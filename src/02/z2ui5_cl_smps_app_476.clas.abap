" @keywords smartform smartfield editable toggle edit mode
" @summary needs the GWSAMPLE_BASIC OData service
CLASS z2ui5_cl_smps_app_476 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
    " Smart controls build their UI from OData V2 metadata, so this app carries no
    " ABAP data at all - it switches the default model to a service instead. The
    " SAP Gateway demo service GWSAMPLE_BASIC ships with every on-premise system
    " and only has to be activated once in /IWFND/MAINT_SERVICE. Its entity set is
    " ProductSet, which is why the tutorial's Products entity set and two of its
    " field names are mapped onto it ({ProductId} -> {ProductID}, {CategoryName}
    " -> {Category}).
    CONSTANTS c_odata_service TYPE string VALUE `/sap/opu/odata/IWBEP/GWSAMPLE_BASIC/`.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_476 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    IF client->check_on_navigated( ).

      DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
          )->ele( n = `View` ns = `mvc`
              )->a( n = `displayBlock`     v = `true`
              )->a( n = `height`           v = `100%`
              )->a( n = `xmlns`            v = `sap.m`
              )->a( n = `xmlns:mvc`        v = `sap.ui.core.mvc`
              )->a( n = `xmlns:core`       v = `sap.ui.core`
              )->a( n = `xmlns:smartField` v = `sap.ui.comp.smartfield`
              )->a( n = `xmlns:smartForm`  v = `sap.ui.comp.smartform` ).

      DATA(page) = view->ele( `Shell`
          )->ele( `Page`
              )->a( n = `title`          v = `abap2UI5 - Smart Controls - SmartForm`
              )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
              )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

      " editTogglable renders the display/edit toggle in the form header. The
      " element binding replaces the controller's bindElement( ) - an OData ENTITY
      " path into the service, so there is no client->_bind( ) variable behind it;
      " every SmartField value and the form title {Name} are relative to it.
      DATA(form) = page->ele( n = `SmartForm` ns = `smartForm`
          )->a( n = `id`            v = `smartForm`
          )->a( n = `editTogglable` v = `true`
          )->a( n = `title`         v = `{Name}`
          )->a( n = `flexEnabled`   v = `false`
          )->a( n = `binding`       v = `{/ProductSet('AR-FB-1000')}` ).

      DATA(group) = form->ele( n = `Group` ns = `smartForm`
          )->a( n = `label` v = `Product` ).

      group->ele( n = `GroupElement` ns = `smartForm`
          )->ele( n = `SmartField` ns = `smartField`
              )->a( n = `value` v = `{ProductID}` ).

      group->ele( n = `GroupElement` ns = `smartForm`
          )->ele( n = `SmartField` ns = `smartField`
              )->a( n = `value` v = `{Name}` ).

      " elementForLabel picks the second field of the group element as the one the
      " group label belongs to (0-based, so Description)
      group->ele( n = `GroupElement` ns = `smartForm`
          )->a( n = `elementForLabel` v = `1`
          )->ele( n = `SmartField` ns = `smartField`
              )->a( n = `value` v = `{Category}`
          )->end(
          )->ele( n = `SmartField` ns = `smartField`
              )->a( n = `value` v = `{Description}` ).

      group->ele( n = `GroupElement` ns = `smartForm`
          )->ele( n = `SmartField` ns = `smartField`
              )->a( n = `value` v = `{Price}` ).

      form->ele( n = `Group` ns = `smartForm`
          )->a( n = `label` v = `Supplier`
          )->ele( n = `GroupElement` ns = `smartForm`
              )->ele( n = `SmartField` ns = `smartField`
                  )->a( n = `value` v = `{SupplierName}` ).

      client->view_display( val = view->stringify( ) switch_default_model_path = c_odata_service ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
