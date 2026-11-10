" @keywords excel xlsx import upload mass create rap eml business object travel fileuploader
" @summary An .xlsx file of travels checked row by row and created in the RAP business object with one MODIFY ENTITIES - every refusal lands on the row it belongs to
"! <p class="shorttext synchronized">Excel - Import Travels into a RAP Business Object</p>
"! An Excel import in three steps, each one a roundtrip:
"!
"! 1. Upload - the FileUploader brings the file, the XCO XLSX library reads
"!    it (z2ui5_cl_smps_xlsx), and every row is converted and checked in the
"!    app. Nothing touches the business object yet.
"! 2. Preview - the table shows each row with its status, so a wrong date or
"!    an amount that is no number is seen before anything is created.
"! 3. Import - one MODIFY ENTITIES creates all rows at once. The %cid of an
"!    instance is the Excel row number, so every message the business object
"!    sends back - from the CREATE or from the validations at COMMIT - is
"!    shown on the row it belongs to:
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         CREATE FIELDS ( agencyid customerid begindate enddate ... )
"!         WITH VALUE #( FOR r IN rows ( %cid = |ROW_{ r-row }| ... ) )
"!       MAPPED DATA(s_mapped) FAILED DATA(s_failed) REPORTED DATA(s_reported).
"!
"!     COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
"!       FAILED DATA(s_failed_commit) REPORTED DATA(s_reported_commit).
"!
"! A COMMIT is all or nothing: one refused row and no travel is saved. With
"! "Skip refused rows" the app rolls back, drops the refused rows and creates
"! the rest in a second attempt.
"!
"! Needs the travel business object z2ui5_r_smps_trv of package 03, which
"! comes with this package's branch. Download Example File writes a sheet
"! with one row the business object refuses.
CLASS z2ui5_cl_smps_app_028 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_row,
        "! the row number in the sheet - the first data row is 2
        row         TYPE i,
        agency_id   TYPE string,
        customer_id TYPE string,
        begin_date  TYPE string,
        end_date    TYPE string,
        booking_fee TYPE string,
        currency    TYPE string,
        "! None, Success, Warning or Error - the sap.ui.core.ValueState
        state       TYPE string,
        status      TYPE string,
        travel_id   TYPE string,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    "! the picked file - a data URL, data:&lt;mime&gt;;base64,&lt;payload&gt;
    DATA file         TYPE string.
    DATA file_name    TYPE string.
    DATA t_rows       TYPE ty_t_row.
    DATA skip_refused TYPE abap_bool.

  PROTECTED SECTION.

    TYPES:
      BEGIN OF ty_s_travel,
        row         TYPE i,
        agency_id   TYPE z2ui5_t_smps_trv-agency_id,
        customer_id TYPE z2ui5_t_smps_trv-customer_id,
        begin_date  TYPE d,
        end_date    TYPE d,
        booking_fee TYPE z2ui5_t_smps_trv-booking_fee,
        currency    TYPE z2ui5_t_smps_trv-currency_code,
      END OF ty_s_travel.
    TYPES ty_t_travel TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.

    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS file_read.
    METHODS rows_import.
    METHODS example_download.
    METHODS on_event.

    "! one row of the sheet into the types of the business object - the
    "! problems found go into the row's status, which stays Error unless
    "! travel is complete
    METHODS row_convert
      EXPORTING
        travel TYPE ty_s_travel
      CHANGING
        row    TYPE ty_s_row.

    "! a date cell - the serial number Excel stores, or a text 2026-12-31
    METHODS date_convert
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE d.

    "! one attempt: CREATE all travels, COMMIT, and on any refusal ROLLBACK -
    "! the refused rows are marked in t_rows and returned
    METHODS travels_create
      IMPORTING
        t_travel      TYPE ty_t_travel
      RETURNING
        VALUE(result) TYPE ty_t_travel.

    METHODS row_refuse
      IMPORTING
        row  TYPE i
        text TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_028 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

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
            )->a( n = `title`          v = `abap2UI5 - Excel - 28 Import Travels into a RAP Business Object`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Columns A to F: agency, customer, begin date, end date, booking fee, currency - row 1 is the header. ` &&
                                 `Upload checks every row, Import creates the travels in Z2UI5_R_SMPS_TRV. No file at hand? Download Example File first.`
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
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Preview`
            )->tag( `ToolbarSpacer`
            )->tag( `CheckBox`
                )->a( n = `text`     v = `Skip refused rows`
                )->a( n = `selected` v = client->_bind( skip_refused )
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `IMPORT` )
                )->a( n = `text`    v = `Import`
                )->a( n = `type`    v = `Emphasized`
                )->a( n = `enabled` b = xsdbool( t_rows IS NOT INITIAL ) ).

    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `4rem`
            )->tag( `Text`
                )->a( n = `text` v = `Row`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Agency`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Customer`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Begin`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `End`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Fee`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Travel` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{ROW}`
                )->tag( `Text`
                    )->a( n = `text` v = `{AGENCY_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUSTOMER_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{BEGIN_DATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{END_DATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{BOOKING_FEE} {CURRENCY}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{STATUS}`
                    )->a( n = `state` v = `{STATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `UPLOAD`.
        file_read( ).
      WHEN `IMPORT`.
        rows_import( ).
      WHEN `EXAMPLE`.
        example_download( ).
    ENDCASE.

  ENDMETHOD.


  METHOD file_read.

    " data:<mime>;base64,<payload> - only the payload is the file
    DATA(base64) = substring_after( val = file sub = `,` ).
    " the file is in t_rows now - kept in the app it would travel along with
    " every roundtrip from here on
    CLEAR file.
    CLEAR t_rows.

    TRY.
        DATA(t_cells) = z2ui5_cl_smps_xlsx=>read( cl_web_http_utility=>decode_x_base64( base64 ) ).
      CATCH cx_root INTO DATA(error).
        " not an .xlsx at all, or a damaged one - XCO says why
        client->message_box_display( text = |{ file_name }: { error->get_text( ) }| type = `error` ).
        " a rebuild, not only the model push: Import is enabled at render
        " time from t_rows, and the FileUploader starts over with it
        view_display( ).
        RETURN.
    ENDTRY.

    " row 1 is the header; a row without any value is the end of the data
    " for a person, not an error
    LOOP AT t_cells INTO DATA(cells) FROM 2.
      IF cells IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(row) = VALUE ty_s_row( row         = sy-tabix
                                  agency_id   = condense( cells-a )
                                  customer_id = condense( cells-b )
                                  begin_date  = condense( cells-c )
                                  end_date    = condense( cells-d )
                                  booking_fee = condense( cells-e )
                                  currency    = to_upper( condense( cells-f ) ) ).
      row_convert( CHANGING row = row ).
      APPEND row TO t_rows.
    ENDLOOP.

    DATA(errors) = REDUCE i( INIT n = 0 FOR r IN t_rows WHERE ( state = `Error` ) NEXT n = n + 1 ).
    client->message_toast_display( |{ file_name } - { lines( t_rows ) } rows read, { errors } with errors| ).
    " a rebuild, not only the model push: Import is enabled at render time
    " from t_rows, and the FileUploader starts over with it
    view_display( ).

  ENDMETHOD.


  METHOD row_convert.

    " the checks an import can make without the business object: does every
    " cell fit the type of its field. What a travel must satisfy beyond that
    " - a customer, an end date not before the begin date - is the business
    " object's to decide, and it does at the COMMIT
    travel = VALUE #( row = row-row ).
    DATA(problems) = VALUE string_table( ).

    IF matches( val = row-agency_id regex = `^\d{1,6}$` ).
      travel-agency_id = row-agency_id.
    ELSE.
      APPEND |agency '{ row-agency_id }' is not a number of up to 6 digits| TO problems.
    ENDIF.

    " an empty customer is passed on on purpose - the validation
    " validateCustomer of the business object answers it
    IF row-customer_id IS INITIAL OR matches( val = row-customer_id regex = `^\d{1,6}$` ).
      travel-customer_id = row-customer_id.
    ELSE.
      APPEND |customer '{ row-customer_id }' is not a number of up to 6 digits| TO problems.
    ENDIF.

    travel-begin_date = date_convert( row-begin_date ).
    IF travel-begin_date IS INITIAL.
      APPEND |begin date '{ row-begin_date }' is no date| TO problems.
    ENDIF.

    travel-end_date = date_convert( row-end_date ).
    IF travel-end_date IS INITIAL.
      APPEND |end date '{ row-end_date }' is no date| TO problems.
    ENDIF.

    TRY.
        travel-booking_fee = row-booking_fee.
      CATCH cx_sy_conversion_error.
        APPEND |booking fee '{ row-booking_fee }' is not a number - write it like 20.00| TO problems.
    ENDTRY.

    travel-currency = row-currency.

    IF problems IS NOT INITIAL.
      row-state  = `Error`.
      row-status = concat_lines_of( table = problems sep = `; ` ).
      RETURN.
    ENDIF.

    row-state  = `None`.
    row-status = `Ready`.

  ENDMETHOD.


  METHOD date_convert.

    " the string value of a number cell may come with a fraction, 45658.0
    IF matches( val = val regex = `^\d{1,5}(\.0+)?$` ).
      " a date cell: Excel stores the days since 1899-12-30
      result = CONV d( '18991230' ) + CONV i( val ).
    ELSEIF matches( val = val regex = `^\d{4}-\d{2}-\d{2}$` ).
      result = replace( val = val sub = `-` with = `` occ = 0 ).
    ELSE.
      RETURN.
    ENDIF.

    " 2026-02-30 has the right shape and is still no date - a date that is
    " not valid converts to the day number 0
    IF CONV i( result ) = 0.
      CLEAR result.
    ENDIF.

  ENDMETHOD.


  METHOD rows_import.

    DATA t_travel TYPE ty_t_travel.

    LOOP AT t_rows REFERENCE INTO DATA(row) WHERE travel_id IS INITIAL.
      row_convert( IMPORTING travel = DATA(travel) CHANGING row = row->* ).
      IF row->state <> `Error`.
        APPEND travel TO t_travel.
      ENDIF.
    ENDLOOP.

    IF t_travel IS INITIAL.
      client->message_box_display( `Nothing to import - upload a file with at least one row without errors first` ).
      RETURN.
    ENDIF.

    DATA(pending) = REDUCE i( INIT n = 0 FOR r IN t_rows WHERE ( travel_id IS INITIAL ) NEXT n = n + 1 ).
    IF skip_refused = abap_false AND lines( t_travel ) < pending.
      client->message_box_display( text = `Some rows have errors - fix the file, or switch on Skip refused rows` type = `error` ).
      RETURN.
    ENDIF.

    DATA(created_before) = REDUCE i( INIT n = 0 FOR r IN t_rows WHERE ( travel_id IS NOT INITIAL ) NEXT n = n + 1 ).
    DATA(t_refused) = travels_create( t_travel ).

    " a COMMIT is all or nothing, so the rows that were fine are not saved
    " either. Skipping means: the same CREATE once more, without the rows the
    " business object refused
    IF t_refused IS NOT INITIAL AND skip_refused = abap_true.
      DATA(t_retry) = t_travel.
      LOOP AT t_refused INTO DATA(refused).
        DELETE t_retry WHERE row = refused-row.
      ENDLOOP.
      IF t_retry IS NOT INITIAL.
        LOOP AT t_retry INTO DATA(retry).
          READ TABLE t_rows ASSIGNING FIELD-SYMBOL(<row>) WITH KEY row = retry-row.
          IF sy-subrc = 0.
            <row>-state  = `None`.
            <row>-status = `Ready`.
          ENDIF.
        ENDLOOP.
        t_refused = travels_create( t_retry ).
      ENDIF.
    ENDIF.

    DATA(created) = REDUCE i( INIT n = 0 FOR r IN t_rows WHERE ( travel_id IS NOT INITIAL ) NEXT n = n + 1 ) - created_before.
    DATA(refused_rows) = REDUCE i( INIT n = 0 FOR r IN t_rows WHERE ( state = `Error` ) NEXT n = n + 1 ).
    IF refused_rows = 0.
      client->message_toast_display( |{ created } travels created| ).
    ELSE.
      client->message_box_display( text = |{ created } travels created, { refused_rows } rows not imported - see the status column|
                                   type = COND #( WHEN created = 0 THEN `error` ELSE `warning` ) ).
    ENDIF.

  ENDMETHOD.


  METHOD travels_create.

    DATA row   TYPE i.
    DATA texts TYPE string_table.

    " the %cid is the Excel row number: it is the one thing the business
    " object hands back with each instance, before a key exists - so it is
    " what leads every answer back to its row
    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        CREATE FIELDS ( agencyid customerid begindate enddate bookingfee currencycode description )
        WITH VALUE #( FOR t IN t_travel
                      ( %cid         = |ROW_{ t-row }|
                        agencyid     = t-agency_id
                        customerid   = t-customer_id
                        begindate    = t-begin_date
                        enddate      = t-end_date
                        bookingfee   = t-booking_fee
                        currencycode = t-currency
                        description  = |{ file_name }, row { t-row }| ) )
      MAPPED DATA(s_mapped)
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      LOOP AT s_failed-travel INTO DATA(failed).
        row = substring_after( val = failed-%cid sub = `ROW_` ).
        texts = VALUE #( FOR r IN s_reported-travel WHERE ( %cid = failed-%cid AND %msg IS BOUND )
                         ( r-%msg->if_message~get_text( ) ) ).
        row_refuse( row = row text = concat_lines_of( table = texts sep = `; ` ) ).
        APPEND VALUE #( row = row ) TO result.
      ENDLOOP.

    ELSE.

      " the validations run now. Their answers carry the key, not the %cid -
      " MAPPED is what translates one into the other
      COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
        FAILED DATA(s_failed_commit)
        REPORTED DATA(s_reported_commit).

      IF s_failed_commit IS INITIAL.
        LOOP AT s_mapped-travel INTO DATA(created).
          row = substring_after( val = created-%cid sub = `ROW_` ).
          READ TABLE t_rows ASSIGNING FIELD-SYMBOL(<row>) WITH KEY row = row.
          IF sy-subrc = 0.
            <row>-travel_id = |{ created-travelid ALPHA = OUT }|.
            <row>-state     = `Success`.
            <row>-status    = `Created`.
          ENDIF.
        ENDLOOP.
        RETURN.
      ENDIF.

      " a failed save keeps the instances in the transactional buffer -
      " discard them, or the next attempt and abap2UI5's own COMMIT WORK at
      " the end of the roundtrip run into them
      ROLLBACK ENTITIES.
      LOOP AT s_failed_commit-travel INTO DATA(failed_commit).
        DATA(mapped) = VALUE #( s_mapped-travel[ travelid = failed_commit-travelid ] OPTIONAL ).
        row = substring_after( val = mapped-%cid sub = `ROW_` ).
        texts = VALUE #( FOR r IN s_reported_commit-travel WHERE ( travelid = failed_commit-travelid AND %msg IS BOUND )
                         ( r-%msg->if_message~get_text( ) ) ).
        row_refuse( row = row text = concat_lines_of( table = texts sep = `; ` ) ).
        APPEND VALUE #( row = row ) TO result.
      ENDLOOP.

    ENDIF.

    " one refusal and nothing is saved - the rows the business object did
    " not object to are rolled back with the others
    LOOP AT t_travel INTO DATA(travel).
      IF NOT line_exists( result[ row = travel-row ] ).
        READ TABLE t_rows ASSIGNING <row> WITH KEY row = travel-row.
        IF sy-subrc = 0.
          <row>-state  = `Warning`.
          <row>-status = `Not saved - another row was refused`.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD row_refuse.

    READ TABLE t_rows ASSIGNING FIELD-SYMBOL(<row>) WITH KEY row = row.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    <row>-state  = `Error`.
    " a business object may refuse without a message - saying so beats an
    " empty cell
    <row>-status = COND #( WHEN text IS INITIAL THEN `Refused by the business object` ELSE text ).

  ENDMETHOD.


  METHOD example_download.

    DATA(today) = cl_abap_context_info=>get_system_date( ).
    DATA(t_cells) = VALUE z2ui5_cl_smps_xlsx=>ty_t_row(
        ( a = `Agency` b = `Customer` c = `Begin Date` d = `End Date` e = `Booking Fee` f = `Currency` )
        ( a = `70001` b = `1` c = |{ CONV d( today + 30 ) DATE = ISO }| d = |{ CONV d( today + 37 ) DATE = ISO }| e = `20.00` f = `EUR` )
        ( a = `70002` b = `2` c = |{ CONV d( today + 45 ) DATE = ISO }| d = |{ CONV d( today + 49 ) DATE = ISO }| e = `35.50` f = `EUR` )
        " the business object refuses this one at the COMMIT: the end date
        " is before the begin date
        ( a = `70003` b = `3` c = |{ CONV d( today + 60 ) DATE = ISO }| d = |{ CONV d( today + 55 ) DATE = ISO }| e = `15.00` f = `USD` )
        ( a = `70001` b = `4` c = |{ CONV d( today + 90 ) DATE = ISO }| d = |{ CONV d( today + 97 ) DATE = ISO }| e = `40.00` f = `EUR` ) ).

    DATA(xlsx) = z2ui5_cl_smps_xlsx=>write( t_cells ).

    client->follow_up_action(
        val   = client->cs_event-download_b64_file
        t_arg = VALUE #( ( |data:{ z2ui5_cl_smps_xlsx=>mime_type };base64,{ cl_web_http_utility=>encode_x_base64( xlsx ) }| )
                         ( `travels.xlsx` ) ) ).

  ENDMETHOD.

ENDCLASS.
