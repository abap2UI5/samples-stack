" @keywords filterbar filtergroupitem smartvariantmanagement classic filter variant
" @summary no service needed - the data is ABAP
CLASS z2ui5_cl_smps_app_493 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_product,
        product  TYPE string,
        category TYPE string,
        supplier TYPE string,
        price    TYPE string,
      END OF ty_s_product.
    TYPES ty_t_product TYPE STANDARD TABLE OF ty_s_product WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_filter,
        product  TYPE string,
        category TYPE string,
        supplier TYPE string,
      END OF ty_s_filter.

    " bound into the view, so both must be PUBLIC: only public attributes are
    " serialized into the model, and a bound protected one fails the first
    " roundtrip with BINDING_ERROR
    DATA ms_filter TYPE ty_s_filter.
    DATA mt_result TYPE ty_t_product.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.


    METHODS data_all
      RETURNING
        VALUE(result) TYPE ty_t_product.

    METHODS search.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_493 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ) IS NOT INITIAL.

      mt_result = data_all( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ) IS NOT INITIAL.
      view_display( ).
    ELSEIF client->check_on_event( `SEARCH` ) IS NOT INITIAL.
      search( ).
      client->message_toast_display( |{ lines( mt_result ) } products| ).
    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA view TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA page TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA filter TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA tab TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA temp1 TYPE string_table.
    view = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock`                 v = `true`
            )->a( n = `height`                       v = `100%`
            )->a( n = `xmlns`                        v = `sap.m`
            )->a( n = `xmlns:mvc`                    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:fb`                     v = `sap.ui.comp.filterbar`
            )->a( n = `xmlns:smartVariantManagement` v = `sap.ui.comp.smartvariants` ).

    
    page = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Smart Controls - Classic FilterBar Variants`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Enter filters, press Go, then save the selection as a variant. `
                && `Selecting it again restores the values into the fields AND into `
                && `ABAP - the binding carries them back, so Go filters on `
                && `the restored values without any extra wiring.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    " The variant container. It owns the persistency (sap.ui.fl / LREP) and
    " is the only piece a SmartFilterBar would bring along by itself - see
    " sample 478 for that variant of the same screen. Its initialise( )
    " handshake is cs_event-filter_bar_variant_init at the end of this method,
    " not cs_event-smart_variant_init.
    page->ele( `HBox`
        )->tag( n = `SmartVariantManagement` ns = `smartVariantManagement`
            )->a( n = `id`             v = `variantMgmt`
            )->a( n = `persistencyKey` v = `Z2UI5_493_VARIANT` ).

    " A CLASSIC sap.ui.comp.filterbar.FilterBar: unlike a SmartFilterBar it
    " has no OData metadata to build itself from, so its filters are named
    " here and their controls are ordinary sap.m inputs, bound like
    " in any other abap2UI5 app. persistencykey is what the variant is
    " stored under - the wiring action below hands it to the variant
    " management as the PersonalizableInfo keyName.
    
    filter = page->ele( n = `FilterBar` ns = `fb`
        )->a( n = `useToolbar`     b = abap_false
        )->a( n = `search`         v = client->_event( `SEARCH` )
        )->a( n = `id`             v = `filterBar`
        )->a( n = `persistencyKey` v = `Z2UI5_493_FILTERBAR`
        )->ele( n = `filterGroupItems` ns = `fb` ).

    filter->ele( n = `FilterGroupItem` ns = `fb`
        )->a( n = `name`               v = `PRODUCT`
        )->a( n = `label`              v = `Product`
        )->a( n = `groupName`          v = `__BASIC`
        )->a( n = `visibleInFilterBar` b = abap_true
        )->ele( n = `control` ns = `fb`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( ms_filter-product ) ).

    filter->ele( n = `FilterGroupItem` ns = `fb`
        )->a( n = `name`               v = `CATEGORY`
        )->a( n = `label`              v = `Category`
        )->a( n = `groupName`          v = `__BASIC`
        )->a( n = `visibleInFilterBar` b = abap_true
        )->ele( n = `control` ns = `fb`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( ms_filter-category ) ).

    filter->ele( n = `FilterGroupItem` ns = `fb`
        )->a( n = `name`               v = `SUPPLIER`
        )->a( n = `label`              v = `Supplier`
        )->a( n = `groupName`          v = `__BASIC`
        )->a( n = `visibleInFilterBar` b = abap_true
        )->ele( n = `control` ns = `fb`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( ms_filter-supplier ) ).

    
    tab = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( mt_result )
        )->a( n = `headerText` v = `Products` ).

    tab->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Product`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Category`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Supplier`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Price` ).

    tab->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{PRODUCT}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CATEGORY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{SUPPLIER}`
                )->tag( `Text`
                    )->a( n = `text` v = `{PRICE}` ).

    client->view_display( view->stringify( ) ).

    " Everything a list-report controller would hand-write for a classic
    " FilterBar: registerFetchData / registerApplyData /
    " registerGetFiltersWithValues, addPersonalizableControl( ) with a
    " PersonalizableInfo, and a change handler per filter field that marks
    " the variant as modified. All of it is boilerplate over the bar's own
    " filter items, so the framework owns it and this app writes no
    " JavaScript. A SmartFilterBar registers itself instead and only needs
    " cs_event-smart_variant_init (sample 478).
    
    CLEAR temp1.
    INSERT `variantMgmt` INTO TABLE temp1.
    INSERT `filterBar` INTO TABLE temp1.
    client->follow_up_action( val   = client->cs_event-filter_bar_variant_init
                              t_arg = temp1 ).

  ENDMETHOD.


  METHOD search.

    " the restored variant values arrived through the binding of the
    " filter controls, so ms_filter is already current here - selecting a
    " variant needs no roundtrip of its own
    DATA temp3 TYPE z2ui5_cl_smps_app_493=>ty_t_product.
    DATA temp4 TYPE z2ui5_cl_smps_app_493=>ty_t_product.
    DATA ls_row LIKE LINE OF temp4.
    CLEAR temp3.
    mt_result = temp3.
    
    temp4 = data_all( ).
    
    LOOP AT temp4 INTO ls_row.
      IF ms_filter-product IS NOT INITIAL AND ls_row-product NS ms_filter-product.
        CONTINUE.
      ENDIF.
      IF ms_filter-category IS NOT INITIAL AND ls_row-category NS ms_filter-category.
        CONTINUE.
      ENDIF.
      IF ms_filter-supplier IS NOT INITIAL AND ls_row-supplier NS ms_filter-supplier.
        CONTINUE.
      ENDIF.
      INSERT ls_row INTO TABLE mt_result.
    ENDLOOP.

  ENDMETHOD.


  METHOD data_all.

    DATA temp5 TYPE z2ui5_cl_smps_app_493=>ty_t_product.
    DATA temp6 LIKE LINE OF temp5.
    CLEAR temp5.
    
    temp6-product = `Notebook Basic 15`.
    temp6-category = `Notebooks`.
    temp6-supplier = `SAP`.
    temp6-price = `956.00`.
    INSERT temp6 INTO TABLE temp5.
    temp6-product = `Notebook Basic 17`.
    temp6-category = `Notebooks`.
    temp6-supplier = `SAP`.
    temp6-price = `1249.00`.
    INSERT temp6 INTO TABLE temp5.
    temp6-product = `ITelO Vault`.
    temp6-category = `Storage`.
    temp6-supplier = `ITelO`.
    temp6-price = `299.00`.
    INSERT temp6 INTO TABLE temp5.
    temp6-product = `Comfort Easy`.
    temp6-category = `Storage`.
    temp6-supplier = `Technocom`.
    temp6-price = `1679.00`.
    INSERT temp6 INTO TABLE temp5.
    temp6-product = `Ergo Screen E-I`.
    temp6-category = `Monitors`.
    temp6-supplier = `Technocom`.
    temp6-price = `230.00`.
    INSERT temp6 INTO TABLE temp5.
    temp6-product = `Flat Basic`.
    temp6-category = `Monitors`.
    temp6-supplier = `ITelO`.
    temp6-price = `399.00`.
    INSERT temp6 INTO TABLE temp5.
    temp6-product = `Smart Eye Blue`.
    temp6-category = `Monitors`.
    temp6-supplier = `SAP`.
    temp6-price = `499.00`.
    INSERT temp6 INTO TABLE temp5.
    temp6-product = `Gladiator MX`.
    temp6-category = `Graphics`.
    temp6-supplier = `Technocom`.
    temp6-price = `89.00`.
    INSERT temp6 INTO TABLE temp5.
    result = temp5.

  ENDMETHOD.

ENDCLASS.
