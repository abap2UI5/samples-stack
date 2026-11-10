" @keywords approval approve reject inbox worklist action execute rap eml travel multiselect
" @summary An approval worklist - the open travels, several selected and accepted or rejected with one EXECUTE, the list shrinking as they are decided
"! <p class="shorttext synchronized">RAP - Approval Worklist</p>
"! A worklist, not a maintenance screen: it shows what is waiting for a
"! decision - the open travels - and gets shorter with every decision. The
"! user selects one or many and presses Accept or Reject; the app calls the
"! action of the business object for all of them in one statement:
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         EXECUTE acceptTravel FROM VALUE #( FOR k IN t_keys ( travelid = k ) )
"!       RESULT DATA(t_result)
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"! The action changes the status - the app never writes OverallStatus
"! itself, which the behavior definition declares readonly. RESULT hands
"! back the changed instances, so the toast can say what happened without
"! reading them again. The filter switches between the worklist and the
"! decided travels, so a decision can be looked up afterwards.
CLASS z2ui5_cl_smps_app_030 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        selkz        TYPE abap_bool,
        travel_id    TYPE string,
        customer_id  TYPE string,
        begin_date   TYPE string,
        end_date     TYPE string,
        total_price  TYPE string,
        description  TYPE string,
        status_text  TYPE string,
        status_state TYPE string,
      END OF ty_s_travel.
    TYPES ty_t_travel TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.
    DATA t_travels TYPE ty_t_travel.

    "! OPEN - the worklist, DONE - the decided travels
    DATA filter TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS data_read.
    METHODS on_event.

    "! accepts or rejects every selected travel with one EXECUTE
    METHODS travels_decide
      IMPORTING
        accept TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_030 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      filter = `OPEN`.
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
            )->a( n = `title`          v = `abap2UI5 - EML - 30 Approval Worklist`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_travels )
        )->a( n = `mode`       v = COND #( WHEN filter = `OPEN` THEN `MultiSelect` ELSE `None` )
        )->a( n = `noDataText` v = COND #( WHEN filter = `OPEN`
                                           THEN `Nothing waits for a decision - press Reset Demo Data for open travels`
                                           ELSE `No travel decided yet` ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( filter )
                )->a( n = `selectionChange` v = client->_event( `FILTER` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `OPEN`
                        )->a( n = `text` v = `To Decide`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`  v = `DONE`
                        )->a( n = `text` v = `Decided`
                )->end(
            )->end(
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `ACCEPT` )
                )->a( n = `text`    v = `Accept`
                )->a( n = `icon`    v = `sap-icon://accept`
                )->a( n = `type`    v = `Accept`
                )->a( n = `visible` b = xsdbool( filter = `OPEN` )
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REJECT` )
                )->a( n = `text`    v = `Reject`
                )->a( n = `icon`    v = `sap-icon://decline`
                )->a( n = `type`    v = `Reject`
                )->a( n = `visible` b = xsdbool( filter = `OPEN` )
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
                )->a( n = `text` v = `Customer`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Dates`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Total Price`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `selected` v = `{SELKZ}`
            )->ele( `cells`
                )->tag( `ObjectIdentifier`
                    )->a( n = `title` v = `{TRAVEL_ID}`
                    )->a( n = `text`  v = `{DESCRIPTION}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUSTOMER_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{BEGIN_DATE} - {END_DATE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{TOTAL_PRICE}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{STATUS_TEXT}`
                    )->a( n = `state` v = `{STATUS_STATE}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `ACCEPT`.
        travels_decide( abap_true ).
      WHEN `REJECT`.
        travels_decide( abap_false ).
      WHEN `FILTER` OR `REFRESH`.
        data_read( ).
      WHEN `GENERATE`.
        client->message_toast_display( z2ui5_cl_smps_data_trv=>data_reset( ) ).
        data_read( ).
    ENDCASE.
    view_display( ).

  ENDMETHOD.


  METHOD data_read.

    " the worklist is what still waits for a decision - the filter is part
    " of the SELECT, so a decided travel leaves the list on the next read
    TYPES ty_r_status TYPE RANGE OF z2ui5_t_smps_trv-overall_status.
    DATA(t_status) = VALUE ty_r_status( ( sign   = `I`
                                          option = COND #( WHEN filter = `OPEN` THEN `EQ` ELSE `NE` )
                                          low    = z2ui5_cl_smps_context=>cs_status-open ) ).

    SELECT FROM z2ui5_r_smps_trv
      FIELDS TravelId, CustomerId, BeginDate, EndDate, TotalPrice, CurrencyCode, Description, OverallStatus
      WHERE OverallStatus IN @t_status
      ORDER BY BeginDate, TravelId
      INTO TABLE @DATA(t_result) UP TO 100 ROWS.

    t_travels = VALUE #( FOR r IN t_result
        ( travel_id    = |{ r-travelid ALPHA = OUT }|
          customer_id  = |{ r-customerid ALPHA = OUT }|
          begin_date   = |{ r-begindate DATE = ISO }|
          end_date     = |{ r-enddate DATE = ISO }|
          total_price  = |{ r-totalprice } { r-currencycode }|
          description  = |{ r-description }|
          status_text  = z2ui5_cl_smps_context=>status_get_text( r-overallstatus )
          status_state = z2ui5_cl_smps_context=>status_get_state( r-overallstatus ) ) ).

  ENDMETHOD.


  METHOD travels_decide.

    DATA(t_keys) = VALUE string_table( FOR t IN t_travels WHERE ( selkz = abap_true ) ( t-travel_id ) ).
    IF t_keys IS INITIAL.
      client->message_box_display( `Select the travels to decide first` ).
      RETURN.
    ENDIF.

    " an action is called like any other operation - by key, many at once.
    " Two statements rather than a dynamic action name: the action is part
    " of the statement, which is what lets the compiler check it
    IF accept = abap_true.
      MODIFY ENTITIES OF z2ui5_r_smps_trv
        ENTITY travel
          EXECUTE acceptTravel FROM VALUE #( FOR k IN t_keys ( travelid = k ) )
        RESULT DATA(t_result)
        FAILED DATA(s_failed)
        REPORTED DATA(s_reported).
    ELSE.
      MODIFY ENTITIES OF z2ui5_r_smps_trv
        ENTITY travel
          EXECUTE rejectTravel FROM VALUE #( FOR k IN t_keys ( travelid = k ) )
        RESULT DATA(t_result_reject)
        FAILED s_failed
        REPORTED s_reported.
      t_result = CORRESPONDING #( t_result_reject ).
    ENDIF.

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

    " RESULT carries the changed instances - the new status comes from the
    " business object, not from what the app expected it to be
    DATA(ids) = concat_lines_of( sep   = `, `
                                 table = VALUE string_table( FOR r IN t_result ( |{ r-travelid ALPHA = OUT }| ) ) ).
    DATA(status) = z2ui5_cl_smps_context=>status_get_text( VALUE #( t_result[ 1 ]-%param-overallstatus OPTIONAL ) ).
    client->message_toast_display( |{ status }: { ids }| ).
    data_read( ).

  ENDMETHOD.

ENDCLASS.
