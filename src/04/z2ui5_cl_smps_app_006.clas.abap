" @keywords eml rap draft list objectstatus which travels
" @summary READ ... %is_draft = mk-on
"! <p class="shorttext synchronized">RAP with Draft - Which Travels Have One</p>
"! A draft and its active instance share the key - only %is_draft separates
"! them. So reading the keys with %is_draft = mk-on answers the question "which
"! travels have a draft?": everything that comes back in RESULT has one,
"! everything else lands in FAILED.
"!
"!     READ ENTITIES OF z2ui5_r_smps_trd
"!       ENTITY travel
"!         FIELDS ( travelid ) WITH VALUE #( FOR s_row IN t_result
"!                                           ( %tky = VALUE #( traveluuid = s_row-traveluuid
"!                                                             %is_draft  = if_abap_behv=>mk-on ) ) )
"!       RESULT DATA(t_drafts)
"!       FAILED DATA(s_failed).
"!
"! Worth knowing: every other draft sample of this repository builds on this
"! one trick. Start here.
CLASS z2ui5_cl_smps_app_006 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        travel_uuid TYPE string,
        travel_id   TYPE string,
        customer_id TYPE string,
        description TYPE string,
        status      TYPE string,
        draft_text  TYPE string,
        draft_state TYPE string,
      END OF ty_s_travel.
    DATA t_travels TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS data_read.
    METHODS view_display.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_006 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      CASE client->get_event( ).
        WHEN `REFRESH`.
          data_read( ).
        WHEN `GENERATE`.
          client->message_toast_display( z2ui5_cl_smps_data_trd=>data_reset( ) ).
          data_read( ).
      ENDCASE.
    ENDIF.

  ENDMETHOD.


  METHOD data_read.

    " the CDS view returns the active instances - a draft is not in there
    SELECT FROM z2ui5_r_smps_trd
      FIELDS TravelUuid,
             TravelId,
             CustomerId,
             Description,
             OverallStatus
      ORDER BY TravelId
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

    " A draft shares the key of its active instance - only %is_draft tells
    " the two apart. So reading the keys with %is_draft = on answers the
    " question "which travels have a draft?": every key that comes back in
    " RESULT has one, everything else lands in FAILED. That is the whole
    " trick, and every other draft sample of this repository relies on it.
    READ ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        FIELDS ( travelid ) WITH VALUE #( FOR s_row IN t_result
                                          ( %tky = VALUE #( traveluuid = s_row-traveluuid
                                                            %is_draft  = if_abap_behv=>mk-on ) ) )
      RESULT DATA(t_drafts).

    t_travels = VALUE #( FOR s_result IN t_result
        ( travel_uuid = |{ s_result-traveluuid }|
          travel_id   = |{ s_result-travelid ALPHA = OUT }|
          customer_id = |{ s_result-customerid ALPHA = OUT }|
          description = |{ s_result-description }|
          status      = z2ui5_cl_smps_context=>status_get_text( s_result-overallstatus )
          draft_text  = COND #( WHEN line_exists( t_drafts[ KEY entity traveluuid = s_result-traveluuid ] )
                                THEN `Draft` ELSE `-` )
          draft_state = COND #( WHEN line_exists( t_drafts[ KEY entity traveluuid = s_result-traveluuid ] )
                                THEN `Warning` ELSE `None` ) ) ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core` ).
    DATA(table) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - EML - 06 Which Travels Have a Draft?`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
            )->ele( `Table`
                )->a( n = `items` v = client->_bind( t_travels ) ).

    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `READ ENTITIES ... WITH %is_draft = mk-on`
            )->tag( `ToolbarSpacer`
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
                )->a( n = `text` v = `Description`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Draft` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUSTOMER_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DESCRIPTION}`
                )->tag( `Text`
                    )->a( n = `text` v = `{STATUS}`
                )->ele( `ObjectStatus`
                    )->a( n = `state` v = `{DRAFT_STATE}`
                    )->a( n = `text`  v = `{DRAFT_TEXT}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
