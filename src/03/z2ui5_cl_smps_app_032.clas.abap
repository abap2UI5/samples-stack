" @keywords edit lock conflict concurrency etag optimistic locking lastchangedat rap eml travel
" @summary Edit a travel without a stateful session - the app remembers LastChangedAt when it reads, and Save refuses the change if someone else saved the travel in between
"! <p class="shorttext synchronized">RAP - Edit with Conflict Check</p>
"! Optimistic locking in a stateless app. Nothing is locked while the user
"! types - an abap2UI5 app holds no session between two roundtrips, so a
"! lock set on Edit would be gone before Save. Instead the app remembers the
"! ETag of the business object, the field LastChangedAt, when it reads the
"! travel, and Save checks it:
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         UPDATE FIELDS ( description bookingfee ) WITH VALUE #( ( ... ) )
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"!     SELECT SINGLE FROM z2ui5_r_smps_trv FIELDS LastChangedAt
"!       WHERE TravelId = @travel_id INTO @DATA(current).
"!
"!     IF current <> s_edit-last_changed_at.  " someone saved in between
"!       ROLLBACK ENTITIES.
"!
"! The order matters. The UPDATE comes first because it takes the lock of
"! the business object (lock master), and the check after it reads the
"! database, where the change of this roundtrip is not written yet - so
"! between the check and the COMMIT nobody else can save the travel.
"! "Change by Someone Else" saves the travel in a roundtrip of its own, which
"! is what a second user would do.
CLASS z2ui5_cl_smps_app_032 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        travel_id   TYPE string,
        customer_id TYPE string,
        booking_fee TYPE string,
        currency    TYPE string,
        description TYPE string,
        changed_at  TYPE string,
      END OF ty_s_travel.
    TYPES ty_t_travel TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.
    DATA t_travels TYPE ty_t_travel.

    TYPES:
      BEGIN OF ty_s_edit,
        travel_id       TYPE string,
        booking_fee     TYPE string,
        currency        TYPE string,
        description     TYPE string,
        "! the ETag as it was when the travel was read - what Save compares
        last_changed_at TYPE timestampl,
      END OF ty_s_edit.
    DATA s_edit TYPE ty_s_edit.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS data_read.
    METHODS travel_edit.
    METHODS travel_save.
    METHODS travel_change_elsewhere.
    METHODS on_event.
    METHODS popup_edit_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_032 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
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
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - EML - 32 Edit with Conflict Check`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Edit a travel, press Change by Someone Else in the popup, then Save - the conflict is detected ` &&
                                 `from LastChangedAt, without any lock held while you type.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_travels )
        )->a( n = `noDataText` v = `No travels yet - press Reset Demo Data` ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Travels (Z2UI5_R_SMPS_TRV)`
            )->tag( `ToolbarSpacer`
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
                )->a( n = `text` v = `Booking Fee`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Last Changed`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{BOOKING_FEE} {CURRENCY}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DESCRIPTION}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CHANGED_AT}`
                )->tag( `Button`
                    )->a( n = `press` v = client->_event( val = `EDIT` arg = `${TRAVEL_ID}` )
                    )->a( n = `icon`  v = `sap-icon://edit`
                    )->a( n = `text`  v = `Edit` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `EDIT`.
        travel_edit( ).
      WHEN `SAVE`.
        travel_save( ).
      WHEN `ELSEWHERE`.
        travel_change_elsewhere( ).
      WHEN `REFRESH`.
        data_read( ).
        view_display( ).
      WHEN `GENERATE`.
        client->message_toast_display( z2ui5_cl_smps_data_trv=>data_reset( ) ).
        data_read( ).
        view_display( ).
    ENDCASE.

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trv                        "#EC CI_NOWHERE
      FIELDS TravelId, CustomerId, BookingFee, CurrencyCode, Description, LastChangedAt
      ORDER BY TravelId DESCENDING
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

    t_travels = VALUE #( FOR r IN t_result
        ( travel_id   = |{ r-travelid ALPHA = OUT }|
          customer_id = |{ r-customerid ALPHA = OUT }|
          booking_fee = |{ r-bookingfee }|
          currency    = |{ r-currencycode }|
          description = |{ r-description }|
          changed_at  = |{ r-lastchangedat TIMESTAMP = ISO }| ) ).

  ENDMETHOD.


  METHOD travel_edit.

    DATA travel_id TYPE z2ui5_t_smps_trv-travel_id.
    travel_id = client->get_event_arg( ).

    " read fresh from the business object, not from the list - the ETag
    " remembered here is the one the user's change is based on
    READ ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        FIELDS ( bookingfee currencycode description lastchangedat )
        WITH VALUE #( ( travelid = travel_id ) )
      RESULT DATA(t_result)
      FAILED DATA(s_failed).

    IF s_failed-travel IS NOT INITIAL OR t_result IS INITIAL.
      client->message_box_display( text = `The travel does not exist any more - press Refresh` type = `error` ).
      RETURN.
    ENDIF.

    DATA(s_result) = t_result[ 1 ].
    s_edit = VALUE #( travel_id       = |{ travel_id ALPHA = OUT }|
                      booking_fee     = |{ s_result-bookingfee }|
                      currency        = |{ s_result-currencycode }|
                      description     = |{ s_result-description }|
                      last_changed_at = s_result-lastchangedat ).
    popup_edit_display( ).

  ENDMETHOD.


  METHOD travel_save.

    DATA travel_id TYPE z2ui5_t_smps_trv-travel_id.
    DATA booking_fee TYPE z2ui5_t_smps_trv-booking_fee.
    travel_id = s_edit-travel_id.
    TRY.
        booking_fee = s_edit-booking_fee.
      CATCH cx_sy_conversion_error.
        client->message_box_display( text = |Booking fee '{ s_edit-booking_fee }' is not a number - write it like 20.00|
                                     type = `error` ).
        RETURN.
    ENDTRY.

    " first the UPDATE: it takes the lock of the business object, so from
    " here to the COMMIT nobody else can save this travel
    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        UPDATE FIELDS ( bookingfee currencycode description )
        WITH VALUE #( ( travelid     = travel_id
                        bookingfee   = booking_fee
                        currencycode = s_edit-currency
                        description  = s_edit-description ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.
      " locked by someone who is saving right now, or gone
      ROLLBACK ENTITIES.
      client->message_box_display( text = s_reported-travel type = `error` ).
      RETURN.
    ENDIF.

    " then the check, against the database: the UPDATE above is still in the
    " transactional buffer, so what is read here is the last saved state
    SELECT SINGLE FROM z2ui5_r_smps_trv
      FIELDS LastChangedAt
      WHERE TravelId = @travel_id
      INTO @DATA(current).

    IF sy-subrc <> 0 OR current <> s_edit-last_changed_at.
      " releases the lock and drops the change - the user decides again on
      " the current state rather than overwriting what someone else saved
      ROLLBACK ENTITIES.
      client->popup_destroy( ).
      data_read( ).
      view_display( ).
      client->message_box_display( text = |Travel { s_edit-travel_id } was changed by someone else after you opened it. | &&
                                          `Your change was not saved - open the travel again to see the current values.`
                                   type = `warning` ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.
      ROLLBACK ENTITIES.
      client->message_box_display( text = s_reported_commit-travel type = `error` ).
      RETURN.
    ENDIF.

    client->popup_destroy( ).
    data_read( ).
    view_display( ).
    client->message_toast_display( |Travel { s_edit-travel_id } saved| ).

  ENDMETHOD.


  METHOD travel_change_elsewhere.

    " what a second user does while the popup is open: change the same
    " travel and save it. Its own roundtrip, its own COMMIT - and with it a
    " new LastChangedAt, set by the managed runtime
    DATA travel_id TYPE z2ui5_t_smps_trv-travel_id.
    travel_id = s_edit-travel_id.

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        UPDATE FIELDS ( description )
        WITH VALUE #( ( travelid    = travel_id
                        description = |Changed elsewhere at { cl_abap_context_info=>get_system_time( ) TIME = ISO }| ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.
      ROLLBACK ENTITIES.
      client->message_box_display( text = s_reported-travel type = `error` ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.
      ROLLBACK ENTITIES.
      client->message_box_display( text = s_reported_commit-travel type = `error` ).
      RETURN.
    ENDIF.

    client->message_toast_display( `Saved by someone else - now press Save` ).

  ENDMETHOD.


  METHOD popup_edit_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->a( n = `xmlns:form` v = `sap.ui.layout.form` ).
    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        t = |Edit Travel { s_edit-travel_id }|
        )->a( n = `contentWidth` v = `30rem` ).

    dialog->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Booking Fee`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_edit-booking_fee )
            )->tag( `Label`
                )->a( n = `text` v = `Currency`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_edit-currency )
            )->tag( `Label`
                )->a( n = `text` v = `Description`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_edit-description ) ).

    dialog->ele( `buttons`
        )->tag( `Button`
            )->a( n = `press`   v = client->_event( `ELSEWHERE` )
            )->a( n = `text`    v = `Change by Someone Else`
            )->a( n = `tooltip` v = `Saves the travel in a roundtrip of its own, as a second user would`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `SAVE` )
            )->a( n = `text`  v = `Save`
            )->a( n = `type`  v = `Emphasized`
        )->tag( `Button`
            )->a( n = `press` v = client->follow_up_action( val = client->cs_event-popup_close )
            )->a( n = `text`  v = `Cancel` ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
