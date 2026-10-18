" @keywords launchpad fiori flp url intent semantic object action link cl_lsapi_manager open_new_tab
" @summary Builds the URL of a launchpad app from semantic object, action and parameters - through cl_lsapi_manager where the system has it, as an intent URL of its own where it does not
"! <p class="shorttext synchronized">Launchpad - Build the URL of a Launchpad App</p>
"! A link into the launchpad is an intent - semantic object, action and
"! parameters behind the hash of the launchpad URL:
"!
"!     /sap/bc/ui2/flp#SalesOrder-display?SalesOrder=42
"!
"! On-premise the class cl_lsapi_manager builds it, the system alias and the
"! launchpad address of the system included:
"!
"!     DATA(url) = cl_lsapi_manager=>create_flp_url(
"!         object     = 'SalesOrder'
"!         action     = 'display'
"!         parameters = VALUE #( ( name = 'SalesOrder' value = '42' ) ) ).
"!
"! The class is not on every system - not on ABAP Cloud, not on older
"! releases - so the sample calls it by name and reads its signature at
"! runtime with RTTI. Where it is missing, the sample builds the intent URL
"! itself. Either way the URL opens in a new tab.
CLASS z2ui5_cl_smps_app_025 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA semantic_object TYPE string.
    DATA action          TYPE string.

    TYPES:
      BEGIN OF ty_s_param,
        name  TYPE string,
        value TYPE string,
      END OF ty_s_param.
    TYPES ty_t_param TYPE STANDARD TABLE OF ty_s_param WITH EMPTY KEY.
    DATA t_params TYPE ty_t_param.

    "! the URL the last press built, and who built it
    DATA url     TYPE string.
    DATA builder TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_event.

    "! cl_lsapi_manager=>create_flp_url( ), called by name - empty when the
    "! class or the method is not on this system or does not answer
    METHODS url_by_lsapi
      RETURNING
        VALUE(result) TYPE string.

    "! the intent URL built here, for every system
    METHODS url_by_intent
      RETURNING
        VALUE(result) TYPE string.

    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_025 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      semantic_object = `SalesOrder`.
      action          = `display`.
      t_params = VALUE #( ( name = `SalesOrder` value = `42` ) ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `BUILD` OR `OPEN`.
        url = url_by_lsapi( ).
        builder = `cl_lsapi_manager=>create_flp_url( )`.
        IF url IS INITIAL.
          url = url_by_intent( ).
          builder = `the intent URL of the sample - cl_lsapi_manager is not on this system`.
        ENDIF.

        IF client->get_event( ) = `OPEN`.
          client->follow_up_action( val   = client->cs_event-open_new_tab
                                    t_arg = VALUE #( ( url ) ) ).
        ENDIF.

      WHEN `ADD`.
        INSERT VALUE #( ) INTO TABLE t_params.

      WHEN `REMOVE`.
        DELETE t_params INDEX lines( t_params ).

    ENDCASE.

  ENDMETHOD.


  METHOD url_by_lsapi.

    CONSTANTS class_name  TYPE string VALUE `CL_LSAPI_MANAGER`.
    CONSTANTS method_name TYPE abap_methname VALUE `CREATE_FLP_URL`.

    DATA descr     TYPE REF TO cl_abap_typedescr.
    DATA t_ptab    TYPE abap_parmbind_tab.
    DATA value_ref TYPE REF TO data.
    DATA instance  TYPE REF TO object.
    FIELD-SYMBOLS <value> TYPE any.
    FIELD-SYMBOLS <table> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <row>   TYPE any.
    FIELD-SYMBOLS <comp>  TYPE any.

    " is the class on this system at all - a type that is not there is an
    " exception of describe_by_name, not a syntax error of this class
    cl_abap_typedescr=>describe_by_name( EXPORTING  p_name         = class_name
                                         RECEIVING  p_descr_ref    = descr
                                         EXCEPTIONS type_not_found = 1
                                                    OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(class_descr) = CAST cl_abap_objectdescr( descr ).
    READ TABLE class_descr->methods INTO DATA(s_method) WITH KEY name = method_name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    TRY.
        " one entry per parameter of the method, typed exactly as the method
        " declares it - the names and types come from the system, not from
        " this sample
        LOOP AT s_method-parameters INTO DATA(s_param).

          DATA(type) = class_descr->get_method_parameter_type( p_method_name    = method_name
                                                               p_parameter_name = s_param-name ).
          CREATE DATA value_ref TYPE HANDLE type.
          ASSIGN value_ref->* TO <value>.

          CASE s_param-name.
            WHEN 'OBJECT'.
              <value> = semantic_object.
            WHEN 'ACTION'.
              <value> = action.
            WHEN 'PARAMETERS'.
              " a table of name/value pairs - filled by component name, so
              " its row type may be whatever the system declares
              ASSIGN value_ref->* TO <table>.
              LOOP AT t_params INTO DATA(s_nav_param) WHERE name IS NOT INITIAL.
                APPEND INITIAL LINE TO <table> ASSIGNING <row>.
                ASSIGN COMPONENT 'NAME' OF STRUCTURE <row> TO <comp>.
                IF sy-subrc = 0.
                  <comp> = s_nav_param-name.
                ENDIF.
                ASSIGN COMPONENT 'VALUE' OF STRUCTURE <row> TO <comp>.
                IF sy-subrc = 0.
                  <comp> = s_nav_param-value.
                ENDIF.
              ENDLOOP.
            WHEN OTHERS.
              " a parameter this sample does not fill - an optional one is
              " left out, a mandatory one goes in initial
              IF s_param-is_optional = abap_true AND s_param-parm_kind <> cl_abap_objectdescr=>returning.
                CONTINUE.
              ENDIF.
          ENDCASE.

          " the kind from the CALLER's side: what the method imports, the
          " caller exports - and a RETURNING value is received
          INSERT VALUE #( name  = s_param-name
                          kind  = SWITCH #( s_param-parm_kind
                                            WHEN cl_abap_objectdescr=>importing THEN cl_abap_objectdescr=>exporting
                                            WHEN cl_abap_objectdescr=>exporting THEN cl_abap_objectdescr=>importing
                                            WHEN cl_abap_objectdescr=>changing  THEN cl_abap_objectdescr=>changing
                                            ELSE cl_abap_objectdescr=>receiving )
                          value = value_ref ) INTO TABLE t_ptab.

        ENDLOOP.

        IF s_method-is_class = abap_true.
          CALL METHOD (class_name)=>(method_name)
            PARAMETER-TABLE t_ptab.
        ELSE.
          CALL METHOD (class_name)=>('GET_INSTANCE')
            RECEIVING
              result = instance.
          CALL METHOD instance->(method_name)
            PARAMETER-TABLE t_ptab.
        ENDIF.

        " the URL is whatever the method hands back
        LOOP AT t_ptab INTO DATA(s_ptab) WHERE kind = cl_abap_objectdescr=>receiving.
          ASSIGN s_ptab-value->* TO <value>.
          result = <value>.
        ENDLOOP.

      CATCH cx_root.
        " the method exists but does not answer the way this sample asks -
        " the intent URL of the sample takes over
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD url_by_intent.

    " #<semantic object>-<action>?<name>=<value>&... behind the launchpad of
    " this system - every value URL-encoded
    DATA(query) = concat_lines_of(
        table = VALUE string_table( FOR s_param IN t_params WHERE ( name IS NOT INITIAL )
                                    ( |{ escape( val = s_param-name format = cl_abap_format=>e_url_full ) }={
                                         escape( val = s_param-value format = cl_abap_format=>e_url_full ) }| ) )
        sep   = `&` ).

    result = |/sap/bc/ui2/flp#{ semantic_object }-{ action }|.
    IF query IS NOT INITIAL.
      result = |{ result }?{ query }|.
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
            )->a( n = `title`          v = `abap2UI5 - Launchpad - Build the URL of a Launchpad App`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Semantic object, action and parameters make the intent of a launchpad app. Build URL ` &&
                                 `asks cl_lsapi_manager where the system has it and builds the intent URL itself where ` &&
                                 `it does not - Open opens the result in a new tab.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `The intent`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Semantic Object`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( semantic_object )
            )->tag( `Label`
                )->a( n = `text` v = `Action`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( action ) ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( t_params ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Parameters`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `ADD` )
                )->a( n = `icon`    v = `sap-icon://add`
                )->a( n = `tooltip` v = `Add Parameter`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REMOVE` )
                )->a( n = `icon`    v = `sap-icon://less`
                )->a( n = `tooltip` v = `Remove Last Parameter` ).
    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Name`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Value` ).
    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Input`
                    )->a( n = `value` v = `{NAME}`
                )->tag( `Input`
                    )->a( n = `value` v = `{VALUE}` ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `The URL`
        )->a( n = `editable` b = abap_false
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `URL`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( url )
            )->tag( `Label`
                )->a( n = `text` v = `Built by`
            )->tag( `Text`
                )->a( n = `text` v = client->_bind( builder ) ).

    page->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `BUILD` )
                )->a( n = `text`  v = `Build URL`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `OPEN` )
                )->a( n = `text`  v = `Open`
                )->a( n = `icon`  v = `sap-icon://action`
                )->a( n = `type`  v = `Emphasized` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
