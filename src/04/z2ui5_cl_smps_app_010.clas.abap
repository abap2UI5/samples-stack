" @keywords eml rap draft handling crud popup complete
" @summary a whole app, not a snippet - the complete draft lifecycle in one screen
"! <p class="shorttext synchronized">RAP with Draft - Complete Draft Handling</p>
"! A WHOLE APP, not a single snippet. The complete draft lifecycle in one
"! screen: list, Edit, Resume, change, Activate, Discard - roughly three times
"! the size of samples 06-09.
"!
"! It repeats what those four show, nothing more. Read them first, then come
"! here to see how the pieces sit together in one app.
CLASS z2ui5_cl_smps_app_010 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        travel_uuid    TYPE string,
        travel_id      TYPE string,
        customer_id    TYPE string,
        begin_date     TYPE string,
        end_date       TYPE string,
        total_price    TYPE string,
        overall_status TYPE string,
        status_state   TYPE string,
        draft_text     TYPE string,
        has_draft      TYPE abap_bool,
      END OF ty_s_travel.
    DATA t_travels TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_draft,
        travel_uuid TYPE string,
        travel_id   TYPE string,
        agency_id   TYPE string,
        customer_id TYPE string,
        begin_date  TYPE string,
        end_date    TYPE string,
        booking_fee TYPE string,
        currency    TYPE string,
        description TYPE string,
      END OF ty_s_draft.
    DATA s_draft TYPE ty_s_draft.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_init.
    METHODS on_event.
    METHODS on_event_generate.
    METHODS on_event_edit.
    METHODS on_event_save_draft.
    METHODS on_event_activate.
    METHODS on_event_discard.
    METHODS view_display.
    METHODS popup_edit_display.
    METHODS data_read.

    METHODS draft_read
      IMPORTING
        uuid TYPE string.

    METHODS data_save
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_010 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      on_init( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_init.

    data_read( ).
    view_display( ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `REFRESH`.
        data_read( ).
      WHEN `GENERATE`.
        on_event_generate( ).
      WHEN `EDIT`.
        on_event_edit( ).
      WHEN `SAVE_DRAFT`.
        on_event_save_draft( ).
      WHEN `ACTIVATE`.
        on_event_activate( ).
      WHEN `DISCARD`.
        on_event_discard( ).
      WHEN `POPUP_CLOSE`.
        client->popup_destroy( ).
    ENDCASE.

  ENDMETHOD.


  METHOD on_event_generate.

    client->message_toast_display( z2ui5_cl_smps_data_trd=>data_reset( ) ).
    data_read( ).

  ENDMETHOD.


  METHOD on_event_edit.

    DATA s_failed   TYPE RESPONSE FOR FAILED EARLY z2ui5_r_smps_trd.
    DATA s_reported TYPE RESPONSE FOR REPORTED EARLY z2ui5_r_smps_trd.

    DATA(uuid) = client->get_event_arg( 1 ).

    IF t_travels[ travel_uuid = uuid ]-has_draft = abap_false.

      " no draft yet: the draft action Edit copies the active instance
      " into a new draft instance
      MODIFY ENTITIES OF z2ui5_r_smps_trd
        ENTITY travel
          EXECUTE Edit FROM VALUE #( ( %key-traveluuid = uuid ) )
        FAILED s_failed
        REPORTED s_reported.

    ELSE.

      " a draft already exists: the draft action Resume reactivates it,
      " so the user continues exactly where the last session ended
      MODIFY ENTITIES OF z2ui5_r_smps_trd
        ENTITY travel
          EXECUTE Resume FROM VALUE #( ( %key-traveluuid = uuid ) )
        FAILED s_failed
        REPORTED s_reported.

    ENDIF.

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      draft_read( uuid ).
      data_read( ).
      popup_edit_display( ).

    ENDIF.

  ENDMETHOD.


  METHOD on_event_save_draft.

    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        UPDATE FIELDS ( agencyid customerid begindate enddate bookingfee currencycode description )
        WITH VALUE #( ( %tky         = VALUE #( traveluuid = s_draft-travel_uuid
                                                %is_draft  = if_abap_behv=>mk-on )
                        agencyid     = s_draft-agency_id
                        customerid   = s_draft-customer_id
                        begindate    = s_draft-begin_date
                        enddate      = s_draft-end_date
                        bookingfee   = s_draft-booking_fee
                        currencycode = s_draft-currency
                        description  = s_draft-description ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      data_read( ).
      client->message_toast_display( `Draft saved - the changes are kept even after logoff` ).

    ENDIF.

  ENDMETHOD.


  METHOD on_event_activate.

    " the validations of the business object run during activation -
    " an invalid draft stays a draft and the messages are displayed
    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        EXECUTE Activate FROM VALUE #( ( %key-traveluuid = s_draft-travel_uuid ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      client->popup_destroy( ).
      data_read( ).
      client->message_toast_display( |Travel { s_draft-travel_id } activated| ).

    ENDIF.

  ENDMETHOD.


  METHOD on_event_discard.

    MODIFY ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        EXECUTE Discard FROM VALUE #( ( %key-traveluuid = s_draft-travel_uuid ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      client->popup_destroy( ).
      data_read( ).
      client->message_toast_display( |Draft of travel { s_draft-travel_id } discarded| ).

    ENDIF.

  ENDMETHOD.


  METHOD draft_read.

    READ ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        ALL FIELDS WITH VALUE #( ( %tky = VALUE #( traveluuid = uuid
                                                   %is_draft  = if_abap_behv=>mk-on ) ) )
      RESULT DATA(t_result).

    DATA(s_result) = t_result[ 1 ].
    s_draft = VALUE #(
      travel_uuid = uuid
      travel_id   = |{ s_result-travelid ALPHA = OUT }|
      agency_id   = |{ s_result-agencyid ALPHA = OUT }|
      customer_id = |{ s_result-customerid ALPHA = OUT }|
      begin_date  = |{ s_result-begindate }|
      end_date    = |{ s_result-enddate }|
      booking_fee = |{ s_result-bookingfee }|
      currency    = |{ s_result-currencycode }|
      description = |{ s_result-description }| ).

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trd
      FIELDS traveluuid,
             travelid,
             customerid,
             begindate,
             enddate,
             totalprice,
             currencycode,
             overallstatus,
             description
      ORDER BY travelid DESCENDING
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

    " a draft instance shares the key of its active instance - reading
    " the keys with %is_draft = on reveals which travels have a draft
    READ ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        FIELDS ( travelid ) WITH VALUE #( FOR s_row IN t_result
                                          ( %tky = VALUE #( traveluuid = s_row-traveluuid
                                                            %is_draft  = if_abap_behv=>mk-on ) ) )
      RESULT DATA(t_drafts).

    t_travels = VALUE #( FOR s_result IN t_result
        ( travel_uuid    = |{ s_result-traveluuid }|
          travel_id      = |{ s_result-travelid ALPHA = OUT }|
          customer_id    = |{ s_result-customerid ALPHA = OUT }|
          begin_date     = |{ s_result-begindate DATE = ISO }|
          end_date       = |{ s_result-enddate DATE = ISO }|
          total_price    = |{ s_result-totalprice } { s_result-currencycode }|
          overall_status = z2ui5_cl_smps_context=>status_get_text( s_result-overallstatus )
          status_state   = z2ui5_cl_smps_context=>status_get_state( s_result-overallstatus )
          has_draft      = xsdbool( line_exists( t_drafts[ KEY entity traveluuid = s_result-traveluuid ] ) )
          draft_text     = COND #( WHEN line_exists( t_drafts[ KEY entity traveluuid = s_result-traveluuid ] )
                                   THEN `Draft` ) ) ).

  ENDMETHOD.


  METHOD data_save.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed IS INITIAL.
      result = abap_true.

    ELSE.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
    ENDIF.

  ENDMETHOD.


  METHOD view_display.

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
            )->a( n = `title`          v = `abap2UI5 - EML - 10 Travels with Draft Handling`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( t_travels ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Travels (Z2UI5_R_SMPS_TRD)`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `GENERATE` )
                )->a( n = `text`  v = `Generate Demo Data`
                )->a( n = `icon`  v = `sap-icon://add`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REFRESH` )
                )->a( n = `icon`    v = `sap-icon://refresh`
                )->a( n = `tooltip` v = `Refresh` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `ID`
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
            )->tag( `Text`
                )->a( n = `text` v = `Total Price`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Draft`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Actions` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUSTOMER_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{BEGIN_DATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{END_DATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{TOTAL_PRICE}`
                )->ele( `ObjectStatus`
                    )->a( n = `state` v = `{STATUS_STATE}`
                    )->a( n = `text`  v = `{OVERALL_STATUS}`
                )->end(
                )->ele( `ObjectStatus`
                    )->a( n = `state` v = `Warning`
                    )->a( n = `text`  v = `{DRAFT_TEXT}`
                )->end(
                )->tag( `Button`
                    )->a( n = `press`   v = client->_event( val = `EDIT` t_arg = VALUE #( ( `${TRAVEL_UUID}` ) ) )
                    )->a( n = `icon`    v = `sap-icon://edit`
                    )->a( n = `tooltip` v = `Edit Travel` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD popup_edit_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->a( n = `xmlns:form` v = `sap.ui.layout.form` ).
    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        v = |Edit Travel { s_draft-travel_id } (Draft)|
        )->a( n = `contentWidth` v = `30rem` ).

    dialog->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Agency ID`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_draft-agency_id )
            )->tag( `Label`
                )->a( n = `text` v = `Customer ID`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_draft-customer_id )
            )->tag( `Label`
                )->a( n = `text` v = `Begin Date`
            )->tag( `DatePicker`
                )->a( n = `value`       v = client->_bind( s_draft-begin_date )
                )->a( n = `valueFormat` v = `yyyyMMdd`
            )->tag( `Label`
                )->a( n = `text` v = `End Date`
            )->tag( `DatePicker`
                )->a( n = `value`       v = client->_bind( s_draft-end_date )
                )->a( n = `valueFormat` v = `yyyyMMdd`
            )->tag( `Label`
                )->a( n = `text` v = `Booking Fee`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_draft-booking_fee )
            )->tag( `Label`
                )->a( n = `text` v = `Currency`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_draft-currency )
            )->tag( `Label`
                )->a( n = `text` v = `Description`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_draft-description ) ).

    dialog->ele( `buttons`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `ACTIVATE` )
            )->a( n = `text`  v = `Activate`
            )->a( n = `type`  v = `Emphasized`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `SAVE_DRAFT` )
            )->a( n = `text`  v = `Save Draft`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `DISCARD` )
            )->a( n = `text`  v = `Discard Draft`
            )->a( n = `type`  v = `Reject`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `POPUP_CLOSE` )
            )->a( n = `text`  v = `Close` ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
