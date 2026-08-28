" @keywords eml rap draft discard resume leave mode
" @summary EXECUTE Activate / Discard
"! <p class="shorttext synchronized">RAP with Draft - Leave Draft Mode</p>
"! Activate turns the draft into the active instance, Discard throws it away.
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trd
"!       ENTITY travel
"!         EXECUTE Activate FROM VALUE #( ( %key-traveluuid = uuid ) )
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"! Worth knowing: Activate is where the validations finally run, so an invalid
"! draft stays a draft and says why. Discard leaves the active instance exactly
"! as it was. Both are draft actions like Edit and Resume - key only, no
"! %is_draft.
CLASS z2ui5_cl_smps_app_009 DEFINITION PUBLIC.

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
    METHODS draft_activate.
    METHODS draft_discard.
    METHODS view_display.

    METHODS data_save
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_009 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      CASE client->get_event( ).
        WHEN `ACTIVATE`.
          draft_activate( ).
        WHEN `DISCARD`.
          draft_discard( ).
      ENDCASE.
    ENDIF.

  ENDMETHOD.


  METHOD draft_activate.

    DATA(uuid) = client->get_event_arg( 1 ).

    " Activate turns the draft into the active instance. This is where the
    " validations validateCustomer and validateDates finally run - they are
    " declared `on save`, and for a draft business object activation is that
    " save. An invalid draft therefore stays a draft: it is not lost, the
    " messages come back in REPORTED and the user can fix it and try again.
    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        EXECUTE Activate FROM VALUE #( ( %key-traveluuid = uuid ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      data_read( ).
      client->message_toast_display( `Draft activated - it is the active travel now` ).

    ENDIF.

  ENDMETHOD.


  METHOD draft_discard.

    DATA(uuid) = client->get_event_arg( 1 ).

    " Discard deletes the draft and nothing else. The active instance is
    " untouched, which is the whole point: the user throws away the changes,
    " not the travel.
    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        EXECUTE Discard FROM VALUE #( ( %key-traveluuid = uuid ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      data_read( ).
      client->message_toast_display( `Draft discarded - the active travel is unchanged` ).

    ENDIF.

  ENDMETHOD.


  METHOD data_save.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed IS INITIAL.
      result = abap_true.

    ELSE.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
    ENDIF.

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trd
      FIELDS TravelUuid
      ORDER BY TravelId
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

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
            )->a( n = `title`          v = `abap2UI5 - EML - 09 Leave Draft Mode`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text` v = `Two ways out of a draft: Activate keeps the changes, Discard throws them away. Both leave the travel itself alive.`
        )->a( n = `type` v = `Information` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( t_drafts ) ).

    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `EXECUTE Activate  /  EXECUTE Discard` ).

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
                )->tag( `Text`
                    )->a( n = `text` v = `{DESCRIPTION}`
                )->ele( `HBox`
                    )->tag( `Button`
                        )->a( n = `press` v = client->_event( val   = `ACTIVATE`
                                                t_arg = VALUE #( ( `${TRAVEL_UUID}` ) ) )
                        )->a( n = `text`  v = `Activate`
                        )->a( n = `type`  v = `Emphasized`
                    )->tag( `Button`
                        )->a( n = `press` v = client->_event( val   = `DISCARD`
                                                t_arg = VALUE #( ( `${TRAVEL_UUID}` ) ) )
                        )->a( n = `text`  v = `Discard` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
