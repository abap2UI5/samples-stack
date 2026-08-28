" @keywords eml rap crud travel manage popup objectstatus
" @summary 01-04 plus EXECUTE and COMMIT ENTITIES RESPONSE OF
"! <p class="shorttext synchronized">RAP - Manage Travels, the Complete App</p>
"! A WHOLE APP, not a single snippet. Read, create, update, delete and both
"! actions of the business object in one screen, with the message handling and
"! the create popup a real app needs - roughly three times the size of samples
"! 01-04. If EML is new to you, read those first.
"!
"! What it adds beyond them is the action call and the save with a response:
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         EXECUTE acceptTravel FROM VALUE #( ( travelid = travel_id ) )
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"!     COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
"!       FAILED DATA(s_failed_commit)
"!       REPORTED DATA(s_reported_commit).
CLASS z2ui5_cl_smps_app_005 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        travel_id      TYPE string,
        customer_id    TYPE string,
        begin_date     TYPE string,
        end_date       TYPE string,
        total_price    TYPE string,
        overall_status TYPE string,
        status_state   TYPE string,
        description    TYPE string,
      END OF ty_s_travel.
    DATA t_travels TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_create,
        agency_id   TYPE string,
        customer_id TYPE string,
        begin_date  TYPE string,
        end_date    TYPE string,
        booking_fee TYPE string,
        currency    TYPE string,
        description TYPE string,
      END OF ty_s_create.
    DATA s_create TYPE ty_s_create.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_init.
    METHODS on_event.
    METHODS on_event_generate.
    METHODS on_event_create.
    METHODS on_event_save.
    METHODS on_event_accept.
    METHODS on_event_reject.
    METHODS on_event_delete.
    METHODS view_display.
    METHODS popup_create_display.
    METHODS data_read.

    METHODS data_save
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_005 IMPLEMENTATION.

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
      WHEN `CREATE`.
        " the popup opens on a set that passes both validations, so Create
        " goes through on the first press - see z2ui5_cl_smps_app_002, which
        " also explains why the end date needs the CONV d( )
        DATA(end_date) = CONV d( sy-datum + 14 ).

        s_create = VALUE #( agency_id   = `070001`
                            customer_id = `000001`
                            begin_date  = |{ sy-datum }|
                            end_date    = |{ end_date }|
                            booking_fee = `20.00`
                            currency    = `EUR`
                            description = `New travel created from sample 05` ).
        popup_create_display( ).
      WHEN `POPUP_CREATE_CONFIRM`.
        on_event_create( ).
      WHEN `POPUP_CREATE_CANCEL`.
        client->popup_destroy( ).
      WHEN `SAVE`.
        on_event_save( ).
      WHEN `ACCEPT`.
        on_event_accept( ).
      WHEN `REJECT`.
        on_event_reject( ).
      WHEN `DELETE`.
        on_event_delete( ).
    ENDCASE.

  ENDMETHOD.


  METHOD on_event_generate.

    " the demo data lives with the business object it belongs to, so every
    " app and the ADT console application create exactly the same set
    client->message_toast_display( z2ui5_cl_smps_data_trv=>data_reset( ) ).
    data_read( ).

  ENDMETHOD.


  METHOD on_event_create.

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        CREATE FIELDS ( agencyid customerid begindate enddate bookingfee currencycode description )
        WITH VALUE #( ( %cid         = `CREATE_TRAVEL_1`
                        agencyid     = s_create-agency_id
                        customerid   = s_create-customer_id
                        begindate    = s_create-begin_date
                        enddate      = s_create-end_date
                        bookingfee   = s_create-booking_fee
                        currencycode = s_create-currency
                        description  = s_create-description ) )
      MAPPED DATA(s_mapped)
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
      client->message_toast_display( |Travel { s_mapped-travel[ 1 ]-travelid ALPHA = OUT } created| ).

    ENDIF.

  ENDMETHOD.


  METHOD on_event_save.

    DATA(travel_id) = client->get_event_arg( 1 ).
    DATA(s_travel) = t_travels[ travel_id = travel_id ].

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        UPDATE FIELDS ( description )
        WITH VALUE #( ( travelid    = travel_id
                        description = s_travel-description ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      data_read( ).
      client->message_toast_display( |Travel { travel_id } updated| ).

    ENDIF.

  ENDMETHOD.


  METHOD on_event_accept.

    DATA(travel_id) = client->get_event_arg( 1 ).

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        EXECUTE acceptTravel FROM VALUE #( ( travelid = travel_id ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      data_read( ).
      client->message_toast_display( |Travel { travel_id } accepted| ).

    ENDIF.

  ENDMETHOD.


  METHOD on_event_reject.

    DATA(travel_id) = client->get_event_arg( 1 ).

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        EXECUTE rejectTravel FROM VALUE #( ( travelid = travel_id ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      data_read( ).
      client->message_toast_display( |Travel { travel_id } rejected| ).

    ENDIF.

  ENDMETHOD.


  METHOD on_event_delete.

    DATA(travel_id) = client->get_event_arg( 1 ).

    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        DELETE FROM VALUE #( ( travelid = travel_id ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    IF data_save( ) = abap_true.

      data_read( ).
      client->message_toast_display( |Travel { travel_id } deleted| ).

    ENDIF.

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trv
      FIELDS TravelId,
             CustomerId,
             BeginDate,
             EndDate,
             TotalPrice,
             CurrencyCode,
             OverallStatus,
             Description
      ORDER BY TravelId DESCENDING
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

    t_travels = VALUE #( FOR s_result IN t_result
        ( travel_id      = |{ s_result-travelid ALPHA = OUT }|
          customer_id    = |{ s_result-customerid ALPHA = OUT }|
          begin_date     = |{ s_result-begindate DATE = ISO }|
          end_date       = |{ s_result-enddate DATE = ISO }|
          total_price    = |{ s_result-totalprice } { s_result-currencycode }|
          overall_status = z2ui5_cl_smps_context=>status_get_text( s_result-overallstatus )
          status_state   = z2ui5_cl_smps_context=>status_get_state( s_result-overallstatus )
          description    = |{ s_result-description }| ) ).

  ENDMETHOD.


  METHOD data_save.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
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
            )->a( n = `title`          v = `abap2UI5 - EML - 05 Manage Travels`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items` v = client->_bind( t_travels ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Travels (Z2UI5_R_SMPS_TRV)`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `CREATE` )
                )->a( n = `text`  v = `Create`
                )->a( n = `icon`  v = `sap-icon://add`
                )->a( n = `type`  v = `Emphasized`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `GENERATE` )
                )->a( n = `text`  v = `Generate Demo Data`
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
                )->a( n = `text` v = `Description`
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
                )->tag( `Input`
                    )->a( n = `value` v = `{DESCRIPTION}`
                )->ele( `HBox`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `SAVE` t_arg = VALUE #( ( `${TRAVEL_ID}` ) ) )
                        )->a( n = `icon`    v = `sap-icon://save`
                        )->a( n = `tooltip` v = `Save Description`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `ACCEPT` t_arg = VALUE #( ( `${TRAVEL_ID}` ) ) )
                        )->a( n = `icon`    v = `sap-icon://accept`
                        )->a( n = `tooltip` v = `Accept Travel`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `REJECT` t_arg = VALUE #( ( `${TRAVEL_ID}` ) ) )
                        )->a( n = `icon`    v = `sap-icon://decline`
                        )->a( n = `tooltip` v = `Reject Travel`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `DELETE` t_arg = VALUE #( ( `${TRAVEL_ID}` ) ) )
                        )->a( n = `icon`    v = `sap-icon://delete`
                        )->a( n = `tooltip` v = `Delete Travel` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD popup_create_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core`
            )->a( n = `xmlns:form` v = `sap.ui.layout.form` ).
    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`        v = `Create Travel`
        )->a( n = `contentWidth` v = `30rem` ).

    dialog->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Agency ID`
            )->tag( `Input`
                )->a( n = `placeholder` v = `e.g. 70001`
                )->a( n = `value`       v = client->_bind( s_create-agency_id )
            )->tag( `Label`
                )->a( n = `text` v = `Customer ID`
            )->tag( `Input`
                )->a( n = `placeholder` v = `e.g. 1`
                )->a( n = `value`       v = client->_bind( s_create-customer_id )
            )->tag( `Label`
                )->a( n = `text` v = `Begin Date`
            )->tag( `DatePicker`
                )->a( n = `value`       v = client->_bind( s_create-begin_date )
                )->a( n = `valueFormat` v = `yyyyMMdd`
            )->tag( `Label`
                )->a( n = `text` v = `End Date`
            )->tag( `DatePicker`
                )->a( n = `value`       v = client->_bind( s_create-end_date )
                )->a( n = `valueFormat` v = `yyyyMMdd`
            )->tag( `Label`
                )->a( n = `text` v = `Booking Fee`
            )->tag( `Input`
                )->a( n = `placeholder` v = `e.g. 10.50`
                )->a( n = `value`       v = client->_bind( s_create-booking_fee )
            )->tag( `Label`
                )->a( n = `text` v = `Currency`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_create-currency )
            )->tag( `Label`
                )->a( n = `text` v = `Description`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( s_create-description ) ).

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `POPUP_CREATE_CONFIRM` )
            )->a( n = `text`  v = `Create`
            )->a( n = `type`  v = `Emphasized` ).
    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `press` v = client->_event( `POPUP_CREATE_CANCEL` )
            )->a( n = `text`  v = `Cancel` ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
