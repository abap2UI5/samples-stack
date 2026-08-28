" @keywords stateful session lock enqueue dequeue set_session_stateful
" @summary ENQUEUE_E_TABLE and ENQUEUE_READ, end and restart the session
CLASS z2ui5_cl_smps_app_485 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA lock_counter TYPE i READ-ONLY.
    DATA session_is_stateful TYPE abap_bool READ-ONLY.
    DATA session_text TYPE string READ-ONLY.
    DATA lock_text TYPE string READ-ONLY.
    DATA:
      BEGIN OF error READ-ONLY,
        text TYPE string,
        flag TYPE abap_bool,
      END OF error.

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

    METHODS update_lock_counter.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_485 IMPLEMENTATION.

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
            )->a( n = `title`          v = `abap2UI5 - Sample: Sticky Session with locks - (ABAP Standard Only)`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event( `BACK` ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`    v = client->_bind( error-text )
        )->a( n = `type`    v = `Error`
        )->a( n = `visible` v = client->_bind( error-flag ) ).

    DATA(vbox) = page->ele( `VBox` ).

    DATA(hbox) = vbox->ele( `HBox`
        )->a( n = `alignItems` v = `Center` ).

    hbox->ele( n = `InfoLabel` ns = `tnt`
        )->a( n = `text` v = client->_bind( session_text ) ).

    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `END_SESSION` )
        )->a( n = `text`  v = `End session` ).

    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `START_SESSION` )
        )->a( n = `text`  v = `Start session again` ).

    hbox = vbox->ele( `HBox`
        )->a( n = `alignItems` v = `Center` ).
    hbox->tag( `Label`
        )->a( n = `text`  v = `press button to create lock entry (SM12) in backend session`
        )->a( n = `class` v = `sapUiTinyMarginEnd` ).
    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `LOCK` )
        )->a( n = `text`  v = `Lock`
        )->a( n = `type`  v = `Emphasized` ).

    hbox = vbox->ele( `HBox` ).

    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `REFRESH` )
        )->a( n = `text`  v = `Refresh lock counter` ).

    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `ROLLBACK` )
        )->a( n = `text`  v = `Rollback Work` ).

    vbox->ele( `HBox`
        )->ele( n = `InfoLabel` ns = `tnt`
            )->a( n = `text` v = client->_bind( lock_text ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        set_session_stateful( client = client stateful = abap_false ).
        client->nav_app_leave( ).
      WHEN `LOCK`.
        lcl_locking=>acquire_lock( ).
        client->message_toast_display( `Lock acquired. Press 'Refresh lock counter'` ).
      WHEN `END_SESSION`.
        set_session_stateful( client = client stateful = abap_false ).
      WHEN `START_SESSION`.
        set_session_stateful( client = client stateful = abap_true ).
      WHEN `REFRESH`.
        update_lock_counter( ).
      WHEN `ROLLBACK`.
        ROLLBACK WORK.
        client->message_toast_display( |ROLLBACK WORK done, { lock_counter } locks released. Press 'Refresh lock counter'| ).
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


  METHOD z2ui5_if_app~main.

    TRY.

        error = VALUE #( ).

        IF client->check_on_init( ).
          update_lock_counter( ).
          initialize_view( client ).
        ELSEIF client->check_on_navigated( ).
          initialize_view( client ).
        ENDIF.

        TRY.
            on_event( client ).
          " a lock that could not be taken is the outcome this sample is about,
          " so it is shown in the MessageStrip of the view rather than in a
          " popup - see lcx_error in the local implementations
          CATCH lcx_error INTO DATA(x_error).
            error-text = x_error->get_text( ).
            error-flag = abap_true.
        ENDTRY.

      CATCH cx_root INTO DATA(lx).
        client->message_box_display( lx->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD update_lock_counter.

    lock_counter = lcl_locking=>get_lock_counter( ).
    lock_text = |There are { lock_counter } SM12 locks|.

  ENDMETHOD.

ENDCLASS.
