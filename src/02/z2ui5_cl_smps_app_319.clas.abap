" @keywords smartmultiinput multi input tokens smart controls odata
" @summary UI conditions mapped 1:1 onto an ABAP range table
"! SmartMultiInput (sap.ui.comp) - the strength of one control: it gives the user
"! a full SELECT-OPTIONS experience (value help from OData, multiple conditions,
"! operators like contains / between / greater-than, and include/exclude) and
"! hands the backend a structured range that maps 1:1 onto an ABAP SELECT-OPTIONS.
"!
"! This demo wires that end to end: define conditions on "Product Type" via the
"! value help, and the backend translates the returned ranges into an ABAP range
"! table (r in ty_s_range -> SIGN/OPTION/LOW/HIGH) and filters a local product
"! list with `... WHERE product_type IN r_product_type`. Both the derived SELECT-OPTIONS
"! and the matching rows are shown, so the "UI condition -> ABAP range" mapping is
"! visible.
"!
"! Needs SAPUI5 (sap.ui.comp is SAPUI5-only) and a reachable, value-list-annotated
"! OData V2 service - see the OData service block in on_init.
CLASS z2ui5_cl_smps_app_319 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_token,
        key  TYPE string,
        text TYPE string,
      END OF ty_s_token,
      ty_t_token TYPE STANDARD TABLE OF ty_s_token WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_s_range,
        exclude      TYPE abap_bool,
        operation    TYPE string,
        value1       TYPE string,
        value2       TYPE string,
        keyfield     TYPE string,
        tokentext    TYPE string,
        tokenlongkey TYPE string,
      END OF ty_s_range,
      ty_t_range TYPE STANDARD TABLE OF ty_s_range WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_s_product,
        product_type TYPE string,
        name         TYPE string,
      END OF ty_s_product.
    TYPES:
      " display row for the derived SELECT-OPTIONS (plain strings so binding
      " serializes safely everywhere; the real RANGE is only built locally)
      BEGIN OF ty_s_selopt,
        sign   TYPE string,
        option TYPE string,
        low    TYPE string,
        high   TYPE string,
      END OF ty_s_selopt.

    DATA:
      BEGIN OF m_selection,
        BEGIN OF product_type,
          tokens_added   TYPE ty_t_token,
          tokens_removed TYPE ty_t_token,
          ranges         TYPE ty_t_range,
        END OF product_type,
      END OF m_selection.

    " the filtered result + the derived SELECT-OPTIONS - both bound
    DATA t_result TYPE STANDARD TABLE OF ty_s_product WITH EMPTY KEY.
    DATA t_selopt TYPE STANDARD TABLE OF ty_s_selopt WITH EMPTY KEY.
    DATA hint     TYPE string.

  PROTECTED SECTION.
    DATA m_client TYPE REF TO z2ui5_if_client.
    " the local demo data the result is filtered from - never bound, so it
    " needs no PUBLIC: state survives the roundtrip at PROTECTED too
    DATA t_product TYPE STANDARD TABLE OF ty_s_product WITH EMPTY KEY.

    METHODS on_init.
    METHODS view_display.
    METHODS on_event.
    METHODS do_search.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_319 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    m_client = client.

    IF m_client->check_on_init( ).
      on_init( ).
      RETURN.
    ELSEIF m_client->check_on_navigated( ).
      view_display( ).
      RETURN.
    ENDIF.

    on_event( ).

  ENDMETHOD.


  METHOD on_init.

    " local demo product list the derived range filters (see class doc). The
    " product types are readable words so the "contains"/"starts with" operators
    " visibly hit something when you type free text into the value help.
    t_product = VALUE #(
      ( product_type = `SERVICE`  name = `Cloud Hosting` )
      ( product_type = `SERVER`   name = `Rack Server X1` )
      ( product_type = `SENSOR`   name = `IoT Sensor` )
      ( product_type = `SOFTWARE` name = `ERP License` )
      ( product_type = `HARDWARE` name = `Laptop Pro` )
      ( product_type = `MATERIAL` name = `Steel Sheet` )
      ( product_type = `SUPPORT`  name = `Gold Support` )
      ( product_type = `TRAINING` name = `ABAP Course` )
      ( product_type = `LICENSE`  name = `DB License` )
      ( product_type = `SEMIFIN`  name = `Semi-finished Part` ) ).
    t_result = t_product.
    hint     = `No conditions yet - showing all demo products. Open the value help and add conditions.`.

    view_display( ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:smi`    v = `sap.ui.comp.smartmultiinput`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc` ).

    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Smart Controls - SmartMultiInput to SELECT-OPTIONS`
            )->a( n = `showNavButton`  b = m_client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = m_client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text` v = `Open the value help (icon on the right), add one or more conditions on Product Type ` &&
                   `(contains, between, greater than, exclude ...). Each condition is turned into an ABAP ` &&
                   `SELECT-OPTIONS row and filters the demo product list below.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    " the invisible companion mirrors tokens + range data into the (switched) app
    " model so the backend can read AND restore the input across roundtrips
    page->tag( n = `SmartMultiInputExt` ns = `z2ui5`
        )->a( n = `multiInputId`  v = `ProductTypeMultiInput`
        )->a( n = `rangeData`     v = m_client->_bind( val = m_selection-product_type-ranges switch_default_model = abap_true )
        )->a( n = `change`        v = m_client->_event( `PRODTYPE_CHANGED` )
        )->a( n = `addedTokens`   v = m_client->_bind( val = m_selection-product_type-tokens_added switch_default_model = abap_true )
        )->a( n = `removedTokens` v = m_client->_bind( val = m_selection-product_type-tokens_removed switch_default_model = abap_true ) ).

    page->ele( n = `SmartMultiInput` ns = `smi`
        )->a( n = `id`                v = `ProductTypeMultiInput`
        )->a( n = `value`             v = `{ProductType}`
        )->a( n = `entitySet`         v = `ProductType_2`
        )->a( n = `supportRanges`     v = `true`
        )->a( n = `enableODataSelect` v = `true` ).

    page->tag( `Button`
        )->a( n = `press` v = m_client->_event( `SEARCH` )
        )->a( n = `text`  v = `Search`
        )->a( n = `icon`  v = `sap-icon://search`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `class` v = `sapUiSmallMarginBegin` ).

    page->ele( `ObjectStatus`
        )->a( n = `text`  v = m_client->_bind( val = hint switch_default_model = abap_true )
        )->a( n = `class` v = `sapUiSmallMargin` ).

    " derived ABAP SELECT-OPTIONS (r_product_type): SIGN / OPTION / LOW / HIGH
    DATA(sel) = page->ele( `Table`
        )->a( n = `items` v = m_client->_bind( val = t_selopt switch_default_model = abap_true ) ).
    sel->ele( `headerToolbar`
        )->ele( `OverflowToolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Derived ABAP SELECT-OPTIONS  ( ... WHERE ProductType IN r_product_type )` ).
    sel->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `SIGN`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `OPTION`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `LOW`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `HIGH` ).
    sel->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>SIGN}`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>OPTION}`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>LOW}`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>HIGH}` ).

    " the rows the range selects out of the demo product list
    DATA(res) = page->ele( `Table`
        )->a( n = `items` v = m_client->_bind( val = t_result switch_default_model = abap_true ) ).
    res->ele( `headerToolbar`
        )->ele( `OverflowToolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Matching demo products (local sample data)` ).
    res->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Product Type`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Name` ).
    res->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>PRODUCT_TYPE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>NAME}` ).

    " OData service block - adjust to your value-list-annotated Gateway service.
    " The SmartMultiInput's value help (Product Type) comes from here; the demo
    " filter above is pure ABAP and independent of it.
    m_client->view_display( val                           = page->stringify( )
                            switch_default_model_path     = `/sap/opu/odata/sap/UI_PRODUCTLIST`
                            switch_default_model_anno_uri = `/sap/opu/odata/IWFND/CATALOGSERVICE;v=2/Annotations(TechnicalName='UI_PRODUCTLIST_VAN',Version='0001')/$value` ).

  ENDMETHOD.


  METHOD on_event.

    CASE m_client->get_event( ).
      WHEN `PRODTYPE_CHANGED` OR `SEARCH`.
        do_search( ).
    ENDCASE.

  ENDMETHOD.


  METHOD do_search.

    " The payoff of this sample: the range operators the SmartMultiInput hands
    " back become a real ABAP range in lr_type, ready to drop into any SELECT
    " the way a selection screen's would be. t_selopt is only its readable
    " copy for the display table.
    " (abaplint reads a comment that opens on "translate ... into ABAP
    " SELECT-OPTIONS" as commented-out code, which is why it is worded this
    " way round.)
    DATA lr_type TYPE RANGE OF string.
    DATA sign    TYPE c LENGTH 1.
    DATA option  TYPE c LENGTH 2.
    DATA low     TYPE string.
    DATA high    TYPE string.

    t_selopt = VALUE #( ).
    lr_type  = VALUE #( ).
    LOOP AT m_selection-product_type-ranges INTO DATA(s).

      sign   = COND #( WHEN s-exclude = abap_true THEN `E` ELSE `I` ).
      option = `EQ`.
      low    = s-value1.
      high   = s-value2.

      CASE to_upper( s-operation ).
        WHEN `EQ`.           option = `EQ`.
        WHEN `NE`.           option = `NE`.
        WHEN `CONTAINS`.     option = `CP`. low = |*{ s-value1 }*|.
        WHEN `NOTCONTAINS`.  option = `CP`. low = |*{ s-value1 }*|. sign = `E`.
        WHEN `STARTSWITH`.   option = `CP`. low = |{ s-value1 }*|.
        WHEN `ENDSWITH`.     option = `CP`. low = |*{ s-value1 }|.
        WHEN `BT`.           option = `BT`.
        WHEN `NB`.           option = `NB`.
        WHEN `GT`.           option = `GT`.
        WHEN `GE`.           option = `GE`.
        WHEN `LT`.           option = `LT`.
        WHEN `LE`.           option = `LE`.
        WHEN `EMPTY`.        option = `EQ`. low = ``.
        WHEN OTHERS.         option = `EQ`.
      ENDCASE.

      APPEND VALUE #( sign = sign option = option low = low high = high ) TO lr_type.
      APPEND VALUE #( sign = sign option = option low = low high = high ) TO t_selopt.
    ENDLOOP.

    " apply the derived SELECT-OPTIONS just like any ABAP query would
    t_result = VALUE #( ).
    IF lr_type IS INITIAL.
      t_result = t_product.
      hint     = |No conditions - showing all { lines( t_product ) } demo products.|.
    ELSE.
      LOOP AT t_product INTO DATA(p) WHERE product_type IN lr_type.
        APPEND p TO t_result.
      ENDLOOP.
      hint = |{ lines( t_selopt ) } condition(s) -> { lines( t_result ) } of { lines( t_product ) } demo products match.|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
