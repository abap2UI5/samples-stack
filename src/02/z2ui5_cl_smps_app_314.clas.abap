" @keywords switch_default_model_path odata model default binding smart controls
" @summary device, HTTP and OData model side by side - GWSAMPLE_BASIC
CLASS z2ui5_cl_smps_app_314 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_row,
        count      TYPE i,
        value      TYPE string,
        descr      TYPE string,
        icon       TYPE string,
        info       TYPE string,
        checkbox   TYPE abap_bool,
        percentage TYPE p LENGTH 5 DECIMALS 2,
        valuecolor TYPE string,
      END OF ty_s_row.
    DATA t_tab TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    DATA mv_val TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_314 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    DATA ls_row TYPE ty_s_row.

    me->client = client.

    IF client->check_on_init( ).

      DO 10 TIMES.
        ls_row-count = sy-index.
        ls_row-value = `red`.
        ls_row-descr = `this is a description`.
        ls_row-checkbox = abap_true.
        ls_row-valuecolor = `Good`.
        INSERT ls_row INTO TABLE t_tab.
      ENDDO.
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ENDIF.

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
            )->a( n = `title`          v = `abap2UI5 - Device Model, HTTP Model, OData Model`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `Input`
        )->a( n = `description` v = `device model`
        )->a( n = `enabled`     b = abap_false
        )->a( n = `value`       v = `{device>/resize/width}` ).

    mv_val = `input value with http model`.
    page->tag( `Input`
        )->a( n = `value` v = client->_bind( val                  = mv_val
                                     switch_default_model = abap_true ) ).

    DATA(tab) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( val                  = t_tab
                                                 switch_default_model = abap_true ) ).

    tab->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `table with http model (framework default)` ).

    tab->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Value`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Info`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description`
        )->end( ).

    tab->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>VALUE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>INFO}`
                )->tag( `Text`
                    )->a( n = `text` v = `{http>DESCR}` ).

    tab = page->ele( `Table`
        " abap2ui5lint-disable-next-line unknown-binding-path hardcoded-binding-path -- the default model IS the OData service here (switch_default_model_path), so the entity set is an absolute service path with no ABAP variable to derive it from
        )->a( n = `items`   v = `{/BusinessPartnerSet}`
        )->a( n = `growing` b = abap_true ).

    tab->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `table with odata model` ).

    tab->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `BusinessPartnerID`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `CompanyName`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `WebAddress`
        )->end( ).

    tab->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{BusinessPartnerID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CompanyName}`
                )->tag( `Text`
                    )->a( n = `text` v = `{WebAddress}` ).
*             )->tag( `Text` )->a( n = `text` v = `{SupplementID}`
*             )->tag( `Text` )->a( n = `text` v = `{SupplementText}`
*             )->tag( `Text` )->a( n = `text` v = `{Price}`
*             )->tag( `Text` )->a( n = `text` v = `{CurrencyCode}` ).

    client->view_display( val = view->stringify( ) switch_default_model_path = `/sap/opu/odata/iwbep/gwsample_basic/` ).
*                            switch_default_model_path = `/sap/opu/odata/DMO/API_TRAVEL_U_V2/` ).

  ENDMETHOD.

ENDCLASS.
