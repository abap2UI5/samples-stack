" @keywords stateful session lock navigation nav_app_call check_on_navigated
" @summary every Next Lock View takes the next VARKEY, going back releases it
CLASS z2ui5_cl_smps_app_490 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA text TYPE string VALUE `call booking mask`.
    DATA varkey TYPE char120.

    METHODS initialize_view2
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

  PROTECTED SECTION.
    DATA view_id TYPE i.

    "! ENQUEUE_E_TABLE (abap_true) or DEQUEUE_E_TABLE (abap_false) on this
    "! view's VARKEY in Z2UI5_T_SMPS_01
    "! @parameter acquire | abap_true sets the lock, abap_false releases it
    "! @parameter result | the message of a lock that could not be set, else empty
    METHODS lock
      IMPORTING
        acquire       TYPE abap_bool
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_490 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    DATA lf_new_varkey TYPE n LENGTH 4.

    IF view_id IS INITIAL OR view_id = 1.
      view_id = 1.
      TRY.
          IF client->check_on_navigated( ).
            " the last lock view has left (or the app just started) - nothing
            " is locked any more, so the session does not need to stay
            client->set_session_stateful( abap_false ).
            DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
                )->ele( n = `View` ns = `mvc`
                    )->a( n = `displayBlock` v = `true`
                    )->a( n = `height`       v = `100%`
                    )->a( n = `xmlns`        v = `sap.m`
                    )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
                    )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
            DATA(page) = view->ele( `Shell`
                )->ele( `Page`
                    )->a( n = `title` v = `Startview` ).
            page->ele( n = `SimpleForm` ns = `form`
                )->ele( n = `content` ns = `form`
                    )->tag( `Button`
                        )->a( n = `press` v = client->_event( `CALL_BOOKING_MASK` )
                        )->a( n = `text`  v = client->_bind( text )
                        )->a( n = `width` v = `20%` ).
            client->view_display( view->stringify( ) ).
            RETURN.
          ENDIF.

          IF client->check_on_event( `CALL_BOOKING_MASK` ).
            DATA(lr_view2) = NEW z2ui5_cl_smps_app_490( ).
            lr_view2->view_id = 2.
            " four digits, the width NEXT_LOCK counts up in - so the first
            " lock reads 0001 and the next one 0002, not 001 and 0002
            lr_view2->varkey = `0001`.
            client->nav_app_call( lr_view2 ).
            RETURN.
          ENDIF.

        CATCH cx_root INTO DATA(lx).
          client->message_box_display( lx ).
      ENDTRY.

    ELSEIF view_id = 2.
      TRY.
          " every lock view holds its own lock in the one stateful session the
          " stack shares: the first one switches the session on, the start view
          " switches it off again once the last lock view has left
          IF client->check_on_init( ).
            DATA(lv_error) = lock( abap_true ).
            IF lv_error IS NOT INITIAL.
              client->message_toast_display( lv_error ).
              client->nav_app_leave( ).
              RETURN.
            ENDIF.
            client->set_session_stateful( ).
            initialize_view2( client ).
            RETURN.
          ENDIF.

          " back from the lock view above: its lock is released, this one's is
          " still held - the screen comes back as it was
          IF client->check_on_navigated( ).
            initialize_view2( client ).
            RETURN.
          ENDIF.

          CASE client->get_event( ).
            WHEN `NEXT_LOCK`.
              lr_view2 = NEW z2ui5_cl_smps_app_490( ).
              lr_view2->view_id = 2.
              lf_new_varkey = varkey+0(4).
              lf_new_varkey = lf_new_varkey + 1.
              lr_view2->varkey = lf_new_varkey+0(4).
              client->nav_app_call( lr_view2 ).
              RETURN.
            WHEN `BACK`.
              " going back releases this view's lock and no other
              lock( abap_false ).
              client->nav_app_leave( ).
              RETURN.
          ENDCASE.

        CATCH cx_root INTO lx.
          client->message_box_display( lx ).
      ENDTRY.
    ENDIF.

  ENDMETHOD.


  METHOD lock.

    " the table is client-dependent, so its key - and with it the lock
    " argument E_TABLE takes - starts with the client
    DATA lv_varkey TYPE char120.
    DATA lv_fm TYPE string.

    lv_varkey = |{ sy-mandt }{ varkey }|.

    IF acquire = abap_false.
      lv_fm = `DEQUEUE_E_TABLE`.
      CALL FUNCTION lv_fm
        EXPORTING
          tabname = 'Z2UI5_T_SMPS_01'
          varkey  = lv_varkey.
      RETURN.
    ENDIF.

    lv_fm = `ENQUEUE_E_TABLE`.
    CALL FUNCTION lv_fm
      EXPORTING
        tabname        = 'Z2UI5_T_SMPS_01'
        varkey         = lv_varkey
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      IF sy-msgid IS NOT INITIAL.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO result.
      ENDIF.
      " an empty result reads as success to the caller - never on a failure
      IF result IS INITIAL.
        result = |Lock on { varkey } could not be set (sy-subrc { sy-subrc })|.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD initialize_view2.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `Stateful Application with lock`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event( `BACK` ) ).
    DATA(vbox) = page->ele( `VBox` ).
    DATA(hbox) = vbox->ele( `HBox`
        )->a( n = `alignItems` v = `Center` ).
    hbox->tag( `Title`
        )->a( n = `text` v = `Current Lock Value in Table Z2UI5_T_SMPS_01` ).
    hbox->tag( `Input`
        )->a( n = `editable` b = abap_false
        )->a( n = `value`    v = client->_bind( varkey ) ).
    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `NEXT_LOCK` )
        )->a( n = `text`  v = `Next Lock View` ).
    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
