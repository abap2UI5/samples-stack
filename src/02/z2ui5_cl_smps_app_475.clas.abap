" @keywords smartform smartfield group groupelement columnlayout annotations
" @summary needs the GWSAMPLE_BASIC OData service
CLASS z2ui5_cl_smps_app_475 DEFINITION PUBLIC.

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


CLASS z2ui5_cl_smps_app_475 IMPLEMENTATION.

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
              )->a( n = `title`          v = `abap2UI5 - Smart Controls - SmartField`
              )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
              )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

      " The tutorial binds the view to a single product record in its controller
      " (bindElement( `/Products('4711')` )). There is no controller here, so the
      " element binding is declared on the SmartForm - the SmartField's relative
      " {Price} binding resolves against it. This is an OData ENTITY path into the
      " service, not a path into an ABAP-fed model, so there is no
      " client->_bind( ) variable to derive it from.
      DATA(form) = page->ele( n = `SmartForm` ns = `smartForm`
          )->a( n = `editable` v = `true`
          )->a( n = `binding`  v = `{/ProductSet('AR-FB-1000')}` ).

      form->ele( n = `layout` ns = `smartForm`
          )->ele( n = `ColumnLayout` ns = `smartForm`
              )->a( n = `emptyCellsLarge` v = `4`
              )->a( n = `labelCellsLarge` v = `4`
              )->a( n = `columnsM`        v = `1`
              )->a( n = `columnsL`        v = `1`
              )->a( n = `columnsXL`       v = `1` ).

      form->ele( n = `Group` ns = `smartForm`
          )->ele( n = `GroupElement` ns = `smartForm`
              )->ele( n = `SmartField` ns = `smartField`
                  )->a( n = `value` v = `{Price}`
                  )->a( n = `id`    v = `idPrice` ).

      client->view_display( val = view->stringify( ) switch_default_model_path = c_odata_service ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
