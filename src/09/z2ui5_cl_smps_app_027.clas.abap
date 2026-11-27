" @keywords launchpad fiori flp full width letterbox screen width fullwidth set_app_full_width follow_up_action
" @summary follow_up_action( cs_event-set_app_full_width ) - the app takes the launchpad's whole width instead of the shell's letterbox
"! <p class="shorttext synchronized">Launchpad - Full Width</p>
"! The launchpad shows an app at a limited width with empty margins left
"! and right (the letterbox), unless the app asks for the full screen. A
"! Fiori elements app asks with "fullWidth" in its manifest; all abap2UI5
"! apps share one component and one manifest, so an abap2UI5 app asks at
"! runtime instead, with the frontend action cs_event-set_app_full_width:
"!
"!     client->follow_up_action(
"!         val   = client->cs_event-set_app_full_width
"!         t_arg = VALUE #( ( `X` ) ) ).
"!
"! X for the full width, no argument for the letterbox again. The sample
"! asks for the full width on start - a wide table is where it pays off -
"! and the switch toggles between the two.
"!
"! The sap.m.Shell around the page limits the width on its own as well,
"! so it is rendered with appWidthLimited = false - otherwise the app
"! stays boxed in however wide the launchpad lets it be.
"!
"! Needs abap2UI5 newer than 1.148.0 (set_app_full_width) and a launchpad.
"! Some launchpads start every app at full width already - there the
"! switch shows the letterbox when it is turned off.
CLASS z2ui5_cl_smps_app_027 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_row,
        col01 TYPE string,
        col02 TYPE string,
        col03 TYPE string,
        col04 TYPE string,
        col05 TYPE string,
        col06 TYPE string,
        col07 TYPE string,
        col08 TYPE string,
        col09 TYPE string,
        col10 TYPE string,
        col11 TYPE string,
        col12 TYPE string,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.

    DATA full_width TYPE abap_bool VALUE abap_true.
    DATA rows       TYPE ty_t_row.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS width_apply.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_027 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
      DATA temp1 TYPE z2ui5_cl_smps_app_027=>ty_t_row.
      DATA i TYPE i.
      DATA temp3 LIKE sy-index.
        DATA temp2 LIKE LINE OF temp1.

    me->client = client.
    IF client->check_on_init( ) IS NOT INITIAL.

      IF client->get( )-check_launchpad_active = abap_false.
        client->message_box_display( `No Launchpad Active, Sample not working!` ).
      ENDIF.
      
      CLEAR temp1.
      
      i = 1.
      
      temp3 = sy-index.
      WHILE NOT i > 10.
        sy-index = temp3.
        
        temp2-col01 = |Row { i }|.
        temp2-col02 = `Lorem`.
        temp2-col03 = `ipsum`.
        temp2-col04 = `dolor`.
        temp2-col05 = `sit`.
        temp2-col06 = `amet`.
        temp2-col07 = `consetetur`.
        temp2-col08 = `sadipscing`.
        temp2-col09 = `elitr`.
        temp2-col10 = `sed`.
        temp2-col11 = `diam`.
        temp2-col12 = `nonumy`.
        INSERT temp2 INTO TABLE temp1.
        i = i + 1.
      ENDWHILE.
      rows = temp1.
      view_display( ).
      width_apply( ).

    ELSEIF client->check_on_navigated( ) IS NOT INITIAL.
      view_display( ).
      width_apply( ).

    ELSEIF client->check_on_event( `WIDTH` ) IS NOT INITIAL.
      width_apply( ).

    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA view TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA page TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA temp1 TYPE xsdboolean.
    DATA table TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA columns TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA cells TYPE REF TO z2ui5_cl_ui5_view_builder.
      DATA name TYPE string.
    view = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc` ).
    
    
    temp1 = boolc( client->get( )-check_launchpad_active = abap_false ).
    page = view->ele( `Shell`
        )->a( n = `appWidthLimited` b = abap_false
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Launchpad - Full Width`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
            )->a( n = `showHeader`     b = temp1 ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `follow_up_action( cs_event-set_app_full_width ) lets the app take the ` &&
                                 `launchpad's whole width instead of the letterbox - toggle the switch and ` &&
                                 `watch the margins left and right. Only works inside a launchpad.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( `Toolbar`
        )->tag( `Label`
            )->a( n = `text` v = `Full width`
        )->tag( `Switch`
            )->a( n = `state`  v = client->_bind( full_width )
            )->a( n = `change` v = client->_event( `WIDTH` ) ).

    
    table = page->ele( `Table`
        )->a( n = `items` v = client->_bind( rows ) ).
    
    columns = table->ele( `columns` ).
    
    cells = table->ele( `items` )->ele( `ColumnListItem` )->ele( `cells` ).
    DO 12 TIMES.
      
      name = |COL{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = `0` }|.
      columns->ele( `Column` )->tag( `Text` )->a( n = `text` t = |Column { sy-index }| ).
      cells->tag( `Text` )->a( n = `text` v = |\{{ name }\}| ).
    ENDDO.

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD width_apply.

    " X asks for the full width; without an argument the launchpad's
    " letterbox comes back (an empty argument is never sent at all)
    DATA temp4 TYPE string_table.
    DATA temp1 TYPE string_table.
    CLEAR temp4.
    INSERT `X` INTO TABLE temp4.
    
    IF full_width = abap_true.
      temp1 = temp4.
    ELSE.
      CLEAR temp1.
    ENDIF.
    client->follow_up_action(
        val   = z2ui5_if_client=>cs_event-set_app_full_width
        t_arg = temp1 ).

  ENDMETHOD.

ENDCLASS.
