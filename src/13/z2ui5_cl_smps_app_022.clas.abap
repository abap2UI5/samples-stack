" @keywords excel xlsx export download write spreadsheet xco table download_b64_file
" @summary The table on the screen written into an .xlsx file with the XCO XLSX library and handed to the browser as a download - a header row, then one row per line
"! <p class="shorttext synchronized">Excel - Export a Table as XLSX File with XCO</p>
"! The XCO XLSX library writes an internal table into a new worksheet:
"!
"!     DATA(document) = xco_cp_xlsx=>document->empty( )->write_access( ).
"!     document->get_workbook( )->worksheet->at_position( 1
"!         )->select( pattern )->row_stream(
"!         )->operation->write_from( REF #( t_rows ) )->execute( ).
"!     DATA(xlsx) = document->get_file_content( ).
"!
"! The file goes to the browser as a base64 data URL through the
"! download_b64_file frontend action - no download service, no extra request.
"! The calls sit in z2ui5_cl_smps_xlsx, which the other samples of the
"! package share.
CLASS z2ui5_cl_smps_app_022 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_product,
        product  TYPE string,
        quantity TYPE i,
        price    TYPE p LENGTH 9 DECIMALS 2,
        currency TYPE string,
      END OF ty_s_product.
    TYPES ty_t_product TYPE STANDARD TABLE OF ty_s_product WITH EMPTY KEY.
    DATA t_products TYPE ty_t_product.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS file_download.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_022 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      t_products = VALUE #( currency = `EUR`
                            ( product = `Notebook`        quantity = 2 price = '899.00' )
                            ( product = `Docking station` quantity = 2 price = '189.50' )
                            ( product = `Headset`         quantity = 5 price = '79.90' )
                            ( product = `Monitor`         quantity = 3 price = '249.00' ) ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `DOWNLOAD` ).
      file_download( ).
    ENDIF.

  ENDMETHOD.


  METHOD file_download.

    " every cell is a string in the worksheet - the header row first, then
    " one row per product, the numbers written the way a spreadsheet reads
    " them back: a decimal point and no thousands separator
    DATA(t_rows) = VALUE z2ui5_cl_smps_xlsx=>ty_t_row(
        ( a = `Product` b = `Quantity` c = `Price` d = `Currency` e = `Total` ) ).

    LOOP AT t_products INTO DATA(s_product).
      APPEND VALUE #( a = s_product-product
                      b = |{ s_product-quantity }|
                      c = |{ s_product-price }|
                      d = s_product-currency
                      e = |{ s_product-quantity * s_product-price DECIMALS = 2 }| ) TO t_rows.
    ENDLOOP.

    DATA(xlsx) = z2ui5_cl_smps_xlsx=>write( t_rows ).

    client->follow_up_action(
        val   = client->cs_event-download_b64_file
        t_arg = VALUE #( ( |data:{ z2ui5_cl_smps_xlsx=>mime_type };base64,{ cl_web_http_utility=>encode_x_base64( xlsx ) }| )
                         ( `products.xlsx` ) ) ).

    client->message_toast_display( |products.xlsx - { lines( t_products ) } rows, { xstrlen( xlsx ) } bytes| ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Excel - 22 Export a Table as XLSX File`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Change the table, then press Download XLSX - the XCO XLSX library writes it into a new ` &&
                                 `worksheet and the browser saves the file.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( t_products ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Products`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `DOWNLOAD` )
                )->a( n = `text`  v = `Download XLSX`
                )->a( n = `icon`  v = `sap-icon://excel-attachment`
                )->a( n = `type`  v = `Emphasized` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Product`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Quantity`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Price`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Currency` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Input`
                    )->a( n = `value` v = `{PRODUCT}`
                )->tag( `Input`
                    )->a( n = `value` v = `{QUANTITY}`
                )->tag( `Input`
                    )->a( n = `value` v = `{PRICE}`
                )->tag( `Input`
                    )->a( n = `value` v = `{CURRENCY}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
