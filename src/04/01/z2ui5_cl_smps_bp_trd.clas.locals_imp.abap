CLASS lhc_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR travel RESULT result.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR travel~setinitialvalues.

    METHODS settravelid FOR DETERMINE ON SAVE
      IMPORTING keys FOR travel~settravelid.

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


  METHOD setinitialvalues.

    " IN LOCAL MODE bypasses feature control and the readonly flags of the
    " behavior definition - which is exactly why a determination may write
    " fields the caller is not allowed to touch
    READ ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
      ENTITY travel
        FIELDS ( bookingfee currencycode overallstatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    DELETE travels WHERE overallstatus IS NOT INITIAL.
    IF travels IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
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


  METHOD settravelid.

    " The readable number is only handed out when the draft really becomes
    " active - a discarded draft must not burn one. `on save` determinations
    " run during Activate, which is exactly that moment.
    READ ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
      ENTITY travel
        FIELDS ( travelid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    DELETE travels WHERE travelid IS NOT INITIAL.
    IF travels IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE FROM z2ui5_t_smps_trd                 "#EC CI_NOWHERE
      FIELDS MAX( travel_id )
      INTO @DATA(max_id).

    MODIFY ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( travelid )
        WITH VALUE #( FOR travel IN travels INDEX INTO i
                      ( %tky     = travel-%tky
                        travelid = max_id + i ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

  ENDMETHOD.


  METHOD validatecustomer.

    READ ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
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

    READ ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
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

    MODIFY ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( overallstatus )
        WITH VALUE #( FOR key IN keys
                      ( %tky          = key-%tky
                        overallstatus = 'A' ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

    " an action with `result [1] $self` returns the changed instance, so the
    " caller does not have to read it again
    READ ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
      ENTITY travel
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels
                      ( %tky   = travel-%tky
                        %param = travel ) ).

  ENDMETHOD.


  METHOD rejecttravel.

    MODIFY ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( overallstatus )
        WITH VALUE #( FOR key IN keys
                      ( %tky          = key-%tky
                        overallstatus = 'X' ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

    READ ENTITIES OF z2ui5_r_smps_trd IN LOCAL MODE
      ENTITY travel
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels
                      ( %tky   = travel-%tky
                        %param = travel ) ).

  ENDMETHOD.

ENDCLASS.
