" @keywords mass change bulk update preview rap eml travel multiselect
" @summary Several travels changed in one go - the new values are previewed next to the old ones, one MODIFY ENTITIES ... UPDATE saves them, and a refusal is shown on its row
"! <p class="shorttext synchronized">RAP - Mass Change with Preview</p>
"! Select travels, say what should change, look at the result, then save:
"!
"! 1. the change is described once - a new booking fee, a number of days to
"!    move the begin date and the end date by
"! 2. Preview computes the new values for every selected travel and shows
"!    them next to the current ones. Nothing is sent to the business object
"! 3. Apply sends all of them in one statement and saves:
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         UPDATE FIELDS ( bookingfee begindate enddate )
"!         WITH VALUE #( FOR p IN t_preview ( travelid = p-travel_id ... ) )
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"!     COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
"!       FAILED DATA(s_failed_commit)
"!       REPORTED DATA(s_reported_commit).
"!
"! An UPDATE names its instances by key, so every answer of the business
"! object - FAILED and REPORTED, from the UPDATE and from the validations at
"! COMMIT - carries the key of the row it is about. Moving only the begin
"! date past the end date is refused by validateDates, and that refusal is
"! shown on its row. The COMMIT is all or nothing.
CLASS z2ui5_cl_smps_app_029 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        selkz          TYPE abap_bool,
        travel_id      TYPE string,
        customer_id    TYPE string,
        begin_date     TYPE string,
        end_date       TYPE string,
        booking_fee    TYPE string,
        currency       TYPE string,
        new_begin_date TYPE string,
        new_end_date   TYPE string,
        new_fee        TYPE string,
        "! None, Success, Warning or Error - the sap.ui.core.ValueState
        state          TYPE string,
        status         TYPE string,
      END OF ty_s_travel.
    TYPES ty_t_travel TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.
    DATA t_travels TYPE ty_t_travel.

    TYPES:
      BEGIN OF ty_s_change,
        "! empty keeps the fee as it is
        booking_fee TYPE string,
        begin_shift TYPE string,
        end_shift   TYPE string,
      END OF ty_s_change.
    DATA s_change TYPE ty_s_change.

    "! true once Preview computed the new values - Apply saves exactly those
    DATA check_preview TYPE abap_bool.

  PROTECTED SECTION.

    TYPES:
      BEGIN OF ty_s_update,
        travel_id   TYPE z2ui5_t_smps_trv-travel_id,
        begin_date  TYPE d,
        end_date    TYPE d,
        booking_fee TYPE z2ui5_t_smps_trv-booking_fee,
      END OF ty_s_update.
    TYPES ty_t_update TYPE STANDARD TABLE OF ty_s_update WITH EMPTY KEY.

    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_event.
    METHODS data_read.
    METHODS preview_build.
    METHODS changes_apply.
    METHODS view_display.

    "! the new values of the previewed rows, in the types of the business object
    METHODS updates_get
      RETURNING
        VALUE(result) TYPE ty_t_update.

    METHODS row_refuse
      IMPORTING
        travel_id TYPE clike
        text      TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_029 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      s_change = VALUE #( begin_shift = `0` end_shift = `0` ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `PREVIEW`.
        preview_build( ).
      WHEN `APPLY`.
        changes_apply( ).
      WHEN `REFRESH`.
        data_read( ).
      WHEN `GENERATE`.
        client->message_toast_display( z2ui5_cl_smps_data_trv=>data_reset( ) ).
        data_read( ).
    ENDCASE.
    view_display( ).

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trv                        "#EC CI_NOWHERE
      FIELDS TravelId, CustomerId, BeginDate, EndDate, BookingFee, CurrencyCode
      ORDER BY TravelId DESCENDING
      INTO TABLE @DATA(t_result) UP TO 50 ROWS.

    t_travels = VALUE #( FOR r IN t_result
        ( travel_id   = |{ r-travelid ALPHA = OUT }|
          customer_id = |{ r-customerid ALPHA = OUT }|
          begin_date  = |{ r-begindate DATE = ISO }|
          end_date    = |{ r-enddate DATE = ISO }|
          booking_fee = |{ r-bookingfee }|
          currency    = |{ r-currencycode }|
          state       = `None` ) ).
    check_preview = abap_false.

  ENDMETHOD.


  METHOD preview_build.

    " the change is checked once, before it is applied to any row - a fee
    " that is no number is one message, not one per row
    DATA fee TYPE z2ui5_t_smps_trv-booking_fee.
    DATA begin_shift TYPE i.
    DATA end_shift TYPE i.
    TRY.
        IF s_change-booking_fee IS NOT INITIAL.
          fee = s_change-booking_fee.
        ENDIF.
        begin_shift = s_change-begin_shift.
        end_shift = s_change-end_shift.
      CATCH cx_sy_conversion_error.
        client->message_box_display( text = `The fee must be a number like 20.00, the shifts whole days like 7 or -3`
                                     type = `error` ).
        RETURN.
    ENDTRY.

    IF NOT line_exists( t_travels[ selkz = abap_true ] ).
      client->message_box_display( `Select the travels to change first` ).
      RETURN.
    ENDIF.

    LOOP AT t_travels REFERENCE INTO DATA(travel).
      CLEAR: travel->new_begin_date, travel->new_end_date, travel->new_fee.
      travel->state = `None`.
      travel->status = ``.
      IF travel->selkz = abap_false.
        CONTINUE.
      ENDIF.

      " the dates are shown as ISO text - back to a date, moved, and shown again
      DATA(begin_date) = CONV d( replace( val = travel->begin_date sub = `-` with = `` occ = 0 ) ).
      DATA(end_date) = CONV d( replace( val = travel->end_date sub = `-` with = `` occ = 0 ) ).
      travel->new_begin_date = |{ CONV d( begin_date + begin_shift ) DATE = ISO }|.
      travel->new_end_date = |{ CONV d( end_date + end_shift ) DATE = ISO }|.
      travel->new_fee = COND #( WHEN s_change-booking_fee IS INITIAL THEN travel->booking_fee ELSE |{ fee }| ).
      travel->status = `Will change`.
    ENDLOOP.

    check_preview = abap_true.

  ENDMETHOD.


  METHOD updates_get.

    LOOP AT t_travels INTO DATA(travel) WHERE new_begin_date IS NOT INITIAL.
      APPEND VALUE #( travel_id   = travel-travel_id
                      begin_date  = replace( val = travel-new_begin_date sub = `-` with = `` occ = 0 )
                      end_date    = replace( val = travel-new_end_date sub = `-` with = `` occ = 0 )
                      booking_fee = travel-new_fee ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD changes_apply.

    IF check_preview = abap_false.
      client->message_box_display( `Press Preview first - Apply saves what the preview shows` ).
      RETURN.
    ENDIF.

    DATA(t_update) = updates_get( ).

    " one statement for every row - the key names the instance, and every
    " answer of the business object carries that key back
    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        UPDATE FIELDS ( bookingfee begindate enddate )
        WITH VALUE #( FOR u IN t_update
                      ( travelid   = u-travel_id
                        bookingfee = u-booking_fee
                        begindate  = u-begin_date
                        enddate    = u-end_date ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.
      ROLLBACK ENTITIES.
      LOOP AT s_failed-travel INTO DATA(failed).
        row_refuse( travel_id = |{ failed-travelid ALPHA = OUT }|
                    text      = concat_lines_of( sep   = `; `
                                                 table = VALUE string_table( FOR r IN s_reported-travel
                                                                             WHERE ( travelid = failed-travelid AND %msg IS BOUND )
                                                                             ( r-%msg->if_message~get_text( ) ) ) ) ).
      ENDLOOP.
      client->message_box_display( text = `The business object refused some rows - nothing was saved` type = `error` ).
      RETURN.
    ENDIF.

    " the validations run now: validateDates refuses an end date before the
    " begin date, which a shift of only one of them can produce
    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.
      " a failed save keeps the changes in the transactional buffer - discard
      " them, or abap2UI5's own COMMIT WORK at the end of the roundtrip runs
      " into them
      ROLLBACK ENTITIES.
      LOOP AT s_failed_commit-travel INTO DATA(failed_commit).
        row_refuse( travel_id = |{ failed_commit-travelid ALPHA = OUT }|
                    text      = concat_lines_of( sep   = `; `
                                                 table = VALUE string_table( FOR r IN s_reported_commit-travel
                                                                             WHERE ( travelid = failed_commit-travelid AND %msg IS BOUND )
                                                                             ( r-%msg->if_message~get_text( ) ) ) ) ).
      ENDLOOP.
      client->message_box_display( text = `The business object refused some rows - nothing was saved` type = `error` ).
      RETURN.
    ENDIF.

    client->message_toast_display( |{ lines( t_update ) } travels changed| ).
    data_read( ).

  ENDMETHOD.


  METHOD row_refuse.

    LOOP AT t_travels REFERENCE INTO DATA(travel) WHERE new_begin_date IS NOT INITIAL.
      IF travel->travel_id = travel_id.
        travel->state = `Error`.
        " a business object may refuse without a message - saying so beats
        " an empty cell
        travel->status = COND #( WHEN text IS INITIAL THEN `Refused by the business object` ELSE text ).
      ELSEIF travel->state <> `Error`.
        travel->state = `Warning`.
        travel->status = `Not saved - another row was refused`.
      ENDIF.
    ENDLOOP.

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
            )->a( n = `title`          v = `abap2UI5 - EML - 29 Mass Change with Preview`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `Change the selected travels`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `New booking fee`
            )->tag( `Input`
                )->a( n = `placeholder` v = `empty keeps the fee`
                )->a( n = `value`       v = client->_bind( s_change-booking_fee )
            )->tag( `Label`
                )->a( n = `text` v = `Move begin date by days`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_change-begin_shift )
            )->tag( `Label`
                )->a( n = `text` v = `Move end date by days`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_change-end_shift ) ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_travels )
        )->a( n = `mode`       v = `MultiSelect`
        )->a( n = `noDataText` v = `No travels yet - press Reset Demo Data` ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Travels (Z2UI5_R_SMPS_TRV)`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `PREVIEW` )
                )->a( n = `text`  v = `Preview`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `APPLY` )
                )->a( n = `text`    v = `Apply`
                )->a( n = `type`    v = `Emphasized`
                )->a( n = `enabled` b = check_preview
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `GENERATE` )
                )->a( n = `text`    v = `Reset Demo Data`
                )->a( n = `tooltip` v = `Deletes every travel, then creates the demo travels again`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REFRESH` )
                )->a( n = `icon`    v = `sap-icon://refresh`
                )->a( n = `tooltip` v = `Refresh` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Travel`
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
            )->tag( `Text`
                )->a( n = `text` v = `Booking Fee`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `selected` v = `{SELKZ}`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{NEW_BEGIN_DATE}`
                    )->a( n = `text`  v = `{BEGIN_DATE}`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{NEW_END_DATE}`
                    )->a( n = `text`  v = `{END_DATE}`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{NEW_FEE}`
                    )->a( n = `text`  v = `{BOOKING_FEE} {CURRENCY}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{STATUS}`
                    )->a( n = `state` v = `{STATE}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
