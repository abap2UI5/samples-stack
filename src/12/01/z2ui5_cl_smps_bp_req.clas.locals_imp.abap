CLASS lhc_request DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF cs_status,
        new      TYPE c LENGTH 1 VALUE 'N',
        approved TYPE c LENGTH 1 VALUE 'A',
        rejected TYPE c LENGTH 1 VALUE 'R',
      END OF cs_status.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR request RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR request RESULT result.

    METHODS getdefaultsforcreate FOR READ
      IMPORTING keys FOR FUNCTION request~getdefaultsforcreate RESULT result.

    METHODS setinitialstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR request~setinitialstatus.

    METHODS validatequantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR request~validatequantity.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION request~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION request~reject RESULT result.

    METHODS copyrequest FOR MODIFY
      IMPORTING keys FOR ACTION request~copyrequest.

    METHODS createrequest FOR MODIFY
      IMPORTING keys FOR ACTION request~createrequest.

ENDCLASS.


CLASS lhc_request IMPLEMENTATION.

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

    IF requested_authorizations-%action-approve = if_abap_behv=>mk-on.
      result-%action-approve = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-reject = if_abap_behv=>mk-on.
      result-%action-reject = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-copyrequest = if_abap_behv=>mk-on.
      result-%action-copyrequest = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-createrequest = if_abap_behv=>mk-on.
      result-%action-createrequest = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.


  METHOD get_instance_features.

    " Feature control answers ONE question per instance: what may happen to
    " it right now. The runtime asks it before every update, delete and
    " action - so a disabled operation is refused no matter who calls it - and
    " a UI asks the same question with GET PERMISSIONS to grey out what would
    " be refused anyway.
    "
    " requested_features says which of the answers the caller wants. Nothing
    " here is expensive, so all four are computed - a check against it pays
    " off once one of them needs a READ of its own.
    READ ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        FIELDS ( status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    " A New request may be changed, approved, rejected and deleted. Once it
    " is decided nothing changes any more - and an approved one is a record
    " that stays: it cannot even be deleted, a rejected one can.
    result = VALUE #( FOR request IN requests
                      LET open = COND #( WHEN request-status = cs_status-new
                                         THEN if_abap_behv=>fc-o-enabled
                                         ELSE if_abap_behv=>fc-o-disabled ) IN
                      ( %tky            = request-%tky
                        %update         = open
                        %delete         = COND #( WHEN request-status = cs_status-approved
                                                  THEN if_abap_behv=>fc-o-disabled
                                                  ELSE if_abap_behv=>fc-o-enabled )
                        %action-approve = open
                        %action-reject  = open ) ).

  ENDMETHOD.


  METHOD getdefaultsforcreate.

    " A default function proposes the values of a new instance - it creates
    " nothing. The caller reads the proposal, lets the user change it, and
    " sends the CREATE itself. %param is a whole instance; whatever is left
    " initial here has no proposal.
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    result = VALUE #( FOR key IN keys
                      ( %cid   = key-%cid
                        %param = VALUE #( title    = |Request of { today DATE = ISO }|
                                          quantity = 1
                                          priority = 'M' ) ) ).

  ENDMETHOD.


  METHOD setinitialstatus.

    READ ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        FIELDS ( status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    DELETE requests WHERE status IS NOT INITIAL.
    IF requests IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        UPDATE FIELDS ( status )
        WITH VALUE #( FOR request IN requests
                      ( %tky   = request-%tky
                        status = cs_status-new ) )
      REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

  ENDMETHOD.


  METHOD validatequantity.

    READ ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        FIELDS ( quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    LOOP AT requests INTO DATA(request).

      " %state_area groups the messages of one validation: the runtime clears
      " the area before the validation runs again, so a corrected value does
      " not keep the old message - which matters once the determine action
      " checkRequest runs it on every change
      APPEND VALUE #( %tky        = request-%tky
                      %state_area = 'VALIDATE_QUANTITY' ) TO reported-request.

      IF request-quantity BETWEEN 1 AND 1000.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = request-%tky ) TO failed-request.
      APPEND VALUE #( %tky              = request-%tky
                      %state_area       = 'VALIDATE_QUANTITY'
                      %element-quantity = if_abap_behv=>mk-on
                      %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'Quantity must be between 1 and 1000' ) ) TO reported-request.

    ENDLOOP.

  ENDMETHOD.


  METHOD approve.

    " cl_abap_behv_aux tells the handler HOW it was called: through the
    " projection z2ui5_c_smps_req, or on the business object itself. The
    " sample stores the answer, so the list shows which contract approved.
    cl_abap_behv_aux=>get_current_context( IMPORTING from_projection = DATA(projection) ).

    MODIFY ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        UPDATE FIELDS ( status approvedvia )
        WITH VALUE #( FOR key IN keys
                      ( %tky        = key-%tky
                        status      = cs_status-approved
                        approvedvia = COND #( WHEN projection IS INITIAL
                                              THEN 'Z2UI5_R_SMPS_REQ'
                                              ELSE projection ) ) )
      FAILED DATA(update_failed)
      REPORTED DATA(update_reported).

    failed   = CORRESPONDING #( DEEP update_failed ).
    reported = CORRESPONDING #( DEEP update_reported ).

    READ ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    result = VALUE #( FOR request IN requests
                      ( %tky   = request-%tky
                        %param = request ) ).

  ENDMETHOD.


  METHOD reject.

    " the parameter arrives per key in %param - one reason per request
    LOOP AT keys INTO DATA(key) WHERE %param-reason IS INITIAL.

      APPEND VALUE #( %tky = key-%tky ) TO failed-request.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'A rejection needs a reason' ) ) TO reported-request.

    ENDLOOP.

    MODIFY ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        UPDATE FIELDS ( status note )
        WITH VALUE #( FOR k IN keys WHERE ( %param-reason IS NOT INITIAL )
                      ( %tky   = k-%tky
                        status = cs_status-rejected
                        note   = k-%param-reason ) ).

    READ ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        ALL FIELDS WITH VALUE #( FOR k IN keys WHERE ( %param-reason IS NOT INITIAL ) ( %tky = k-%tky ) )
      RESULT DATA(requests).

    result = VALUE #( FOR request IN requests
                      ( %tky   = request-%tky
                        %param = request ) ).

  ENDMETHOD.


  METHOD copyrequest.

    " A factory action creates a NEW instance from an existing one. The new
    " instance is created under the %cid of the action call, so MAPPED reaches
    " the caller under the very %cid it sent, together with the new key.
    READ ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        FIELDS ( title quantity priority )
        WITH CORRESPONDING #( keys )
      RESULT DATA(sources).

    MODIFY ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        CREATE FIELDS ( title quantity priority )
        WITH VALUE #( FOR key IN keys
                      LET source = VALUE #( sources[ %tky = key-%tky ] OPTIONAL ) IN
                      ( %cid     = key-%cid
                        title    = COND #( WHEN key-%param-title IS NOT INITIAL
                                            THEN key-%param-title
                                            ELSE source-title )
                        quantity = source-quantity
                        priority = source-priority ) )
      MAPPED DATA(create_mapped)
      FAILED DATA(create_failed)
      REPORTED DATA(create_reported).

    mapped   = CORRESPONDING #( DEEP create_mapped ).
    failed   = CORRESPONDING #( DEEP create_failed ).
    reported = CORRESPONDING #( DEEP create_reported ).

  ENDMETHOD.


  METHOD createrequest.

    " the static twin of copyRequest: no source instance, everything comes
    " from the parameter
    MODIFY ENTITIES OF z2ui5_r_smps_req IN LOCAL MODE
      ENTITY request
        CREATE FIELDS ( title quantity priority )
        WITH VALUE #( FOR key IN keys
                      ( %cid     = key-%cid
                        title    = key-%param-title
                        quantity = key-%param-quantity
                        priority = key-%param-priority ) )
      MAPPED DATA(create_mapped)
      FAILED DATA(create_failed)
      REPORTED DATA(create_reported).

    mapped   = CORRESPONDING #( DEEP create_mapped ).
    failed   = CORRESPONDING #( DEEP create_failed ).
    reported = CORRESPONDING #( DEEP create_reported ).

  ENDMETHOD.

ENDCLASS.
