" @keywords launchpad fiori flp startup parameters intent
" @summary what the tile passed in - client->get( )-t_comp_params
CLASS z2ui5_cl_smps_app_481 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_481 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).

      IF client->get( )-check_launchpad_active = abap_false.
        client->message_box_display( `No Launchpad Active, Sample not working!` ).
      ENDIF.
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `READ_PARAMS` ).

      DATA(text) = `Start Parameter: `.
      DATA(t_params) = client->get( )-t_comp_params.
      LOOP AT t_params INTO DATA(s_param).
        text = |{ text } / { s_param-n } = { s_param-v }|.
      ENDLOOP.
      client->message_box_display( text ).

    ENDIF.

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
            )->a( n = `showHeader` b = abap_false ).
    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Reads the startup parameters the Fiori Launchpad passed to this app ` &&
                   `tile (the ComponentData) via client->get( )-t_comp_params - start the ` &&
                   `tile with URL parameters to see them. Only works inside a launchpad.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).
    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Launchpad - Read Startup Parameters`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = ``
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `READ_PARAMS` )
                )->a( n = `text`  v = `Read Parameters`
            )->tag( `Label`
                )->a( n = `text` v = ``
            )->tag( `Button`
                )->a( n = `press`   v = client->_event_nav_app_leave( )
                )->a( n = `text`    v = `Go Back`
                )->a( n = `visible` b = client->check_app_prev_stack( ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
