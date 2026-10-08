" @keywords eml rap create travel insert commit datepicker
" @summary MODIFY ... CREATE, key from MAPPED
"! <p class="shorttext synchronized">RAP - Create a Travel</p>
"! Creates one instance. The %cid is a temporary id you invent: the business
"! object does not know the key yet, so it reports the new one back under that
"! %cid in MAPPED.
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         CREATE FIELDS ( agencyid customerid begindate enddate ... )
"!         WITH VALUE #( ( %cid = `CREATE_1` agencyid = ... ) )
"!       MAPPED DATA(s_mapped)
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"!     COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
"!       FAILED DATA(s_failed_commit)
"!       REPORTED DATA(s_reported_commit).
"!
"! Worth knowing: nothing reaches the database before the COMMIT, and the
"! validations only run there - a CREATE that came back clean can still fail at
"! the COMMIT. That is why both responses are evaluated.
CLASS z2ui5_cl_smps_app_002 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        agency_id   TYPE string,
        customer_id TYPE string,
        begin_date  TYPE string,
        end_date    TYPE string,
        booking_fee TYPE string,
        currency    TYPE string,
        description TYPE string,
      END OF ty_s_travel.
    DATA s_travel TYPE ty_s_travel.

    DATA created_id TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS data_create.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_002 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      " prefilled with a set that passes both validations of the business
      " object - CustomerId is filled and EndDate is not before BeginDate -
      " so pressing Create right away produces a travel. Change a value and
      " the same button shows what the validations answer instead.
      " CONV d( ) is what turns the sum back into a date: today + 14 is
      " calculated as a day number, and a string template renders that number
      " instead of a date - the field showed 739853
      DATA(today) = cl_abap_context_info=>get_system_date( ).
      DATA(end_date) = CONV d( today + 14 ).

      s_travel = VALUE #( agency_id   = `070001`
                          customer_id = `000001`
                          begin_date  = |{ today }|
                          end_date    = |{ end_date }|
                          booking_fee = `20.00`
                          currency    = `EUR`
                          description = `New travel created from sample 02` ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `CREATE` ).
      data_create( ).
    ENDIF.

  ENDMETHOD.


  METHOD data_create.

    " CREATE hands the new instance to the transactional buffer. The %cid is
    " a temporary id chosen by the caller: the business object does not know
    " the key yet, so MAPPED reports it back under that %cid.
    MODIFY ENTITIES OF z2ui5_r_smps_trv
      ENTITY travel
        CREATE FIELDS ( agencyid customerid begindate enddate bookingfee currencycode description )
        WITH VALUE #( ( %cid         = `CREATE_1`
                        agencyid     = s_travel-agency_id
                        customerid   = s_travel-customer_id
                        begindate    = s_travel-begin_date
                        enddate      = s_travel-end_date
                        bookingfee   = s_travel-booking_fee
                        currencycode = s_travel-currency
                        description  = s_travel-description ) )
      MAPPED DATA(s_mapped)
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    " nothing is persisted before the COMMIT - and the validations of the
    " business object only run now, so this is where they can still fail
    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.

      " a failed save keeps the changes in the transactional buffer - discard
      " them, or the next EML statement and abap2UI5's own COMMIT WORK at the
      " end of the roundtrip run into them
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported_commit-travel ).
      RETURN.

    ENDIF.

    " thanks to early numbering the key assigned by the business object is
    " available in MAPPED, addressed by the %cid sent above
    created_id = |{ s_mapped-travel[ %cid = `CREATE_1` ]-travelid ALPHA = OUT }|.
    client->message_toast_display( |Travel { created_id } created| ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - EML - 02 Create Travel`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
            )->ele( n = `SimpleForm` ns = `form`
                )->a( n = `title`    v = `MODIFY ENTITIES OF Z2UI5_R_SMPS_TRV ... CREATE`
                )->a( n = `editable` b = abap_true
                )->ele( n = `content` ns = `form`
                    )->tag( `Label`
                        )->a( n = `text` v = `Agency ID`
                    )->tag( `Input`
                        )->a( n = `placeholder` v = `e.g. 070001`
                        )->a( n = `value`       v = client->_bind( s_travel-agency_id )
                    )->tag( `Label`
                        )->a( n = `text` v = `Customer ID`
                    )->tag( `Input`
                        )->a( n = `placeholder` v = `e.g. 000001`
                        )->a( n = `value`       v = client->_bind( s_travel-customer_id )
                    )->tag( `Label`
                        )->a( n = `text` v = `Begin Date`
                    )->tag( `DatePicker`
                        )->a( n = `value`       v = client->_bind( s_travel-begin_date )
                        )->a( n = `valueFormat` v = `yyyyMMdd`
                    )->tag( `Label`
                        )->a( n = `text` v = `End Date`
                    )->tag( `DatePicker`
                        )->a( n = `value`       v = client->_bind( s_travel-end_date )
                        )->a( n = `valueFormat` v = `yyyyMMdd`
                    )->tag( `Label`
                        )->a( n = `text` v = `Booking Fee`
                    )->tag( `Input`
                        )->a( n = `placeholder` v = `e.g. 20.00`
                        )->a( n = `value`       v = client->_bind( s_travel-booking_fee )
                    )->tag( `Label`
                        )->a( n = `text` v = `Currency`
                    )->tag( `Input`
                        )->a( n = `value` v = client->_bind( s_travel-currency )
                    )->tag( `Label`
                        )->a( n = `text` v = `Description`
                    )->tag( `Input`
                        )->a( n = `value` v = client->_bind( s_travel-description )
                    )->tag( `Label`
                        )->a( n = `text` v = ``
                    )->tag( `Button`
                        )->a( n = `press` v = client->_event( `CREATE` )
                        )->a( n = `text`  v = `Create`
                        )->a( n = `type`  v = `Emphasized`
                    )->tag( `Label`
                        )->a( n = `text` v = `Created Travel ID`
                    )->tag( `Input`
                        )->a( n = `enabled` b = abap_false
                        )->a( n = `value`   v = client->_bind( created_id ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
