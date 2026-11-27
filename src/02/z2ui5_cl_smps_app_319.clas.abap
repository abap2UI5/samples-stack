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
      ty_t_token TYPE STANDARD TABLE OF ty_s_token WITH DEFAULT KEY.
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
      ty_t_range TYPE STANDARD TABLE OF ty_s_range WITH DEFAULT KEY.
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
    DATA t_result TYPE STANDARD TABLE OF ty_s_product WITH DEFAULT KEY.
    DATA t_selopt TYPE STANDARD TABLE OF ty_s_selopt WITH DEFAULT KEY.
    DATA hint     TYPE string.

  PROTECTED SECTION.
    DATA m_client TYPE REF TO z2ui5_if_client.
    " the local demo data the result is filtered from - never bound, so it
    " needs no PUBLIC: state survives the roundtrip at PROTECTED too
    DATA t_product TYPE STANDARD TABLE OF ty_s_product WITH DEFAULT KEY.

    METHODS view_display.
    METHODS on_event.
    METHODS model_init.
    METHODS do_search.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_319 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    m_client = client.
    IF m_client->check_on_init( ) IS NOT INITIAL.
      model_init( ).
      view_display( ).
    ELSEIF m_client->check_on_navigated( ) IS NOT INITIAL.
      view_display( ).
    ELSEIF m_client->check_on_event( ) IS NOT INITIAL.
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA view TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA page TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA sel TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA res TYPE REF TO z2ui5_cl_ui5_view_builder.
    view = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:smi`    v = `sap.ui.comp.smartmultiinput`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc` ).

    
    page = view->ele( `Shell`
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
    
    sel = page->ele( `Table`
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
    
    res = page->ele( `Table`
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
    DATA skipped TYPE i.

    DATA temp1 LIKE t_selopt.
    DATA temp2 LIKE lr_type.
    DATA s LIKE LINE OF m_selection-product_type-ranges.
      DATA temp3 LIKE sign.
      DATA operation TYPE string.
        DATA temp4 LIKE sign.
      DATA temp5 LIKE LINE OF lr_type.
      DATA temp6 TYPE z2ui5_cl_smps_app_319=>ty_s_selopt.
    DATA temp7 LIKE t_result.
      DATA p LIKE LINE OF t_product.
    CLEAR temp1.
    t_selopt = temp1.
    
    CLEAR temp2.
    lr_type  = temp2.
    
    LOOP AT m_selection-product_type-ranges INTO s.

      
      IF s-exclude = abap_true.
        temp3 = `E`.
      ELSE.
        temp3 = `I`.
      ENDIF.
      sign   = temp3.
      option = `EQ`.
      low    = s-value1.
      high   = s-value2.

      " the Not* operations (NotEQ, NotBT, NotContains, NotEmpty, ...) are
      " their positive twin with the sign turned round - read as EQ, they
      " selected exactly the rows the user had asked to leave out
      
      operation = to_upper( s-operation ).
      IF strlen( operation ) > 3 AND substring( val = operation len = 3 ) = `NOT`.
        operation = substring( val = operation off = 3 ).
        
        IF sign = `I`.
          temp4 = `E`.
        ELSE.
          temp4 = `I`.
        ENDIF.
        sign = temp4.
      ENDIF.

      CASE operation.
        WHEN `EQ` OR ``.   option = `EQ`.
        WHEN `NE`.         option = `NE`.
        WHEN `CONTAINS`.   option = `CP`. low = |*{ s-value1 }*|.
        WHEN `STARTSWITH`. option = `CP`. low = |{ s-value1 }*|.
        WHEN `ENDSWITH`.   option = `CP`. low = |*{ s-value1 }|.
        WHEN `BT`.         option = `BT`.
        WHEN `NB`.         option = `NB`.
        WHEN `GT`.         option = `GT`.
        WHEN `GE`.         option = `GE`.
        WHEN `LT`.         option = `LT`.
        WHEN `LE`.         option = `LE`.
        WHEN `EMPTY` OR `INITIAL`.
          option = `EQ`.
          low    = ``.
          high   = ``.
        WHEN OTHERS.
          " an operation this mapping does not know is left out rather than
          " guessed - an EQ on its first value would filter on something the
          " user never asked for
          skipped = skipped + 1.
          CONTINUE.
      ENDCASE.

      
      CLEAR temp5.
      temp5-sign = sign.
      temp5-option = option.
      temp5-low = low.
      temp5-high = high.
      INSERT temp5 INTO TABLE lr_type.
      
      CLEAR temp6.
      temp6-sign = sign.
      temp6-option = option.
      temp6-low = low.
      temp6-high = high.
      INSERT temp6 INTO TABLE t_selopt.
    ENDLOOP.

    " apply the derived SELECT-OPTIONS just like any ABAP query would
    
    CLEAR temp7.
    t_result = temp7.
    IF lr_type IS INITIAL.
      t_result = t_product.
      hint     = |No conditions - showing all { lines( t_product ) } demo products.|.
    ELSE.
      
      LOOP AT t_product INTO p WHERE product_type IN lr_type.
        INSERT p INTO TABLE t_result.
      ENDLOOP.
      hint = |{ lines( t_selopt ) } condition(s) -> { lines( t_result ) } of { lines( t_product ) } demo products match.|.
    ENDIF.
    IF skipped > 0.
      hint = |{ hint } { skipped } condition(s) with an operation this sample does not map were left out.|.
    ENDIF.

  ENDMETHOD.


  METHOD model_init.

    " local demo product list the derived range filters (see class doc). The
    " product types are readable words so the "contains"/"starts with" operators
    " visibly hit something when you type free text into the value help.
    DATA temp8 LIKE t_product.
    DATA temp9 LIKE LINE OF temp8.
    CLEAR temp8.
    
    temp9-product_type = `SERVICE`.
    temp9-name = `Cloud Hosting`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `SERVER`.
    temp9-name = `Rack Server X1`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `SENSOR`.
    temp9-name = `IoT Sensor`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `SOFTWARE`.
    temp9-name = `ERP License`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `HARDWARE`.
    temp9-name = `Laptop Pro`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `MATERIAL`.
    temp9-name = `Steel Sheet`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `SUPPORT`.
    temp9-name = `Gold Support`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `TRAINING`.
    temp9-name = `ABAP Course`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `LICENSE`.
    temp9-name = `DB License`.
    INSERT temp9 INTO TABLE temp8.
    temp9-product_type = `SEMIFIN`.
    temp9-name = `Semi-finished Part`.
    INSERT temp9 INTO TABLE temp8.
    t_product = temp8.
    t_result = t_product.
    hint     = `No conditions yet - showing all demo products. Open the value help and add conditions.`.

  ENDMETHOD.

ENDCLASS.
