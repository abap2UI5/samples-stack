" @keywords eml rap read travel select entity behavior
" @summary reads one instance by its key - a missing key comes back in FAILED, not as an exception
"! <p class="shorttext synchronized">RAP - Read a Travel</p>
"! Reads one instance by its key.
"!
"!     READ ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         ALL FIELDS WITH VALUE #( ( travelid = travel_id ) )
"!       RESULT DATA(t_result)
"!       FAILED DATA(s_failed).
"!
"! Worth knowing: a key that does not exist is not an exception. It comes back
"! in FAILED and RESULT stays empty, so the response is what you check - never
"! sy-subrc.
CLASS z2ui5_cl_smps_app_001 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        agency_id      TYPE string,
        customer_id    TYPE string,
        begin_date     TYPE string,
        end_date       TYPE string,
        total_price    TYPE string,
        overall_status TYPE string,
        description    TYPE string,
      END OF ty_s_travel.
    DATA s_travel TYPE ty_s_travel.

    DATA travel_id TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS key_prefill.
    METHODS data_read.
    METHODS view_display.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_001 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      key_prefill( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `READ` ).
      data_read( ).
    ENDIF.

  ENDMETHOD.


  METHOD key_prefill.

    " Prefilled with a key that really exists, so Read answers on the first
    " press instead of with "Travel does not exist". Read off the table
    " rather than hard coded: the demo data only starts at 1 on an empty
    " table, and after a few creates and deletes the lowest key is a
    " different one.
    SELECT SINGLE FROM z2ui5_r_smps_trv
      FIELDS MIN( TravelId ) INTO @DATA(first_id).

    travel_id = COND #( WHEN first_id IS NOT INITIAL THEN |{ first_id ALPHA = OUT }| ).

  ENDMETHOD.


  METHOD data_read.

    READ ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        ALL FIELDS WITH VALUE #( ( travelid = travel_id ) )
      RESULT DATA(t_result)
      FAILED DATA(s_failed).

    IF s_failed-travel IS NOT INITIAL.

      s_travel = VALUE #( ).
      client->message_box_display( text = |Travel { travel_id } does not exist| type = `error` ).

    ELSE.

      DATA(s_result) = t_result[ 1 ].
      s_travel = VALUE #(
        agency_id      = |{ s_result-agencyid ALPHA = OUT }|
        customer_id    = |{ s_result-customerid ALPHA = OUT }|
        begin_date     = |{ s_result-begindate DATE = ISO }|
        end_date       = |{ s_result-enddate DATE = ISO }|
        total_price    = |{ s_result-totalprice } { s_result-currencycode }|
        overall_status = z2ui5_cl_smps_context=>status_get_text( s_result-overallstatus )
        description    = |{ s_result-description }| ).

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
    view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - EML - 01 Read Travel`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
            )->ele( n = `SimpleForm` ns = `form`
                )->a( n = `title`    v = `READ ENTITIES OF Z2UI5_R_SMPS_TRV`
                )->a( n = `editable` b = abap_true
                )->ele( n = `content` ns = `form`
                    )->tag( `Label`
                        )->a( n = `text` v = `Travel ID`
                    )->tag( `Input`
                        )->a( n = `placeholder` v = `No travel in the table - press Regenerate Demo Data in the overview`
                        )->a( n = `value`       v = client->_bind( travel_id )
                    )->tag( `Button`
                        )->a( n = `press` v = client->_event( `READ` )
                        )->a( n = `text`  v = `Read`
                        )->a( n = `type`  v = `Emphasized`
                    )->tag( `Label`
                        )->a( n = `text` v = `Agency`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( s_travel-agency_id )
                    )->tag( `Label`
                        )->a( n = `text` v = `Customer`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( s_travel-customer_id )
                    )->tag( `Label`
                        )->a( n = `text` v = `Begin Date`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( s_travel-begin_date )
                    )->tag( `Label`
                        )->a( n = `text` v = `End Date`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( s_travel-end_date )
                    )->tag( `Label`
                        )->a( n = `text` v = `Total Price`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( s_travel-total_price )
                    )->tag( `Label`
                        )->a( n = `text` v = `Status`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( s_travel-overall_status )
                    )->tag( `Label`
                        )->a( n = `text` v = `Description`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( s_travel-description ) ).
    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
