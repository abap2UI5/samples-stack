"! <p class="shorttext synchronized">abap2UI5 EML sample - demo data (draft)</p>
"! Demo data for the draft enabled business object z2ui5_r_smps_trd.
"!
"! Run it in ADT with F9 - it is a console application - or press the button
"! in one of the sample apps, which calls the same methods.
"!
"! Writing the tables by hand would hurt here: the draft table
"! z2ui5_d_smps_trd carries the admin fields of SYCH_BDL_DRAFT_ADMIN_INC.
"! Creating a draft and activating it is both correct and shorter - and it is
"! the lifecycle the samples teach.
CLASS z2ui5_cl_smps_data_trd DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    "! Deletes everything, then creates the demo set. This is what F9 runs.
    "! When the business object refuses a discard or a delete, nothing is
    "! created - the result says so instead.
    CLASS-METHODS data_reset
      RETURNING
        VALUE(result) TYPE string.

    "! Creates three demo travels as drafts and activates them, keeping
    "! whatever is already there.
    CLASS-METHODS data_generate
      RETURNING
        VALUE(result) TYPE string.

    "! Discards every draft and deletes every active travel.
    CLASS-METHODS data_delete
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_data_trd IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( data_reset( ) ).

  ENDMETHOD.


  METHOD data_reset.

    result = data_delete( ).

    " a refused discard or delete leaves rows behind, and a reset that keeps
    " old travels and drafts next to the new ones is no reset - stop here
    SELECT FROM z2ui5_r_smps_trd                        "#EC CI_NOWHERE
      FIELDS COUNT( * )
      INTO @DATA(left_over).

    SELECT FROM z2ui5_d_smps_trd                        "#EC CI_NOWHERE
      FIELDS COUNT( * )
      INTO @DATA(drafts_left_over).

    IF left_over > 0 OR drafts_left_over > 0.
      result = |{ result } No demo data created, { left_over } travel(s) and { drafts_left_over } draft(s) are still there.|.
      RETURN.
    ENDIF.

    result = |{ result } { data_generate( ) }|.

  ENDMETHOD.


  METHOD data_generate.

    " the system date through the released API: ABAP Cloud refuses a read of
    " sy-datum, and the package says Cloud + Standard
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    " a new instance of a draft enabled business object is born as a draft
    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        CREATE FIELDS ( agencyid customerid begindate enddate bookingfee currencycode description )
        WITH VALUE #( %is_draft    = if_abap_behv=>mk-on
                      currencycode = 'EUR'
                      ( %cid        = `DEMO_1`
                        agencyid    = '070001'
                        customerid  = '000001'
                        begindate   = today
                        enddate     = today + 14
                        bookingfee  = '20.00'
                        description = 'Demo travel - sightseeing' )
                      ( %cid        = `DEMO_2`
                        agencyid    = '070002'
                        customerid  = '000002'
                        begindate   = today + 30
                        enddate     = today + 37
                        bookingfee  = '35.50'
                        description = 'Demo travel - business trip' )
                      ( %cid        = `DEMO_3`
                        agencyid    = '070003'
                        customerid  = '000003'
                        begindate   = today + 60
                        enddate     = today + 74
                        bookingfee  = '12.75'
                        description = 'Demo travel - city break' ) )
      MAPPED DATA(s_mapped)
      FAILED DATA(s_failed).

    IF s_failed-travel IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = |Demo drafts rejected, { lines( s_failed-travel ) } instance(s) refused.|.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
      FAILED DATA(s_failed_draft).

    IF s_failed_draft IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `The demo drafts were refused on commit.`.
      RETURN.
    ENDIF.

    " Activate runs the validations, so anything wrong surfaces here
    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        EXECUTE Activate FROM VALUE #( FOR s_new IN s_mapped-travel
                                       ( %key-traveluuid = s_new-traveluuid ) )
      FAILED DATA(s_failed_act).

    IF s_failed_act-travel IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `The demo drafts were created but refused on activation.`.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
      FAILED DATA(s_failed_commit).

    IF s_failed_commit IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `Demo data rejected by the business object on commit.`.
      RETURN.
    ENDIF.

    result = `3 demo travels created and activated.`.

  ENDMETHOD.


  METHOD data_delete.

    SELECT FROM z2ui5_r_smps_trd                        "#EC CI_NOWHERE
      FIELDS TravelUuid
      ORDER BY TravelUuid
      INTO TABLE @DATA(t_keys).

    " The CDS entity shows active instances only. A draft that was never
    " activated - a new instance is born as a draft, and data_generate( )
    " leaves its drafts behind when Activate refuses them - exists in the
    " draft table alone, so the draft keys are read from there. Reading the
    " draft table is fine; writing it is what EML is for.
    SELECT FROM z2ui5_d_smps_trd                        "#EC CI_NOWHERE
      FIELDS traveluuid
      ORDER BY traveluuid
      INTO TABLE @DATA(t_draft_keys).

    IF t_keys IS INITIAL AND t_draft_keys IS INITIAL.
      result = `Nothing to delete.`.
      RETURN.
    ENDIF.

    " Every draft has to go before its active instance can. Ask which ones EML
    " actually returns instead of discarding blindly: a Discard on an instance
    " without a draft lands in FAILED, and an EML failure that is neither
    " rolled back nor evaluated leaves the RAP transaction marked for abortion.
    " Every later statement of the same LUW then aborts - which is how this
    " method used to end the whole request in a CX_SADL_DUMP_APPL_MODEL_ERROR
    " instead of deleting anything.
    "
    " Reading the keys with %is_draft = mk-on is the same trick sample 06
    " uses: what comes back in RESULT has a draft.
    READ ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        FIELDS ( travelid ) WITH VALUE #( FOR s_row IN t_draft_keys
                                          ( %tky = VALUE #( traveluuid = s_row-traveluuid
                                                            %is_draft  = if_abap_behv=>mk-on ) ) )
      RESULT DATA(t_drafts).

    IF t_drafts IS NOT INITIAL.

      MODIFY ENTITIES OF z2ui5_r_smps_trd
        ENTITY travel
          EXECUTE Discard FROM VALUE #( FOR s_draft IN t_drafts
                                        ( %key-traveluuid = s_draft-traveluuid ) )
        FAILED DATA(s_failed_discard).

      IF s_failed_discard-travel IS NOT INITIAL.
        ROLLBACK ENTITIES.
        result = `Existing drafts could not be discarded.`.
        RETURN.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
        FAILED DATA(s_failed_commit_discard).

      IF s_failed_commit_discard IS NOT INITIAL.
        ROLLBACK ENTITIES.
        result = `Existing drafts could not be discarded on commit.`.
        RETURN.
      ENDIF.

    ENDIF.

    IF t_keys IS INITIAL.
      result = |{ lines( t_drafts ) } draft(s) discarded.|.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        DELETE FROM VALUE #( FOR s_key IN t_keys
                             ( %tky = VALUE #( traveluuid = s_key-traveluuid
                                               %is_draft  = if_abap_behv=>mk-off ) ) )
      FAILED DATA(s_failed).

    IF s_failed-travel IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `Deletion refused by the business object.`.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
      FAILED DATA(s_failed_commit).

    IF s_failed_commit IS NOT INITIAL.
      ROLLBACK ENTITIES.
      result = `Deletion refused by the business object on commit.`.
      RETURN.
    ENDIF.

    result = |{ lines( t_drafts ) } draft(s) discarded, { lines( t_keys ) } travel(s) deleted.|.

  ENDMETHOD.

ENDCLASS.
