" @keywords eml rap draft change save modify
" @summary UPDATE ... %is_draft = mk-on
"! <p class="shorttext synchronized">RAP with Draft - Change and Save a Draft</p>
"! An ordinary UPDATE. The only thing that makes it a draft update is
"! %is_draft = mk-on in the key.
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trd
"!       ENTITY travel
"!         UPDATE FIELDS ( description )
"!         WITH VALUE #( ( %tky        = VALUE #( traveluuid = uuid
"!                                                %is_draft  = if_abap_behv=>mk-on )
"!                         description = s_draft-description ) )
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"! Worth knowing: the COMMIT writes the draft table, not the application table,
"! and the active instance stays untouched until someone activates the draft
"! (sample 09). Validations do not run yet either - a draft may be
"! incomplete.
CLASS z2ui5_cl_smps_app_008 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_draft,
        travel_uuid TYPE string,
        travel_id   TYPE string,
        description TYPE string,
      END OF ty_s_draft.
    DATA t_drafts TYPE STANDARD TABLE OF ty_s_draft WITH EMPTY KEY.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS data_read.
    METHODS draft_save.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_008 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `SAVE` ).
      draft_save( ).
    ENDIF.

  ENDMETHOD.


  METHOD draft_save.

    DATA(uuid) = client->get_event_arg( 1 ).
    DATA(s_draft) = t_drafts[ travel_uuid = uuid ].

    " An ordinary UPDATE - the only thing that makes it a draft update is
    " %is_draft = mk-on in the key. The active instance stays untouched.
    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        UPDATE FIELDS ( description )
        WITH VALUE #( ( %tky        = VALUE #( traveluuid = uuid
                                               %is_draft  = if_abap_behv=>mk-on )
                        description = s_draft-description ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    " The COMMIT writes the draft into the draft table z2ui5_d_smps_trd.
    " Note what does NOT happen here: no validation runs. A draft may be
    " incomplete or plainly wrong and still be saved - it survives the
    " session and even a logoff. The validations wait for Activate.
    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.

      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported_commit-travel ).
      RETURN.

    ENDIF.

    data_read( ).
    client->message_toast_display( |Draft of travel { s_draft-travel_id } saved - it survives a logoff| ).

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trd
      FIELDS TravelUuid
      ORDER BY TravelId
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

    " read the DRAFT instances, not the active ones - so the form below
    " shows what is currently in the draft, which is what gets changed
    READ ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        FIELDS ( travelid description ) WITH VALUE #( FOR s_row IN t_result
                                                      ( %tky = VALUE #( traveluuid = s_row-traveluuid
                                                                        %is_draft  = if_abap_behv=>mk-on ) ) )
      RESULT DATA(t_result_drafts).

    t_drafts = VALUE #( FOR s_result IN t_result_drafts
        ( travel_uuid = |{ s_result-traveluuid }|
          travel_id   = |{ s_result-travelid ALPHA = OUT }|
          description = |{ s_result-description }| ) ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - EML - 08 Change and Save a Draft`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text` v = `Only travels that already have a draft show up here - create one with the Enter Draft Mode app.`
        )->a( n = `type` v = `Information` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( t_drafts ) ).

    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `UPDATE ... WITH %is_draft = mk-on` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `ID`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description (draft)`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}`
                )->tag( `Input`
                    )->a( n = `value` v = `{DESCRIPTION}`
                )->tag( `Button`
                    )->a( n = `press` v = client->_event( val   = `SAVE`
                                            t_arg = VALUE #( ( `${TRAVEL_UUID}` ) ) )
                    )->a( n = `text`  v = `Save Draft` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
