" @keywords excel xlsx upload import read spreadsheet xco fileuploader table
" @summary An .xlsx file from the FileUploader read with the XCO XLSX library - the first worksheet becomes an ABAP table and is shown as it arrived
"! <p class="shorttext synchronized">Excel - Read an Uploaded XLSX File with XCO</p>
"! The FileUploader custom control delivers the file as a base64 data URL,
"! the app decodes it into an xstring and hands it to the XCO XLSX library:
"!
"!     DATA(worksheet) = xco_cp_xlsx=>document->for_file_content( file
"!         )->read_access( )->get_workbook( )->worksheet->at_position( 1 ).
"!
"!     worksheet->select( pattern )->row_stream(
"!         )->operation->write_to( REF #( t_rows )
"!         )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
"!         )->execute( ).
"!
"! The calls sit in z2ui5_cl_smps_xlsx, which the other samples of the
"! package share. No file at hand? Download Example File writes one with the
"! same library.
CLASS z2ui5_cl_smps_app_021 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    "! the picked file - a data URL, data:&lt;mime&gt;;base64,&lt;payload&gt;
    DATA file      TYPE string.
    DATA file_name TYPE string.

    "! the first worksheet as it arrived - every cell a string
    DATA t_rows TYPE z2ui5_cl_smps_xlsx=>ty_t_row.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_event.
    METHODS file_read.
    METHODS example_download.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_021 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `UPLOAD`.
        file_read( ).
      WHEN `EXAMPLE`.
        example_download( ).
    ENDCASE.

  ENDMETHOD.


  METHOD file_read.

    " data:<mime>;base64,<payload> - only the payload is the file
    DATA(base64) = substring_after( val = file sub = `,` ).

    TRY.
        t_rows = z2ui5_cl_smps_xlsx=>read( cl_web_http_utility=>decode_x_base64( base64 ) ).
        client->message_toast_display( |{ file_name } - { lines( t_rows ) } rows read| ).

      CATCH cx_root INTO DATA(error).
        " not an .xlsx at all, or a damaged one - XCO says why
        CLEAR t_rows.
        client->message_box_display( text = |{ file_name }: { error->get_text( ) }| type = `error` ).
    ENDTRY.

    CLEAR file.
    view_display( ).

  ENDMETHOD.


  METHOD example_download.

    " the same library the other way round - see z2ui5_cl_smps_app_022
    DATA(xlsx) = z2ui5_cl_smps_xlsx=>write( VALUE #(
        ( a = `Product` b = `Quantity` c = `Price` d = `Currency` )
        ( a = `Notebook` b = `2` c = `899.00` d = `EUR` )
        ( a = `Docking station` b = `2` c = `189.50` d = `EUR` )
        ( a = `Headset` b = `5` c = `79.90` d = `EUR` ) ) ).

    client->follow_up_action(
        val   = client->cs_event-download_b64_file
        t_arg = VALUE #( ( |data:{ z2ui5_cl_smps_xlsx=>mime_type };base64,{ cl_web_http_utility=>encode_x_base64( xlsx ) }| )
                         ( `example.xlsx` ) ) ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Excel - 21 Read an Uploaded XLSX File`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Pick an .xlsx file and press Upload - the XCO XLSX library reads its first worksheet, ` &&
                                 `columns A to F, into an ABAP table. No file at hand? Download Example File first.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( `HBox`
        )->a( n = `class`      v = `sapUiSmallMargin`
        )->a( n = `alignItems` v = `Center`
        )->tag( n = `FileUploader` ns = `z2ui5`
            )->a( n = `placeholder`      v = `pick an .xlsx file...`
            )->a( n = `fileType`         v = `xlsx`
            )->a( n = `uploadButtonText` v = `Upload`
            )->a( n = `upload`           v = client->_event( `UPLOAD` )
            )->a( n = `path`             v = client->_bind( file_name )
            )->a( n = `value`            v = client->_bind( file )
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `EXAMPLE` )
            )->a( n = `text`  v = `Download Example File`
            )->a( n = `icon`  v = `sap-icon://download`
            )->a( n = `class` v = `sapUiSmallMarginBegin` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_rows )
        )->a( n = `noDataText` v = `Nothing read yet` ).
    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `A`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `B`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `C`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `D`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `E`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `F` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{A}`
                )->tag( `Text`
                    )->a( n = `text` v = `{B}`
                )->tag( `Text`
                    )->a( n = `text` v = `{C}`
                )->tag( `Text`
                    )->a( n = `text` v = `{D}`
                )->tag( `Text`
                    )->a( n = `text` v = `{E}`
                )->tag( `Text`
                    )->a( n = `text` v = `{F}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
