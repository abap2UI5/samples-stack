" @keywords report selection screen filter range export excel xlsx download travel sql
" @summary A report as it is written every day - a selection with ranges, the result in a table with a total, and the same rows exported as .xlsx with XCO
"! <p class="shorttext synchronized">Excel - Report with Selection and Export</p>
"! The classic report in three parts, each one a few lines:
"!
"! 1. the selection - agency, customer and a date window, each field turned
"!    into a range table, so an empty field means "all" exactly as on a
"!    selection screen
"! 2. the result - one SELECT on the CDS view entity with the ranges in its
"!    WHERE, shown in a table with the number of rows and a total
"! 3. the export - the rows on the screen written into an .xlsx with the XCO
"!    XLSX library and handed to the browser as a download
"!
"!     SELECT FROM z2ui5_r_smps_trv FIELDS ...
"!       WHERE AgencyId   IN @t_agency
"!         AND CustomerId IN @t_customer
"!         AND BeginDate  IN @t_begin
"!       INTO TABLE @DATA(t_result).
"!
"! The export writes what the report shows, not a second SELECT, so the file
"! and the screen cannot disagree. Reads the travels of package 03.
CLASS z2ui5_cl_smps_app_031 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_selection,
        agency_id   TYPE string,
        customer_id TYPE string,
        "! yyyyMMdd, the value format of the DatePicker
        begin_from  TYPE string,
        begin_to    TYPE string,
        max_rows    TYPE i,
      END OF ty_s_selection.
    DATA s_selection TYPE ty_s_selection.

    TYPES:
      BEGIN OF ty_s_travel,
        travel_id   TYPE string,
        agency_id   TYPE string,
        customer_id TYPE string,
        begin_date  TYPE string,
        end_date    TYPE string,
        total_price TYPE string,
        currency    TYPE string,
        status      TYPE string,
      END OF ty_s_travel.
    TYPES ty_t_travel TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.
    DATA t_travels TYPE ty_t_travel.

    "! the line under the table - number of rows and the total per currency
    DATA summary TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS data_search.
    METHODS data_export.
    METHODS on_event.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_031 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      s_selection-max_rows = 200.
      data_search( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
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
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Excel - 31 Report with Selection and Export`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Selection`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Agency`
            )->tag( `Input`
                )->a( n = `placeholder` v = `all`
                )->a( n = `value`       v = client->_bind( s_selection-agency_id )
                )->a( n = `submit`      v = client->_event( `SEARCH` )
            )->tag( `Label`
                )->a( n = `text` v = `Customer`
            )->tag( `Input`
                )->a( n = `placeholder` v = `all`
                )->a( n = `value`       v = client->_bind( s_selection-customer_id )
                )->a( n = `submit`      v = client->_event( `SEARCH` )
            )->tag( `Label`
                )->a( n = `text` v = `Begin date from / to`
            )->tag( `DatePicker`
                )->a( n = `value`       v = client->_bind( s_selection-begin_from )
                )->a( n = `valueFormat` v = `yyyyMMdd`
            )->tag( `DatePicker`
                )->a( n = `value`       v = client->_bind( s_selection-begin_to )
                )->a( n = `valueFormat` v = `yyyyMMdd`
            )->tag( `Label`
                )->a( n = `text` v = `Maximum rows`
            )->tag( `StepInput`
                )->a( n = `value` v = client->_bind( s_selection-max_rows )
                )->a( n = `min`   v = `1`
                )->a( n = `max`   v = `5000`
                )->a( n = `step`  v = `100`
            )->tag( `Label`
            )->ele( `HBox`
                )->tag( `Button`
                    )->a( n = `press` v = client->_event( `SEARCH` )
                    )->a( n = `text`  v = `Search`
                    )->a( n = `type`  v = `Emphasized`
                    )->a( n = `icon`  v = `sap-icon://search`
                )->tag( `Button`
                    )->a( n = `press` v = client->_event( `RESET` )
                    )->a( n = `text`  v = `Reset`
                    )->a( n = `class` v = `sapUiTinyMarginBegin` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_travels )
        )->a( n = `noDataText` v = `No travel matches the selection` ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = client->_bind( summary )
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `EXPORT` )
                )->a( n = `text`  v = `Export to Excel`
                )->a( n = `icon`  v = `sap-icon://excel-attachment` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Travel`
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
                )->a( n = `text` v = `Begin Date`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `End Date`
        )->end(
        )->ele( `Column`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Total Price`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{AGENCY_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUSTOMER_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{BEGIN_DATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{END_DATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{TOTAL_PRICE} {CURRENCY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{STATUS}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `SEARCH`.
        data_search( ).
        view_display( ).
      WHEN `RESET`.
        s_selection = VALUE #( max_rows = 200 ).
        data_search( ).
        view_display( ).
      WHEN `EXPORT`.
        data_export( ).
    ENDCASE.

  ENDMETHOD.


  METHOD data_search.

    TYPES ty_r_agency TYPE RANGE OF z2ui5_t_smps_trv-agency_id.
    TYPES ty_r_customer TYPE RANGE OF z2ui5_t_smps_trv-customer_id.
    TYPES ty_r_date TYPE RANGE OF z2ui5_t_smps_trv-begin_date.
    TYPES:
      BEGIN OF ty_s_total,
        currency TYPE z2ui5_t_smps_trv-currency_code,
        amount   TYPE z2ui5_t_smps_trv-total_price,
      END OF ty_s_total.
    DATA t_total TYPE SORTED TABLE OF ty_s_total WITH UNIQUE KEY currency.

    IF NOT matches( val = s_selection-agency_id && s_selection-customer_id regex = `^\d*$` ).
      client->message_box_display( text = `Agency and customer are numbers - leave a field empty to select all` type = `error` ).
      RETURN.
    ENDIF.

    " an empty range selects everything - the selection-screen behavior,
    " without a branch per field
    DATA(t_agency) = VALUE ty_r_agency( ).
    IF s_selection-agency_id IS NOT INITIAL.
      t_agency = VALUE #( ( sign = `I` option = `EQ` low = s_selection-agency_id ) ).
    ENDIF.

    DATA(t_customer) = VALUE ty_r_customer( ).
    IF s_selection-customer_id IS NOT INITIAL.
      t_customer = VALUE #( ( sign = `I` option = `EQ` low = s_selection-customer_id ) ).
    ENDIF.

    " a window open on one side is a GE or an LE, open on both no range at all
    DATA(t_begin) = VALUE ty_r_date( ).
    IF s_selection-begin_from IS NOT INITIAL AND s_selection-begin_to IS NOT INITIAL.
      t_begin = VALUE #( ( sign = `I` option = `BT` low = s_selection-begin_from high = s_selection-begin_to ) ).
    ELSEIF s_selection-begin_from IS NOT INITIAL.
      t_begin = VALUE #( ( sign = `I` option = `GE` low = s_selection-begin_from ) ).
    ELSEIF s_selection-begin_to IS NOT INITIAL.
      t_begin = VALUE #( ( sign = `I` option = `LE` low = s_selection-begin_to ) ).
    ENDIF.

    DATA(max_rows) = COND i( WHEN s_selection-max_rows > 0 THEN s_selection-max_rows ELSE 200 ).

    SELECT FROM z2ui5_r_smps_trv
      FIELDS TravelId, AgencyId, CustomerId, BeginDate, EndDate, TotalPrice, CurrencyCode, OverallStatus
      WHERE AgencyId   IN @t_agency
        AND CustomerId IN @t_customer
        AND BeginDate  IN @t_begin
      ORDER BY BeginDate, TravelId
      INTO TABLE @DATA(t_result) UP TO @max_rows ROWS.

    t_travels = VALUE #( FOR r IN t_result
        ( travel_id   = |{ r-travelid ALPHA = OUT }|
          agency_id   = |{ r-agencyid ALPHA = OUT }|
          customer_id = |{ r-customerid ALPHA = OUT }|
          begin_date  = |{ r-begindate DATE = ISO }|
          end_date    = |{ r-enddate DATE = ISO }|
          total_price = |{ r-totalprice }|
          currency    = |{ r-currencycode }|
          status      = z2ui5_cl_smps_context=>status_get_text( r-overallstatus ) ) ).

    " a total only makes sense per currency - summed in the types of the
    " business object, not from the strings on the screen
    LOOP AT t_result INTO DATA(result).
      DATA(total) = VALUE ty_s_total( currency = result-currencycode amount = result-totalprice ).
      COLLECT total INTO t_total.
    ENDLOOP.

    summary = |{ lines( t_travels ) } travels| &&
              COND #( WHEN lines( t_travels ) = max_rows THEN | (the first { max_rows } - narrow the selection)| ELSE `` ) &&
              REDUCE string( INIT s = `` FOR t IN t_total NEXT s = |{ s }, { t-amount } { t-currency }| ).

  ENDMETHOD.


  METHOD data_export.

    IF t_travels IS INITIAL.
      client->message_toast_display( `Nothing to export - the selection found no travel` ).
      RETURN.
    ENDIF.

    " the rows on the screen, not a second SELECT - the file shows exactly
    " what the user looked at. Six columns, A to F, as z2ui5_cl_smps_xlsx
    " writes them
    DATA(t_cells) = VALUE z2ui5_cl_smps_xlsx=>ty_t_row(
        ( a = `Travel` b = `Customer` c = `Begin Date` d = `End Date` e = `Total Price` f = `Status` ) ).
    LOOP AT t_travels INTO DATA(travel).
      APPEND VALUE #( a = travel-travel_id
                      b = travel-customer_id
                      c = travel-begin_date
                      d = travel-end_date
                      e = |{ travel-total_price } { travel-currency }|
                      f = travel-status ) TO t_cells.
    ENDLOOP.

    DATA(xlsx) = z2ui5_cl_smps_xlsx=>write( t_cells ).
    DATA(file_name) = |travels_{ cl_abap_context_info=>get_system_date( ) }.xlsx|.

    client->follow_up_action(
        val   = client->cs_event-download_b64_file
        t_arg = VALUE #( ( |data:{ z2ui5_cl_smps_xlsx=>mime_type };base64,{ cl_web_http_utility=>encode_x_base64( xlsx ) }| )
                         ( file_name ) ) ).

  ENDMETHOD.

ENDCLASS.
