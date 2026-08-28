" @keywords smartfilterbar smarttable filter search annotations controlconfiguration
" @summary needs the GWSAMPLE_BASIC OData service
CLASS z2ui5_cl_smps_app_477 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
    " Smart controls build their UI from OData V2 metadata, so this app carries no
    " ABAP data at all - it switches the default model to a service instead. The
    " SAP Gateway demo service GWSAMPLE_BASIC ships with every on-premise system
    " and only has to be activated once in /IWFND/MAINT_SERVICE. Its entity set is
    " ProductSet, which is why the tutorial's Products entity set is mapped onto it.
    CONSTANTS c_odata_service TYPE string VALUE `/sap/opu/odata/IWBEP/GWSAMPLE_BASIC/`.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_477 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    IF client->check_on_navigated( ).

      DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
          )->ele( n = `View` ns = `mvc`
              )->a( n = `displayBlock`         v = `true`
              )->a( n = `height`               v = `100%`
              )->a( n = `xmlns`                v = `sap.m`
              )->a( n = `xmlns:mvc`            v = `sap.ui.core.mvc`
              )->a( n = `xmlns:core`           v = `sap.ui.core`
              )->a( n = `xmlns:smartFilterBar` v = `sap.ui.comp.smartfilterbar`
              )->a( n = `xmlns:smartTable`     v = `sap.ui.comp.smarttable` ).

      DATA(page) = view->ele( `Shell`
          )->ele( `Page`
              )->a( n = `title`          v = `abap2UI5 - Smart Controls - SmartTable`
              )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
              )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

      " No model data and no event wiring: the SmartTable binds itself
      " (enableautobinding) and reads the SmartFilterBar's conditions through the
      " smartfilterid association - the whole app is the view plus the service.
      page->ele( n = `SmartFilterBar` ns = `smartFilterBar`
          )->a( n = `id`        v = `smartFilterBar`
          )->a( n = `entitySet` v = `ProductSet`
          )->ele( n = `controlConfiguration` ns = `smartFilterBar`
              )->tag( n = `ControlConfiguration` ns = `smartFilterBar`
                  )->a( n = `key`                                      v = `Category`
                  )->a( n = `visibleInAdvancedArea`                    v = `true`
                  )->a( n = `preventInitialDataFetchInValueHelpDialog` v = `false` ).

      " GWSAMPLE_BASIC carries no UI.LineItem annotation, and without one a
      " SmartTable starts with NO columns at all - it renders the "add columns to
      " see the content" placeholder instead of falling back to all metadata
      " fields. The initially visible fields therefore have to be named; the
      " tutorial's own service annotates the four columns it shows.
      page->ele( n = `SmartTable` ns = `smartTable`
          )->a( n = `id`                      v = `smartTable_ResponsiveTable`
          )->a( n = `smartFilterId`           v = `smartFilterBar`
          )->a( n = `tableType`               v = `ResponsiveTable`
          )->a( n = `editable`                v = `false`
          )->a( n = `initiallyVisibleFields`  v = `ProductID,Name,Category,SupplierName,Price`
          )->a( n = `entitySet`               v = `ProductSet`
          )->a( n = `useVariantManagement`    v = `false`
          )->a( n = `useTablePersonalisation` v = `false`
          )->a( n = `header`                  v = `Products`
          )->a( n = `showRowCount`            v = `true`
          )->a( n = `enableExport`            v = `false`
          )->a( n = `enableAutoBinding`       v = `true` ).

      client->view_display( val = view->stringify( ) switch_default_model_path = c_odata_service ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
