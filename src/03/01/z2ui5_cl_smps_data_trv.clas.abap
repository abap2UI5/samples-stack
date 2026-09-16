"! <p class="shorttext synchronized">abap2UI5 EML sample - demo data</p>
"! Demo data for the business object z2ui5_r_smps_trv.
"!
"! Run it in ADT with F9 - it is a console application - or press the button
"! in one of the sample apps, which calls the same methods.
"!
"! Everything goes through the business object with EML, never with an INSERT
"! into z2ui5_t_smps_trv. An INSERT would skip the determination
"! setInitialValues, so the rows would carry no status and no total price -
"! data this business object could never have produced itself.
CLASS z2ui5_cl_smps_data_trv DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    "! Deletes everything, then creates the demo set. This is what F9 runs.
    "!
    "! Deleting first is what makes the keys predictable: early numbering
    "! continues behind MAX( travel_id ), so on an empty table the demo
    "! travels always come out as 1, 2, 3.
    CLASS-METHODS data_reset
      RETURNING
        VALUE(result) TYPE string.

    "! Creates three demo travels, keeping whatever is already there.
    CLASS-METHODS data_generate
      RETURNING
        VALUE(result) TYPE string.

    "! Deletes every travel through the business object.
    CLASS-METHODS data_delete
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_data_trv IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( data_reset( ) ).

  ENDMETHOD.


  METHOD data_reset.

    result = |{ data_delete( ) } { data_generate( ) }|.

  ENDMETHOD.


  METHOD data_generate.

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        CREATE FIELDS ( agencyid customerid begindate enddate bookingfee currencycode description )
        WITH VALUE #( currencycode = 'EUR'
                      ( %cid        = `DEMO_1`
                        agencyid    = '070001'
                        customerid  = '000001'
                        begindate   = sy-datum
                        enddate     = sy-datum + 14
                        bookingfee  = '20.00'
                        description = 'Demo travel - sightseeing' )
                      ( %cid        = `DEMO_2`
                        agencyid    = '070002'
                        customerid  = '000002'
                        begindate   = sy-datum + 30
                        enddate     = sy-datum + 37
                        bookingfee  = '35.50'
                        description = 'Demo travel - business trip' )
                      ( %cid        = `DEMO_3`
                        agencyid    = '070003'
                        customerid  = '000003'
                        begindate   = sy-datum + 60
                        enddate     = sy-datum + 74
                        bookingfee  = '12.75'
                        description = 'Demo travel - city break' ) )
      FAILED DATA(s_failed).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      result = |Demo data rejected, { lines( s_failed-travel ) } instance(s) refused.|.
      RETURN.

    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
      FAILED DATA(s_failed_commit).

    IF s_failed_commit IS NOT INITIAL.
      result = `Demo data rejected by the business object on commit.`.
      RETURN.
    ENDIF.

    result = `3 demo travels created.`.

  ENDMETHOD.


  METHOD data_delete.

    SELECT FROM z2ui5_r_smps_trv                        "#EC CI_NOWHERE
      FIELDS TravelId
      ORDER BY TravelId
      INTO TABLE @DATA(t_keys).

    IF t_keys IS INITIAL.
      result = `Nothing to delete.`.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        DELETE FROM VALUE #( FOR s_key IN t_keys ( travelid = s_key-travelid ) )
      FAILED DATA(s_failed).

    IF s_failed-travel IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `Deletion refused by the business object.`.
      RETURN.
    ENDIF.

    COMMIT ENTITIES.

    result = |{ lines( t_keys ) } travel(s) deleted.|.

  ENDMETHOD.

ENDCLASS.
