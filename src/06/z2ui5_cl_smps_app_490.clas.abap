" @keywords stateful session lock navigation nav_app_call check_on_navigated
" @summary every Next Lock View takes the next VARKEY, going back releases it
CLASS z2ui5_cl_smps_app_490 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA view_id TYPE i.
    DATA text TYPE string VALUE `call booking mask`.
    DATA varkey TYPE char120.

    METHODS initialize_view2
      IMPORTING
        client TYPE REF TO z2ui5_if_client.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_490 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    DATA lf_new_varkey TYPE n LENGTH 4.

    IF view_id IS INITIAL OR view_id = 1.
      view_id = 1.
      TRY.
          IF client->check_on_navigated( ).
            DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
                )->ele( n = `View` ns = `mvc`
                    )->a( n = `displayBlock` v = `true`
                    )->a( n = `height`       v = `100%`
                    )->a( n = `xmlns`        v = `sap.m`
                    )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
                    )->a( n = `xmlns:core`   v = `sap.ui.core`
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
            lr_view2->varkey = `001`.
            client->nav_app_call( lr_view2 ).
            RETURN.
          ENDIF.

        CATCH cx_root INTO DATA(lx).
          client->message_box_display( lx ).
      ENDTRY.

    ELSEIF view_id = 2.
      TRY.
          IF client->check_on_init( ).

            DATA(lv_fm) = `ENQUEUE_E_TABLE`.
            CALL FUNCTION lv_fm
              EXPORTING
                tabname        = `Z2UI5_T_SMPS_01`
                varkey         = varkey
              EXCEPTIONS
                foreign_lock   = 1
                system_failure = 2
                OTHERS         = 3.

            IF sy-subrc <> 0.
              client->set_session_stateful( abap_false ).
              client->nav_app_leave( ).

            ELSE.

              client->set_session_stateful( ).
              initialize_view2( client ).
            ENDIF.
            RETURN.
          ENDIF.

          IF client->check_on_navigated( ).
            client->set_session_stateful( abap_false ).
            TRY.
                client->nav_app_leave( ).
                RETURN.
              CATCH cx_sy_move_cast_error ##NO_HANDLER ##CATCH_ALL.
            ENDTRY.
          ENDIF.

          CASE client->get_event( ).
            WHEN `NEXT_LOCK`.
              client->set_session_stateful( abap_false ).
              lr_view2 = NEW z2ui5_cl_smps_app_490( ).
              lr_view2->view_id = 2.
              lf_new_varkey = varkey+0(4).
              lf_new_varkey = lf_new_varkey + 1.
              lr_view2->varkey = lf_new_varkey+0(4).
              client->nav_app_call( lr_view2 ).
              RETURN.
            WHEN `BACK`.
              client->set_session_stateful( abap_false ).
              client->nav_app_leave( ).
              RETURN.
          ENDCASE.

        CATCH cx_root INTO lx.
          client->message_box_display( lx ).
      ENDTRY.
    ENDIF.

  ENDMETHOD.


  METHOD initialize_view2.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `Stateful Application with lock`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event( `BACK` ) ).
    DATA(vbox) = page->ele( `VBox` ).
    DATA(hbox) = vbox->ele( `HBox`
        )->a( n = `alignItems` v = `Center` ).
    hbox->tag( `Title`
        )->a( n = `text` v = `Current Lock Value in Table ZTEST` ).
    hbox->tag( `Input`
        )->a( n = `editable` b = abap_false
        )->a( n = `value`    v = client->_bind( varkey ) ).
    hbox->tag( `Button`
        )->a( n = `press` v = client->_event( `NEXT_LOCK` )
        )->a( n = `text`  v = `Next Lock View` ).
    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
