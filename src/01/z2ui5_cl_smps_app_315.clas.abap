" @keywords odata model service entityset switch_default_model_path external binding
" @summary one table bound to each, column headers from the metadata
CLASS z2ui5_cl_smps_app_315 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_315 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    IF client->check_on_navigated( ).

      DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
          )->ele( n = `View` ns = `mvc`
              )->a( n = `displayBlock` v = `true`
              )->a( n = `height`       v = `100%`
              )->a( n = `xmlns`        v = `sap.m`
              )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
              )->a( n = `xmlns:core`   v = `sap.ui.core` ).
      DATA(page) = view->ele( `Shell`
          )->ele( `Page`
              )->a( n = `title`          v = `abap2UI5 - Table with odata source`
              )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
              )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

      DATA(tab) = page->ele( `Table`
          )->a( n = `items`   v = `{TRAVEL>/Currency}`
          )->a( n = `growing` b = abap_true ).

      tab->ele( `headerToolbar`
          )->ele( `Toolbar`
              )->tag( `Title`
                  )->a( n = `text` v = `table with OData model TRAVEL` ).

      tab->ele( `columns`
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `{TRAVEL>/#Currency/Currency/@sap:label}`
          )->end(
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `{TRAVEL>/#Currency/Currency_Text/@sap:label}`
          )->end(
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `{TRAVEL>/#Currency/Decimals/@sap:label}`
          )->end(
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `{TRAVEL>/#Currency/CurrencyISOCode/@sap:label}`
          )->end( ).

      tab->ele( `items`
          )->ele( `ColumnListItem`
              )->ele( `cells`
                  )->tag( `Text`
                      )->a( n = `text` v = `{TRAVEL>Currency}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{TRAVEL>Currency_Text}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{TRAVEL>Decimals}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{TRAVEL>CurrencyISOCode}` ).

      tab = page->ele( `Table`
          )->a( n = `items`   v = `{FLIGHT>/Airport}`
          )->a( n = `growing` b = abap_true ).

      tab->ele( `headerToolbar`
          )->ele( `Toolbar`
              )->tag( `Title`
                  )->a( n = `text` v = `table with odata model FLIGHT` ).

      tab->ele( `columns`
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `AirportID`
          )->end(
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `Name`
          )->end(
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `City`
          )->end(
          )->ele( `Column`
              )->tag( `Text`
                  )->a( n = `text` v = `CountryCode`
          )->end( ).

      tab->ele( `items`
          )->ele( `ColumnListItem`
              )->ele( `cells`
                  )->tag( `Text`
                      )->a( n = `text` v = `{FLIGHT>AirportID}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{FLIGHT>Name}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{FLIGHT>City}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{FLIGHT>CountryCode}` ).

      client->view_display( view->stringify( ) ).

      client->follow_up_action(
          val   = z2ui5_if_client=>cs_event-set_odata_model
          t_arg = VALUE #( ( `/sap/opu/odata/DMO/API_TRAVEL_U_V2/` )
                           ( `TRAVEL` ) ) ).

      client->follow_up_action(
          val   = z2ui5_if_client=>cs_event-set_odata_model
          t_arg = VALUE #( ( `/sap/opu/odata/DMO/ui_flight_r_v2/` )
                           ( `FLIGHT` ) ) ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
