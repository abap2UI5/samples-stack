" @keywords smartvariantmanagement page variant save smarttable smartfilterbar filter
" @summary needs the GWSAMPLE_BASIC OData service
CLASS z2ui5_cl_smps_app_478 DEFINITION PUBLIC.

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


CLASS z2ui5_cl_smps_app_478 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    IF client->check_on_navigated( ).

      DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
          )->ele( n = `View` ns = `mvc`
              )->a( n = `displayBlock`                 v = `true`
              )->a( n = `height`                       v = `100%`
              )->a( n = `xmlns`                        v = `sap.m`
              )->a( n = `xmlns:mvc`                    v = `sap.ui.core.mvc`
              )->a( n = `xmlns:core`                   v = `sap.ui.core`
              )->a( n = `xmlns:smartFilterBar`         v = `sap.ui.comp.smartfilterbar`
              )->a( n = `xmlns:smartTable`             v = `sap.ui.comp.smarttable`
              )->a( n = `xmlns:smartVariantManagement` v = `sap.ui.comp.smartvariants` ).

      DATA(page) = view->ele( `Shell`
          )->ele( `Page`
              )->a( n = `title`          v = `abap2UI5 - Smart Controls - Page Variant`
              )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
              )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

      " Page variant: one SmartVariantManagement in front of the page owns the
      " persistency (PageVariantPKey) and both smart controls register with it
      " through their smartvariant association, each contributing its own
      " persistencykey. Everything below is metadata-driven - no model data.
      page->ele( `HBox`
          )->tag( n = `SmartVariantManagement` ns = `smartVariantManagement`
              )->a( n = `id`             v = `pageVariantId`
              )->a( n = `persistencyKey` v = `PageVariantPKey` ).

      " The tutorial's onFiltersChanged handler is not published, so there is no
      " original body to rebuild - but the original IS a controller function, i.e.
      " client-side. The wire therefore stays roundtrip-free (control_global
      " MESSAGE_TOAST): a backend round-trip fired in the middle of the variant /
      " filter handshake is exactly what a smart control does not expect.
      page->ele( n = `SmartFilterBar` ns = `smartFilterBar`
          )->a( n = `id`                     v = `smartFilterBar`
          )->a( n = `entitySet`              v = `ProductSet`
          )->a( n = `persistencyKey`         v = `SmartFilterPKey`
          )->a( n = `smartVariant`           v = `pageVariantId`
          )->a( n = `assignedFiltersChanged` v = client->follow_up_action(
              val   = client->cs_event-control_global
              t_arg = VALUE #( ( `MESSAGE_TOAST` ) ( `show` ) ( `Assigned filters changed` ) ) )
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
          )->a( n = `useVariantManagement`    v = `true`
          )->a( n = `useTablePersonalisation` v = `true`
          )->a( n = `header`                  v = `Products`
          )->a( n = `showRowCount`            v = `true`
          )->a( n = `enableExport`            v = `false`
          )->a( n = `enableAutoBinding`       v = `true`
          )->a( n = `persistencyKey`          v = `SmartTablePKey`
          )->a( n = `smartVariant`            v = `pageVariantId` ).

      client->view_display( val = view->stringify( ) switch_default_model_path = c_odata_service ).

      " The handshake a controller would do: without initialise( ) the page variant
      " never gets a personalizable control, so saving a view dies in sap.ui.fl and
      " stored views are never loaded. The action waits for the smart controls to
      " register, which they do once their metadata has arrived.
      client->follow_up_action( val   = client->cs_event-smart_variant_init
                                t_arg = VALUE #( ( `pageVariantId` ) ( `smartFilterBar` ) ) ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
