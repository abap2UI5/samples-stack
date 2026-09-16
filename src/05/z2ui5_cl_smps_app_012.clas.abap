" @keywords rap business events log consumer subscribe
" @summary what the handler wrote, newest first
CLASS z2ui5_cl_smps_app_012 DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_log,
        event_name TYPE z2ui5_e_smps_evt_name,
        log_text   TYPE z2ui5_e_smps_log_text,
        created_by TYPE syuname,
      END OF ty_s_log.
    DATA mt_log TYPE STANDARD TABLE OF ty_s_log WITH EMPTY KEY.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS data_read.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_012 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      IF client->get_event( ) = `REFRESH`.
        data_read( ).
        view_display( ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD data_read.
    SELECT FROM z2ui5_t_smps_log                        "#EC CI_NOWHERE
      FIELDS event_name, log_text, created_by
      ORDER BY created_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @mt_log
      UP TO 100 ROWS.
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
            )->a( n = `title`          v = `RAP Events Demo - Event Log (abap2UI5)`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( mt_log ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Business Events`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REFRESH` )
                )->a( n = `icon`    v = `sap-icon://refresh`
                )->a( n = `tooltip` v = `Refresh` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Event`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Details`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `User` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{EVENT_NAME}`
                )->tag( `Text`
                    )->a( n = `text` v = `{LOG_TEXT}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CREATED_BY}` ).

    client->view_display( view->stringify( ) ).
  ENDMETHOD.

ENDCLASS.
