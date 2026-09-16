CLASS lhc_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR travel RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE travel.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR travel~setinitialvalues.

    METHODS validatecustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatecustomer.

    METHODS validatedates FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validatedates.

    METHODS accepttravel FOR MODIFY
      IMPORTING keys FOR ACTION travel~accepttravel RESULT result.

    METHODS rejecttravel FOR MODIFY
      IMPORTING keys FOR ACTION travel~rejecttravel RESULT result.

ENDCLASS.


CLASS lhc_travel IMPLEMENTATION.

  METHOD get_global_authorizations.

    " the sample deliberately grants everything - a real business object would
    " check an authorization object here. Only what was asked for is answered.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-accepttravel = if_abap_behv=>mk-on.
      result-%action-accepttravel = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-rejecttravel = if_abap_behv=>mk-on.
      result-%action-rejecttravel = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.


  METHOD earlynumbering_create.

    " The key is a readable number, so it cannot be drawn by the managed
    " runtime the way a UUID can - it is assigned here and handed back in
    " MAPPED, which is where the caller reads the new key from.
    " Good enough for a sample: a productive business object would use a
    " number range object instead of MAX( ), which is not safe against two
    " users creating at the very same moment.
    SELECT SINGLE FROM z2ui5_t_smps_trv                 "#EC CI_NOWHERE
      FIELDS MAX( travel_id )
      INTO @DATA(max_id).

    LOOP AT entities INTO DATA(entity).

      max_id += 1.
      APPEND VALUE #( %cid = entity-%cid
                      %key = VALUE #( travelid = max_id ) ) TO mapped-travel.

    ENDLOOP.

  ENDMETHOD.


  METHOD setinitialvalues.

    " IN LOCAL MODE bypasses feature control and the readonly flags of the
    " behavior definition - which is exactly why a determination may write
    " fields the caller is not allowed to touch
    READ ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        FIELDS ( bookingfee currencycode overallstatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    DELETE travels WHERE overallstatus IS NOT INITIAL.
    IF travels IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( overallstatus totalprice currencycode )
        WITH VALUE #( FOR travel IN travels
                      ( %tky          = travel-%tky
                        overallstatus = 'O'
                        totalprice    = travel-bookingfee
                        currencycode  = COND #( WHEN travel-currencycode IS INITIAL
                                                THEN 'EUR'
                                                ELSE travel-currencycode ) ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

  ENDMETHOD.


  METHOD validatecustomer.

    READ ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        FIELDS ( customerid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

      IF travel-customerid IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.
      APPEND VALUE #( %tky                = travel-%tky
                      %element-customerid = if_abap_behv=>mk-on
                      %msg                = new_message_with_text(
                                                severity = if_abap_behv_message=>severity-error
                                                text     = 'Customer ID is initial' ) ) TO reported-travel.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatedates.

    READ ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        FIELDS ( begindate enddate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

      IF travel-begindate IS NOT INITIAL AND travel-enddate IS NOT INITIAL
          AND travel-enddate >= travel-begindate.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.
      APPEND VALUE #( %tky               = travel-%tky
                      %element-begindate = if_abap_behv=>mk-on
                      %element-enddate   = if_abap_behv=>mk-on
                      %msg               = new_message_with_text(
                                               severity = if_abap_behv_message=>severity-error
                                               text     = 'End date must not be before begin date' ) ) TO reported-travel.

    ENDLOOP.

  ENDMETHOD.


  METHOD accepttravel.

    MODIFY ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( overallstatus )
        WITH VALUE #( FOR key IN keys
                      ( %tky          = key-%tky
                        overallstatus = 'A' ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

    " an action with `result [1] $self` returns the changed instance, so the
    " caller does not have to read it again
    READ ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels
                      ( %tky   = travel-%tky
                        %param = travel ) ).

  ENDMETHOD.


  METHOD rejecttravel.

    MODIFY ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( overallstatus )
        WITH VALUE #( FOR key IN keys
                      ( %tky          = key-%tky
                        overallstatus = 'X' ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

    READ ENTITIES OF z2ui5_r_smps_trv IN LOCAL MODE
      ENTITY travel
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels
                      ( %tky   = travel-%tky
                        %param = travel ) ).

  ENDMETHOD.

ENDCLASS.
