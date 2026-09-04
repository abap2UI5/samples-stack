" @keywords launchpad fiori flp cross app navigation receiver intent
" @summary reads them back out of its startup parameters
CLASS z2ui5_cl_smps_app_484 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA product  TYPE string.
    DATA quantity TYPE string.

    DATA check_launchpad_active TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_484 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    check_launchpad_active = client->get( )-check_launchpad_active.

    DATA(t_params) = client->get( )-t_comp_params.
    TRY.
        product = t_params[ n = `PRODUCT` ]-v.
        quantity = t_params[ n = `QUANTITY` ]-v.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    IF client->check_on_navigated( ).

      DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
          )->ele( n = `View` ns = `mvc`
              )->a( n = `displayBlock` v = `true`
              )->a( n = `height`       v = `100%`
              )->a( n = `xmlns`        v = `sap.m`
              )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
              )->a( n = `xmlns:core`   v = `sap.ui.core`
              )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
      DATA(page) = view->ele( `Shell`
          )->ele( `Page`
              )->a( n = `title`          v = `abap2UI5 - Launchpad - Cross-App Navigation (Receiver)`
              )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
              )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
              )->a( n = `showHeader`     b = xsdbool( client->get( )-check_launchpad_active = abap_false ) ).

      page->tag( `MessageStrip`
          )->a( n = `text`     v = `RECEIVER side of launchpad cross-app navigation: started via the sender ` &&
                     `tile (z2ui5_cl_smps_app_483), it reads the Product and Quantity values the ` &&
                     `sender handed over from its startup parameters (t_comp_params) and shows ` &&
                     `them below. ` &&
                     `The button navigates back to the sender the same way. Only works inside ` &&
                     `a launchpad with both tiles configured.`
          )->a( n = `type`     v = `Information`
          )->a( n = `showIcon` b = abap_true
          )->a( n = `class`    v = `sapUiSmallMargin` ).

      page->ele( n = `SimpleForm` ns = `form`
          )->a( n = `title`    v = `Cross-App Navigation - Receiver`
          )->a( n = `editable` b = abap_true
          )->ele( n = `content` ns = `form`
              )->tag( `Label`
                  )->a( n = `text` v = `Product (received navigation parameter)`
              )->tag( `Input`
                  )->a( n = `enabled` b = abap_false
                  )->a( n = `value`   v = client->_bind( product )
              )->tag( `Label`
                  )->a( n = `text` v = `Quantity (received navigation parameter)`
              )->tag( `Input`
                  )->a( n = `enabled` b = abap_false
                  )->a( n = `value`   v = client->_bind( quantity )
              )->tag( `Label`
                  )->a( n = `text` v = `Launchpad active`
              )->tag( `Input`
                  )->a( n = `enabled` b = abap_false
                  )->a( n = `value`   b = check_launchpad_active
              )->tag( `Button`
                  )->a( n = `press`   v = client->follow_up_action( client->cs_event-cross_app_nav_to_prev_app )
                  )->a( n = `text`    v = `back to the previous app`
                  )->a( n = `visible` b = check_launchpad_active
              )->tag( `Button`
                  )->a( n = `press`   v = client->follow_up_action(
                      val   = client->cs_event-cross_app_nav_to_ext
                      t_arg = VALUE #( ( `{ semanticObject: "Z2UI5_CL_LP_SAMPLE_03",  action: "display" }` ) ) )
                  )->a( n = `text`    v = `navigate to the sender app`
                  )->a( n = `visible` b = check_launchpad_active ).

      client->view_display( view->stringify( ) ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
