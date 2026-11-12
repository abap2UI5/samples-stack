CLASS lhe_ticket DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    METHODS on_ticket_created FOR ENTITY EVENT
      ticketcreated FOR ticket~TicketCreated.

    METHODS on_status_changed FOR ENTITY EVENT
      statuschanged FOR ticket~StatusChanged.
ENDCLASS.

CLASS lhe_ticket IMPLEMENTATION.

  METHOD on_ticket_created.
    DATA lt_log TYPE STANDARD TABLE OF z2ui5_t_smps_log WITH EMPTY KEY.
    DATA lv_now TYPE timestampl.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    TRY.
        LOOP AT ticketcreated INTO DATA(ls_ev).
          APPEND VALUE #(
            log_uuid    = cl_system_uuid=>create_uuid_x16_static( )
            ticket_uuid = ls_ev-ticketuuid
            event_name  = 'TicketCreated'
            log_text    = |NOTIFICATION event (key only): ticket { ls_ev-ticketuuid } was created.|
            created_by  = lv_user
            created_at  = lv_now ) TO lt_log.
        ENDLOOP.
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.

    IF lt_log IS NOT INITIAL.
      INSERT z2ui5_t_smps_log FROM TABLE @lt_log.
    ENDIF.
  ENDMETHOD.

  METHOD on_status_changed.
    DATA lt_log TYPE STANDARD TABLE OF z2ui5_t_smps_log WITH EMPTY KEY.
    DATA lv_now TYPE timestampl.

    GET TIME STAMP FIELD lv_now.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    TRY.
        LOOP AT statuschanged INTO DATA(ls_ev).
          APPEND VALUE #(
            log_uuid    = cl_system_uuid=>create_uuid_x16_static( )
            ticket_uuid = ls_ev-ticketuuid
            event_name  = 'StatusChanged'
            log_text    = |DATA event (payload): Status={ ls_ev-status } | &&
                          |Priority={ ls_ev-priority } Title={ ls_ev-title } | &&
                          |(changed by { ls_ev-changedby }).|
            created_by  = lv_user
            created_at  = lv_now ) TO lt_log.
        ENDLOOP.
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.

    IF lt_log IS NOT INITIAL.
      INSERT z2ui5_t_smps_log FROM TABLE @lt_log.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
