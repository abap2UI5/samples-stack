" @keywords stateful session basics state roundtrip set_session_stateful
" @summary counts up while the session is stateful, starts over once it is not
CLASS z2ui5_cl_smps_app_486 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA instance_counter TYPE i READ-ONLY.
    DATA session_is_stateful TYPE abap_bool READ-ONLY.
    DATA session_text TYPE string READ-ONLY.

  PROTECTED SECTION.
    METHODS initialize_view
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS on_event
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

    METHODS set_session_stateful
      IMPORTING
        client   TYPE REF TO z2ui5_if_client
        stateful TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_486 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    TRY.

        IF client->check_on_init( ).
          initialize_view( client ).
        ELSEIF client->check_on_navigated( ).
          initialize_view( client ).
        ENDIF.

        on_event( client ).

      CATCH cx_root INTO DATA(lx).
        client->message_box_display( lx->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD initialize_view.

    set_session_stateful( client = client stateful = abap_true ).

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:tnt`    v = `sap.tnt` ).

    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Sample: Sticky Session`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event( `BACK` ) ).

    DATA(vbox) = page->ele( `VBox` ).
    vbox->ele( n = `InfoLabel` ns = `tnt`
        )->a( n = `text` v = client->_bind( session_text ) ).

    DATA(hbox) = vbox->ele( `HBox`
        )->a( n = `alignItems` v = `Center` ).
    hbox->tag( `Label`
        )->a( n = `text`  v = `press button to increment counter in backend session`
        )->a( n = `class` v = `sapUiTinyMarginEnd` ).
    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `INCREMENT` )
        )->a( n = `text`  v = client->_bind( instance_counter )
        )->a( n = `type`  v = `Emphasized` ).

    hbox = vbox->ele( `HBox` ).
    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `END_SESSION` )
        )->a( n = `text`  v = `End session` ).

    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `START_SESSION` )
        )->a( n = `text`  v = `Start session again` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        set_session_stateful( client = client stateful = abap_false ).
        client->nav_app_leave( ).
      WHEN `INCREMENT`.
        instance_counter = lcl_static_container=>increment( ).
      WHEN `END_SESSION`.
        set_session_stateful( client = client stateful = abap_false ).
      WHEN `START_SESSION`.
        set_session_stateful( client = client stateful = abap_true ).
    ENDCASE.

  ENDMETHOD.


  METHOD set_session_stateful.

    client->set_session_stateful( stateful ).
    session_is_stateful = stateful.

    IF stateful = abap_true.
      session_text = `Session ON (stateful)`.

    ELSE.
      session_text = `Session OFF (stateless)`.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
