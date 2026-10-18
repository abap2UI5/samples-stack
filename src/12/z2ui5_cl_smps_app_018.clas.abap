" @keywords rap eml action parameter abstract entity factory action default function popup create copy reject
" @summary Actions with a parameter - a default function proposes a new request, a static factory action creates it, a factory action copies one, and reject asks for its reason in a popup
"! <p class="shorttext synchronized">RAP Actions - Parameters, Factory Actions, Defaults</p>
"! Four ways into the business object z2ui5_r_smps_req that all carry a
"! PARAMETER - an abstract entity, filled in a popup and handed over in
"! %param:
"!
"!     " the default function proposes the values of a new request
"!     READ ENTITIES OF z2ui5_r_smps_req
"!       ENTITY request
"!         EXECUTE getdefaultsforcreate FROM VALUE #( ( %cid = `DEFAULTS` ) )
"!       RESULT DATA(t_defaults).
"!
"!     " a static factory action creates a request from its parameter
"!     MODIFY ENTITIES OF z2ui5_r_smps_req
"!       ENTITY request
"!         EXECUTE createrequest FROM VALUE #( ( %cid = `CREATE_1` %param = ... ) )
"!       MAPPED DATA(s_mapped) ...
"!
"!     " an instance factory action creates a copy of an existing one
"!     EXECUTE copyrequest FROM VALUE #( ( %cid = `COPY_1` requestuuid = ... %param = ... ) )
"!
"!     " an ordinary action with a parameter
"!     EXECUTE reject FROM VALUE #( ( requestuuid = ... %param = VALUE #( reason = ... ) ) )
"!
"! A factory action returns no RESULT - the new instance comes back in MAPPED,
"! under the %cid the caller sent.
CLASS z2ui5_cl_smps_app_018 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_request,
        request_uuid TYPE string,
        title        TYPE string,
        quantity     TYPE string,
        priority     TYPE string,
        status       TYPE string,
        note         TYPE string,
      END OF ty_s_request.
    TYPES ty_t_request TYPE STANDARD TABLE OF ty_s_request WITH EMPTY KEY.
    DATA t_requests TYPE ty_t_request.

    TYPES:
      "! what the popup edits - the parameter of the action it was opened for
      BEGIN OF ty_s_popup,
        title    TYPE string,
        quantity TYPE i,
        priority TYPE string,
        reason   TYPE string,
      END OF ty_s_popup.
    DATA s_popup TYPE ty_s_popup.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    CONSTANTS:
      "! which action the open popup belongs to
      BEGIN OF cs_mode,
        create TYPE string VALUE `CREATE`,
        copy   TYPE string VALUE `COPY`,
        reject TYPE string VALUE `REJECT`,
      END OF cs_mode.

    "! the popup that is open, and the request it was opened for
    DATA popup_mode   TYPE string.
    DATA request_uuid TYPE string.

    METHODS on_event.
    METHODS popup_open_create.
    METHODS popup_confirm.
    METHODS request_create.
    METHODS request_copy.
    METHODS request_reject.
    METHODS data_save
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS data_read.
    METHODS view_display.
    METHODS popup_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_018 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `CREATE`.
        popup_open_create( ).

      WHEN `COPY`.
        popup_mode   = cs_mode-copy.
        request_uuid = client->get_event_arg( ).
        s_popup = VALUE #( title = |{ client->get_event_arg( 2 ) } (copy)| ).
        popup_display( ).

      WHEN `REJECT`.
        popup_mode   = cs_mode-reject.
        request_uuid = client->get_event_arg( ).
        s_popup = VALUE #( ).
        popup_display( ).

      WHEN `POPUP_CONFIRM`.
        popup_confirm( ).

      WHEN `POPUP_CANCEL`.
        client->popup_destroy( ).

      WHEN `REFRESH`.
        data_read( ).

      WHEN `GENERATE`.
        client->message_toast_display( z2ui5_cl_smps_data_req=>data_reset( ) ).
        data_read( ).

    ENDCASE.

  ENDMETHOD.


  METHOD popup_open_create.

    " A default function is a FUNCTION: it reads, it changes nothing. It is
    " called with READ ... EXECUTE, and its RESULT carries a whole instance
    " in %param - the proposal the popup opens with.
    READ ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE getdefaultsforcreate FROM VALUE #( ( %cid = `DEFAULTS` ) )
      RESULT DATA(t_defaults).

    DATA(s_default) = VALUE #( t_defaults[ 1 ]-%param OPTIONAL ).
    s_popup = VALUE #( title    = |{ s_default-title }|
                       quantity = s_default-quantity
                       priority = |{ s_default-priority }| ).

    popup_mode = cs_mode-create.
    popup_display( ).

  ENDMETHOD.


  METHOD popup_confirm.

    CASE popup_mode.
      WHEN cs_mode-create.
        request_create( ).
      WHEN cs_mode-copy.
        request_copy( ).
      WHEN cs_mode-reject.
        request_reject( ).
    ENDCASE.

  ENDMETHOD.


  METHOD request_create.

    " a static factory action needs no instance - like a CREATE, but the
    " business object decides what the parameter becomes
    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE createrequest
        FROM VALUE #( ( %cid   = `CREATE_1`
                        %param = VALUE #( title    = s_popup-title
                                          quantity = s_popup-quantity
                                          priority = s_popup-priority ) ) )
      MAPPED DATA(s_mapped)
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->popup_destroy( ).
      client->message_toast_display( COND #( WHEN s_mapped-request IS INITIAL
                                             THEN `Request created`
                                             ELSE `Request created - its key came back in MAPPED` ) ).
    ENDIF.

  ENDMETHOD.


  METHOD request_copy.

    " an instance factory action: the key names the source, %cid names the
    " copy - MAPPED returns the copy's new key under that %cid
    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE copyrequest
        FROM VALUE #( ( %cid        = `COPY_1`
                        requestuuid = CONV #( request_uuid )
                        %param      = VALUE #( title = s_popup-title ) ) )
      MAPPED DATA(s_mapped)
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->popup_destroy( ).
      client->message_toast_display( COND #( WHEN s_mapped-request IS INITIAL
                                             THEN `Request copied`
                                             ELSE `Request copied - the new key came back in MAPPED` ) ).
    ENDIF.

  ENDMETHOD.


  METHOD request_reject.

    " an empty reason is not refused here - the business object refuses it,
    " and its message is what the user sees
    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE reject
        FROM VALUE #( ( requestuuid = CONV #( request_uuid )
                        %param      = VALUE #( reason = s_popup-reason ) ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->popup_destroy( ).
      client->message_toast_display( `Request rejected` ).
    ENDIF.

  ENDMETHOD.


  METHOD data_save.

    " the validation of the quantity runs here, at the save - a factory
    " action that came back clean can still be refused now
    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_req
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed IS INITIAL.
      result = abap_true.
      data_read( ).
    ELSE.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
    ENDIF.

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_req                        "#EC CI_NOWHERE
      FIELDS RequestUuid,
             Title,
             Quantity,
             Priority,
             Status,
             Note
      ORDER BY CreatedAt DESCENDING
      INTO TABLE @DATA(t_result) UP TO 50 ROWS.

    t_requests = VALUE #( FOR s_result IN t_result
        ( request_uuid = |{ s_result-requestuuid }|
          title        = |{ s_result-title }|
          quantity     = |{ s_result-quantity }|
          priority     = SWITCH #( s_result-priority
                                   WHEN 'H' THEN `High`
                                   WHEN 'M' THEN `Medium`
                                   WHEN 'L' THEN `Low` )
          status       = SWITCH #( s_result-status
                                   WHEN 'N' THEN `New`
                                   WHEN 'A' THEN `Approved`
                                   WHEN 'R' THEN `Rejected` )
          note         = |{ s_result-note }| ) ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - RAP Actions - 18 Parameters, Factory Actions, Defaults`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Create opens with the proposal of the default function and creates through a static ` &&
                                 `factory action, Copy runs a factory action on the row, Reject an action whose parameter ` &&
                                 `is the reason - every popup fills an abstract entity that travels in %param.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_requests )
        )->a( n = `noDataText` v = `No requests yet - press Create or Reset Demo Data` ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Requests (Z2UI5_R_SMPS_REQ)`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `CREATE` )
                )->a( n = `text`  v = `Create`
                )->a( n = `icon`  v = `sap-icon://add`
                )->a( n = `type`  v = `Emphasized`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `GENERATE` )
                )->a( n = `text`    v = `Reset Demo Data`
                )->a( n = `tooltip` v = `Deletes every request the business object lets go of, then creates three new ones`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REFRESH` )
                )->a( n = `icon`    v = `sap-icon://refresh`
                )->a( n = `tooltip` v = `Refresh` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Title`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Quantity`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Priority`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Note`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Actions` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TITLE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{QUANTITY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{PRIORITY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{STATUS}`
                )->tag( `Text`
                    )->a( n = `text` v = `{NOTE}`
                )->ele( `HBox`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `COPY` t_arg = VALUE #( ( `${REQUEST_UUID}` ) ( `${TITLE}` ) ) )
                        )->a( n = `icon`    v = `sap-icon://copy`
                        )->a( n = `tooltip` v = `Copy - factory action copyRequest`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `REJECT` arg = `${REQUEST_UUID}` )
                        )->a( n = `icon`    v = `sap-icon://decline`
                        )->a( n = `tooltip` v = `Reject - action with a parameter` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD popup_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->a( n = `xmlns:form` v = `sap.ui.layout.form` ).
    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        v = SWITCH #( popup_mode
                                                WHEN cs_mode-create THEN `Create - static factory action createRequest`
                                                WHEN cs_mode-copy   THEN `Copy - factory action copyRequest`
                                                WHEN cs_mode-reject THEN `Reject - action with a parameter` )
        )->a( n = `contentWidth` v = `30rem` ).

    DATA(content) = dialog->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form` ).

    CASE popup_mode.

      WHEN cs_mode-create.
        content->tag( `Label`
            )->a( n = `text` v = `Title`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_popup-title )
            )->tag( `Label`
                )->a( n = `text` v = `Quantity`
            )->tag( `StepInput`
                )->a( n = `value` v = client->_bind( s_popup-quantity )
                )->a( n = `min`   v = `0`
            )->tag( `Label`
                )->a( n = `text` v = `Priority`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey` v = client->_bind( s_popup-priority )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `L`
                        )->a( n = `text` v = `Low`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `M`
                        )->a( n = `text` v = `Medium`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `H`
                        )->a( n = `text` v = `High` ).

      WHEN cs_mode-copy.
        content->tag( `Label`
            )->a( n = `text` v = `Title of the copy`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_popup-title ) ).

      WHEN cs_mode-reject.
        content->tag( `Label`
            )->a( n = `text` v = `Reason`
            )->tag( `TextArea`
                )->a( n = `value`       v = client->_bind( s_popup-reason )
                )->a( n = `placeholder` v = `required - the business object refuses an empty one`
                )->a( n = `rows`        v = `3` ).

    ENDCASE.

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `POPUP_CONFIRM` )
            )->a( n = `text`  v = `OK`
            )->a( n = `type`  v = `Emphasized` ).
    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `POPUP_CANCEL` )
            )->a( n = `text`  v = `Cancel` ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
