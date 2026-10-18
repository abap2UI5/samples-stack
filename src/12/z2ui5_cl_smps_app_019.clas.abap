" @keywords rap eml determine action validation check on change valuestate messages without saving
" @summary A determine action runs the validation of the business object while the user types - the quantity is checked on every change, and nothing is saved until Save
"! <p class="shorttext synchronized">RAP Actions - Validate on Change with a Determine Action</p>
"! Validations run at the save - a user who types a wrong value hears about it
"! only when pressing Save. A DETERMINE ACTION runs them on demand instead.
"! The business object z2ui5_r_smps_req declares
"!
"!     determine action checkRequest { validation validateQuantity; }
"!
"! and the app calls it on every change of the quantity, with the new value
"! in the transactional buffer:
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_req
"!       ENTITY request
"!         UPDATE FIELDS ( quantity ) WITH VALUE #( ( requestuuid = ... quantity = ... ) )
"!         EXECUTE checkrequest FROM VALUE #( ( requestuuid = ... ) )
"!       REPORTED DATA(s_reported).
"!
"!     ROLLBACK ENTITIES.
"!
"! The messages of the validation come back in REPORTED, with %element naming
"! the field - the app puts them on the input as its value state. The
"! ROLLBACK discards the change again: the check saves nothing, Save does.
CLASS z2ui5_cl_smps_app_019 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    "! the request being edited
    DATA title        TYPE string.
    DATA quantity     TYPE i.

    "! what the last check said - bound to the input
    DATA value_state      TYPE string.
    DATA value_state_text TYPE string.

  PROTECTED SECTION.
    DATA client       TYPE REF TO z2ui5_if_client.
    DATA request_uuid TYPE string.

    METHODS on_event.
    METHODS request_load.
    METHODS request_check.
    METHODS request_save.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_019 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      request_load( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `CHECK`.
        request_check( ).

      WHEN `SAVE`.
        request_save( ).

      WHEN `NEXT`.
        request_load( ).
        view_display( ).

      WHEN `GENERATE`.
        client->message_toast_display( z2ui5_cl_smps_data_req=>data_reset( ) ).
        request_load( ).
        view_display( ).

    ENDCASE.

  ENDMETHOD.


  METHOD request_load.

    " the newest New request - only those may be changed, the feature
    " control of the business object refuses an update of a decided one
    SELECT FROM z2ui5_r_smps_req
      FIELDS RequestUuid,
             Title,
             Quantity
      WHERE Status = 'N'
      ORDER BY CreatedAt DESCENDING
      INTO TABLE @DATA(t_result) UP TO 1 ROWS.

    DATA(s_result) = VALUE #( t_result[ 1 ] OPTIONAL ).
    request_uuid     = |{ s_result-requestuuid }|.
    title            = |{ s_result-title }|.
    quantity         = s_result-quantity.
    value_state      = `None`.
    value_state_text = ``.

  ENDMETHOD.


  METHOD request_check.

    " the change goes into the transactional buffer, the determine action
    " runs the validation against it - in ONE statement, so the validation
    " sees the new value
    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        UPDATE FIELDS ( quantity )
        WITH VALUE #( ( requestuuid = CONV #( request_uuid )
                        quantity    = quantity ) )
        EXECUTE checkrequest
        FROM VALUE #( ( requestuuid = CONV #( request_uuid ) ) )
      REPORTED DATA(s_reported).

    " nothing is saved - the check only asks. Without the ROLLBACK the change
    " would stay in the buffer and abap2UI5's COMMIT WORK at the end of the
    " roundtrip would run into it.
    ROLLBACK ENTITIES.

    " a message on the field quantity is what the validation reports - the
    " %element flag says which field it belongs to
    DATA(s_message) = VALUE #( s_reported-request[ %element-quantity = if_abap_behv=>mk-on ] OPTIONAL ).

    IF s_message-%msg IS BOUND.
      value_state      = `Error`.
      value_state_text = s_message-%msg->if_message~get_text( ).
    ELSE.
      value_state      = `Success`.
      value_state_text = `The business object accepts this quantity`.
    ENDIF.

  ENDMETHOD.


  METHOD request_save.

    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        UPDATE FIELDS ( quantity )
        WITH VALUE #( ( requestuuid = CONV #( request_uuid )
                        quantity    = quantity ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
      RETURN.
    ENDIF.

    " the same validation once more, now at the save - it is the one that
    " counts, the check above only asked early
    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_req
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported_commit-request ).
      RETURN.
    ENDIF.

    client->message_toast_display( |Quantity { quantity } saved| ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - RAP Actions - 19 Validate on Change`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Change the quantity: every change runs the determine action checkRequest, which runs the ` &&
                                 `validation of the business object without saving - try 0 or 5000. Save stores the value.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    IF request_uuid IS INITIAL.
      page->tag( `MessageStrip`
          )->a( n = `text`  v = `There is no New request to change - press Reset Demo Data below`
          )->a( n = `type`  v = `Warning`
          )->a( n = `class` v = `sapUiSmallMargin` ).
    ENDIF.

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `EXECUTE checkRequest - a determine action`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Request`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( title )
            )->tag( `Label`
                )->a( n = `text` v = `Quantity`
            )->tag( `Input`
                )->a( n = `value`          v = client->_bind( quantity )
                )->a( n = `type`           v = `Number`
                )->a( n = `valueLiveUpdate` b = abap_true
                )->a( n = `valueState`     v = client->_bind( value_state )
                )->a( n = `valueStateText` v = client->_bind( value_state_text )
                )->a( n = `change`         v = client->_event( `CHECK` )
                )->a( n = `enabled`        b = xsdbool( request_uuid IS NOT INITIAL ) ).

    page->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `GENERATE` )
                )->a( n = `text`  v = `Reset Demo Data`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `NEXT` )
                )->a( n = `text`  v = `Reload`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `SAVE` )
                )->a( n = `text`    v = `Save`
                )->a( n = `type`    v = `Emphasized`
                )->a( n = `enabled` b = xsdbool( request_uuid IS NOT INITIAL ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
