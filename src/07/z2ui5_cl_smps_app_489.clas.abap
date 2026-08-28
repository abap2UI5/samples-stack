" @keywords websocket apc amc push channel feedlistitem news popover
" @summary connect, publish, list the active connections - no JavaScript
CLASS z2ui5_cl_smps_app_489 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_news,
        text   TYPE string,
        author TYPE string,
      END OF ty_s_news.
    TYPES ty_t_news TYPE STANDARD TABLE OF ty_s_news WITH EMPTY KEY.

    DATA news_input TYPE string.
    DATA author_input TYPE string.
    DATA t_news TYPE ty_t_news.
    DATA connections TYPE i.
    DATA ws_message TYPE string.
    DATA ws_active TYPE abap_bool.
    DATA ws_status TYPE string.
  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.


    METHODS on_init.
    METHODS on_event.
    METHODS on_event_post.
    METHODS on_event_received.
    METHODS on_event_toggle.
    METHODS on_event_error.
    METHODS view_display.
    METHODS popover_display.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_489 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      on_init( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_init.

    " Counted before the control connects - our own connection is added
    " when the APC handler broadcasts __NEW_CONNECTION__ back to us.
    connections = z2ui5_cl_smps_app_489_ws=>get_active_connections( ).
    ws_active   = abap_true.
    ws_status   = `Connected`.

    view_display( ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `POST`.
        on_event_post( ).
      WHEN `WS_RECEIVED`.
        on_event_received( ).
      WHEN `WS_ERROR`.
        on_event_error( ).
      WHEN `TOGGLE_CONNECTION`.
        on_event_toggle( ).
      WHEN `CLEAR`.
        t_news = VALUE #( ).
      WHEN `CLICK_HINT_ICON`.
        popover_display( ).
        RETURN.
    ENDCASE.

    " The view is displayed once, on init - the Websocket control lives in
    " it and must not be torn down and reconnected on every message, so
    " every event only refreshes the model.

  ENDMETHOD.


  METHOD on_event_post.

    DATA(s_news) = VALUE ty_s_news(
        text   = news_input
        author = COND #( WHEN author_input IS INITIAL THEN `Anonymous` ELSE author_input ) ).

    TRY.
        " Published from ABAP straight into the AMC channel - every APC
        " connection bound to it, this app's own included, receives it back
        " through the Websocket control.
        " abap2ui5lint-disable-next-line non-released-api -- the vendored ajson copy: no released JSON writer exists, and a sample class installed on its own cannot ship its own
        z2ui5_cl_smps_app_489_ws=>send( z2ui5_cl_ajson=>create_empty(
            )->set(
                iv_path         = `/`
                iv_val          = s_news
                iv_ignore_empty = abap_false
            )->stringify( ) ).
        news_input = ``.
      CATCH cx_root INTO DATA(error).
        client->message_box_display( error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD on_event_received.

    CASE ws_message.
      WHEN z2ui5_cl_smps_app_489_ws=>c_msg-__new_connection__.
        connections = connections + 1.

      WHEN z2ui5_cl_smps_app_489_ws=>c_msg-__closed__.
        connections = connections - 1.

      WHEN OTHERS.
        TRY.
            DATA(s_news) = VALUE ty_s_news( ).
            z2ui5_cl_ajson=>parse( ws_message
              )->to_abap_corresponding_only(
              )->to_abap( IMPORTING ev_container = s_news ).
            INSERT s_news INTO TABLE t_news.
          " abap2ui5lint-disable-next-line non-released-api -- the exception of the parse below
          CATCH z2ui5_cx_ajson_error INTO DATA(error).
            client->message_toast_display( error->get_text( ) ).
        ENDTRY.
    ENDCASE.

  ENDMETHOD.


  METHOD on_event_toggle.

    " The ToggleButton binds WS_ACTIVE, so the control has already
    " opened or closed the connection client-side when this event arrives -
    " only the counter and the label are left to sort out.
    IF ws_active = abap_true.

      " Reconnecting needs no counting here either: __NEW_CONNECTION__
      " comes back through the reopened connection and adds us.
      ws_status = `Connected`.

    ELSE.

      " We are gone, so the __CLOSED__ broadcast the others receive never
      " reaches us - drop ourselves from the count directly.
      connections = connections - 1.
      ws_status   = `Disconnected`.

    ENDIF.

  ENDMETHOD.


  METHOD on_event_error.

    ws_active = abap_false.
    ws_status = `Disconnected`.
    " The connection is down, so the count can no longer be maintained from
    " the broadcasts - read it from the channel instead.
    connections = z2ui5_cl_smps_app_489_ws=>get_active_connections( ).

    client->message_box_display(
        text = |The WebSocket connection failed ({ client->get_event_arg( 1 ) }): { client->get_event_arg( 2 ) }|
        type = `error` ).

  ENDMETHOD.


  METHOD view_display.

    SELECT
      SINGLE FROM icfservloc
      FIELDS icfactive
      WHERE icf_name = `Z2UI5_APC_SMP_2`
      INTO @DATA(icfactive).

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `xmlns:tnt`    v = `sap.tnt`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Sample: News Feed over WebSocket`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `press`   v = client->_event( `CLICK_HINT_ICON` )
            )->a( n = `icon`    v = `sap-icon://hint`
            )->a( n = `id`      v = `button_hint_id`
            )->a( n = `tooltip` v = `Sample information` ).

    page->tag( `MessageStrip`
        )->a( n = `text` v = `This sample consumes an ABAP Push Channel without a line of JavaScript: the z2ui5:Websocket ` &&
                   `custom control keeps the connection open, reports every message through its 'received' event ` &&
                   `and a failure through 'error'; publishing goes back into the AMC channel from ABAP. The ` &&
                   `button in the footer opens and closes the connection.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    IF icfactive = abap_false.
      page->tag( `MessageStrip`
          )->a( n = `text`    v = `ICF Service '/sap/bc/apc/sap/z2ui5_apc_smp_2' is not active. WebSocket communication will not work. Please activate the ICF Service in transaction SICF.`
          )->a( n = `type`    v = `Warning`
          )->a( n = `visible` b = abap_true ).
    ENDIF.

    " The connection itself: an invisible control that writes each inbound
    " message into WS_MESSAGE and raises WS_RECEIVED so the app can process
    " it. Built generically rather than through _z2ui5( )->websocket( ),
    " because that builder method predates the control's error event.
    page->ele( n = `Websocket` ns = `z2ui5`
        )->a( n = `path`        v = `/sap/bc/apc/sap/z2ui5_apc_smp_2`
        )->a( n = `value`       v = client->_bind( ws_message )
        )->a( n = `checkActive` v = client->_bind( ws_active )
        )->a( n = `received`    v = client->_event( `WS_RECEIVED` )
        )->a( n = `error`       v = client->_event(
                                        val   = `WS_ERROR`
                                        t_arg = VALUE #( ( `${$parameters>/code}` )
                                                         ( `${$parameters>/message}` ) ) ) ).

    DATA(form) = page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Publish news`
        )->a( n = `class`    v = `sapUiTinyMarginBottom`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form` ).

    " Publishing while disconnected would work - it goes into the channel
    " from ABAP - but the app would not see its own news come back.
    form->ele( `FeedInput`
        )->a( n = `enabled` v = client->_bind( ws_active )
        )->a( n = `value`   v = client->_bind( news_input )
        )->a( n = `post`    v = client->_event( `POST` ) ).

    form->tag( `Label`
        )->a( n = `text` v = `Author`
        )->tag( `Input`
            )->a( n = `placeholder` v = `Anonymous`
            )->a( n = `value`       v = client->_bind( author_input ) ).

    page->ele( `List`
        )->a( n = `headerText` v = `News`
        )->a( n = `items`      v = client->_bind( t_news )
        )->ele( `FeedListItem`
            )->a( n = `sender`   v = `{AUTHOR}`
            )->a( n = `showIcon` b = abap_false
            )->a( n = `text`     v = `{TEXT}` ).

    DATA(footer) = page->ele( `footer` )->ele( `OverflowToolbar` ).
    footer->ele( n = `InfoLabel` ns = `tnt`
        )->a( n = `text`        v = client->_bind( connections )
        )->a( n = `colorScheme` v = `7`
        " abap2ui5lint-disable-next-line member-too-new -- sap.tnt.InfoLabel icon is @since 1.74; this package needs 7.40 SP08 and a UI5 with sap.tnt anyway, and the label without its icon would not show what the sample shows
        )->a( n = `icon`        v = `sap-icon://connected` ).

    " Bound to the control's checkActive, so pressing it opens or
    " closes the connection in the browser right away; the roundtrip only
    " brings the counter and the label up to date.
    footer->tag( `ToggleButton`
        )->a( n = `press`   v = client->_event( `TOGGLE_CONNECTION` )
        )->a( n = `text`    v = client->_bind( ws_status )
        )->a( n = `icon`    v = `sap-icon://connected`
        )->a( n = `pressed` v = client->_bind( ws_active ) ).

    " eraser, not clear-all: the clear-all glyph reached the SAP icon font
    " after 1.71, so on the oldest release abap2UI5 supports the button
    " renders with no icon at all - UI5 says nothing about a name it does
    " not know, it simply draws nothing
    footer->tag( `ToolbarSpacer`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `CLEAR` )
            )->a( n = `text`  v = `Clear`
            )->a( n = `icon`  v = `sap-icon://eraser` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD popover_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->a( n = `xmlns:form` v = `sap.ui.layout.form`
            )->a( n = `xmlns:tnt`  v = `sap.tnt` ).
    view->ele( `QuickView`
        )->a( n = `placement` v = `Bottom`
        )->a( n = `width`     v = `auto`
        )->ele( `QuickViewPage`
            )->a( n = `description` v = `This sample shows how to consume APC messages over websocket. Open the app multiple times and post something.`
            )->a( n = `header`      v = `Sample information`
            )->a( n = `pageId`      v = `sampleInformationId` ).

    client->popover_display( xml = view->stringify( ) by_id = `button_hint_id` ).

  ENDMETHOD.

ENDCLASS.
