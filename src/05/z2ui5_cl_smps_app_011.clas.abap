" @keywords rap business events ticket raise publish
" @summary every create and update raises an entity event
CLASS z2ui5_cl_smps_app_011 DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_ticket,
        title      TYPE z2ui5_e_smps_title,
        priority   TYPE z2ui5_e_smps_priority,
        status     TYPE z2ui5_e_smps_status,
        created_by TYPE syuname,
      END OF ty_s_ticket.
    DATA mt_tickets TYPE STANDARD TABLE OF ty_s_ticket WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_create,
        title    TYPE string,
        priority TYPE string,
        status   TYPE string,
      END OF ty_s_create.
    DATA ms_create TYPE ty_s_create.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_init.
    METHODS on_event.
    METHODS on_event_create.
    METHODS data_read.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_011 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
    me->client = client.
    IF client->check_on_init( ).
      ms_create = VALUE #( priority = `M` status = `NEW` ).
      on_init( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.
  ENDMETHOD.

  METHOD on_init.
    data_read( ).
    view_display( ).
  ENDMETHOD.

  METHOD on_event.
    CASE client->get_event( ).
      WHEN `CREATE`.
        on_event_create( ).
      WHEN `REFRESH`.
        data_read( ).
        view_display( ).
    ENDCASE.
  ENDMETHOD.

  METHOD on_event_create.
    IF ms_create-title IS INITIAL.
      client->message_toast_display( `Please enter a title` ).
      RETURN.
    ENDIF.

    " Create a ticket via the RAP business object -> raises the RAP business event
    MODIFY ENTITIES OF z2ui5_r_smps_tck
      ENTITY Ticket
        CREATE FIELDS ( title priority status )
        WITH VALUE #( ( %cid     = `CID_TICKET`
                        title    = ms_create-title
                        priority = ms_create-priority
                        status   = ms_create-status ) )
      FAILED DATA(failed).

    IF failed-ticket IS NOT INITIAL.
      ROLLBACK ENTITIES.
      client->message_toast_display( `Create failed` ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_tck
      FAILED DATA(commit_failed).

    IF commit_failed IS INITIAL.
      client->message_toast_display( |Ticket '{ ms_create-title }' created - business event fired| ).
      ms_create = VALUE #( priority = `M` status = `NEW` ).
      data_read( ).
      view_display( ).
    ELSE.
      client->message_toast_display( `Save failed` ).
    ENDIF.
  ENDMETHOD.

  METHOD data_read.
    SELECT FROM z2ui5_t_smps_tck                        "#EC CI_NOWHERE
      FIELDS title, priority, status, created_by
      ORDER BY created_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @mt_tickets
      UP TO 50 ROWS.
  ENDMETHOD.

  METHOD view_display.
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
            )->a( n = `title`          v = `RAP Events Demo - Tickets (abap2UI5)`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    " --- create form ---
    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Title`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( ms_create-title )
            )->tag( `Label`
                )->a( n = `text` v = `Priority (H / M / L)`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( ms_create-priority )
            )->tag( `Label`
                )->a( n = `text` v = `Status`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( ms_create-status )
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `CREATE` )
                )->a( n = `text`  v = `Create Ticket`
                )->a( n = `type`  v = `Emphasized` ).

    " --- tickets table ---
    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( mt_tickets ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Tickets`
            )->tag( `ToolbarSpacer`
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
                )->a( n = `text` v = `Priority`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Created By` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TITLE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{PRIORITY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{STATUS}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CREATED_BY}` ).

    client->view_display( view->stringify( ) ).
  ENDMETHOD.

ENDCLASS.
