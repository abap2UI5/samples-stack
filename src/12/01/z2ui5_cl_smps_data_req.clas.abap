"! <p class="shorttext synchronized">abap2UI5 RAP sample - request demo data</p>
"! Demo data for the business object z2ui5_r_smps_req: three requests, two
"! of them New and one Rejected.
"!
"! Run it in ADT with F9 - it is a console application - or press the button
"! in one of the sample apps, which calls the same method. Everything goes
"! through the business object with EML, the creates through its static
"! factory action createRequest.
CLASS z2ui5_cl_smps_data_req DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    "! Deletes every request the business object lets go of, then creates
    "! the demo set. Approved requests stay: the feature control of the
    "! business object refuses to delete them, and the demo data respects
    "! that like any other caller.
    CLASS-METHODS data_reset
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_data_req IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( data_reset( ) ).

  ENDMETHOD.


  METHOD data_reset.

    SELECT FROM z2ui5_r_smps_req
      FIELDS RequestUuid
      WHERE Status <> 'A'
      ORDER BY RequestUuid
      INTO TABLE @DATA(t_keys).

    IF t_keys IS NOT INITIAL.

      MODIFY ENTITIES OF z2ui5_r_smps_req
        ENTITY request
          DELETE FROM VALUE #( FOR s_key IN t_keys ( requestuuid = s_key-requestuuid ) )
        FAILED DATA(s_failed_delete).

      IF s_failed_delete IS NOT INITIAL.
        ROLLBACK ENTITIES.
        result = `Deletion refused by the business object - no demo data created.`.
        RETURN.
      ENDIF.

    ENDIF.

    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE createrequest
        FROM VALUE #( ( %cid = `DEMO_1` %param = VALUE #( title = 'Laptop for the new colleague' quantity = 1  priority = 'H' ) )
                      ( %cid = `DEMO_2` %param = VALUE #( title = 'Printer paper'                quantity = 50 priority = 'L' ) )
                      ( %cid = `DEMO_3` %param = VALUE #( title = 'Monitor stands'               quantity = 4  priority = 'M' ) ) )
      MAPPED DATA(s_mapped)
      FAILED DATA(s_failed).

    IF s_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `Demo data rejected by the business object.`.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_req
      FAILED DATA(s_failed_commit).

    IF s_failed_commit IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `Demo data rejected by the business object on commit.`.
      RETURN.
    ENDIF.

    " the keys are known now - MAPPED carries them under the %cid sent above.
    " One request is rejected, so a decided request is there from the start.
    DATA(key_3) = VALUE #( s_mapped-request[ %cid = `DEMO_3` ]-requestuuid OPTIONAL ).

    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE reject FROM VALUE #( ( requestuuid = key_3
                                       %param      = VALUE #( reason = 'Not in this year''s budget' ) ) )
      FAILED DATA(s_failed_reject).

    IF s_failed_reject IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `3 demo requests created, all of them New.`.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_req
      FAILED DATA(s_failed_reject_commit).

    IF s_failed_reject_commit IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `3 demo requests created, all of them New.`.
      RETURN.
    ENDIF.

    result = `3 demo requests created.`.

  ENDMETHOD.

ENDCLASS.
