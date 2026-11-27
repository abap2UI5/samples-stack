" @keywords launchpad fiori flp shell title follow_up_action
" @summary follow_up_action( cs_event-set_title_launchpad )
CLASS z2ui5_cl_smps_app_482 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA title TYPE string VALUE `my title`.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_482 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
      DATA temp1 TYPE string_table.

    me->client = client.
    IF client->check_on_init( ) IS NOT INITIAL.

      IF client->get( )-check_launchpad_active = abap_false.
        client->message_box_display( `No Launchpad Active, Sample not working!` ).
      ENDIF.
      view_display( ).
    ELSEIF client->check_on_navigated( ) IS NOT INITIAL.
      view_display( ).
    ELSEIF client->check_on_event( `SET_TITLE` ) IS NOT INITIAL.

      
      CLEAR temp1.
      INSERT title INTO TABLE temp1.
      client->follow_up_action(
          val   = z2ui5_if_client=>cs_event-set_title_launchpad
          t_arg = temp1 ).

    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA view TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA page TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA temp3 TYPE string_table.
    view = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    
    page = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `showHeader` b = abap_false ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Sets the launchpad shell title from the backend via follow_up_action( ` &&
                   `cs_event-set_title_launchpad ) - type a title and press Set Title, the ` &&
                   `header above changes without a view rebuild. Only works inside a launchpad.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Set Shell Title`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = ``
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( title )
            )->tag( `Label`
                )->a( n = `text` v = ``
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `SET_TITLE` )
                )->a( n = `text`  v = `Set Title`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event_nav_app_leave( )
                )->a( n = `text`    v = `Go Back`
                )->a( n = `visible` b = client->check_app_prev_stack( ) ).

    client->view_display( view->stringify( ) ).

    
    CLEAR temp3.
    INSERT title INTO TABLE temp3.
    client->follow_up_action(
        val   = z2ui5_if_client=>cs_event-set_title_launchpad
        t_arg = temp3 ).

  ENDMETHOD.

ENDCLASS.
