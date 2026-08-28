" @keywords eml rap delete travel remove commit table
" @summary deletes one instance - MODIFY ... DELETE FROM
"! <p class="shorttext synchronized">RAP - Delete a Travel</p>
"! Deletes one instance.
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trv
"!       ENTITY travel
"!         DELETE FROM VALUE #( ( travelid = travel_id ) )
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"! Worth knowing: DELETE FROM takes the key only, there is no field list. And
"! like every other operation it only asks the transactional buffer - the row
"! is gone after the COMMIT, not before.
CLASS z2ui5_cl_smps_app_004 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        travel_id   TYPE string,
        customer_id TYPE string,
        description TYPE string,
      END OF ty_s_travel.
    DATA t_travels TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS data_read.
    METHODS data_delete.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_004 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `DELETE` ).
      data_delete( ).
    ENDIF.

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trv
      FIELDS TravelId,
             CustomerId,
             Description
      ORDER BY TravelId
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

    t_travels = VALUE #( FOR s_result IN t_result
        ( travel_id   = |{ s_result-travelid ALPHA = OUT }|
          customer_id = |{ s_result-customerid ALPHA = OUT }|
          description = |{ s_result-description }| ) ).

  ENDMETHOD.


  METHOD data_delete.

    DATA(travel_id) = client->get_event_arg( 1 ).

    " DELETE only needs the key - and it can still fail, e.g. when the
    " business object refuses the deletion or the instance is locked
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

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.

      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported_commit-travel ).
      RETURN.

    ENDIF.

    data_read( ).
    client->message_toast_display( |Travel { travel_id } deleted| ).

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
            )->a( n = `title`          v = `abap2UI5 - EML - 04 Delete Travel`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
            )->ele( `Table`
                )->a( n = `items` v = client->_bind( t_travels ) ).

    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `MODIFY ENTITIES OF Z2UI5_R_SMPS_TRV ... DELETE` ).

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
                )->a( n = `text` v = `` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TRAVEL_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CUSTOMER_ID}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DESCRIPTION}`
                )->tag( `Button`
                    )->a( n = `press` v = client->_event( val   = `DELETE`
                                            t_arg = VALUE #( ( `${TRAVEL_ID}` ) ) )
                    )->a( n = `text`  v = `Delete`
                    )->a( n = `icon`  v = `sap-icon://delete` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
