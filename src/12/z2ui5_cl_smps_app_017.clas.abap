" @keywords rap eml feature control instance features get permissions enabled disabled buttons
" @summary GET PERMISSIONS asks the business object what may happen to each request - the buttons follow its answer, and the business object refuses the rest anyway
"! <p class="shorttext synchronized">RAP Actions - Feature Control with GET PERMISSIONS</p>
"! The business object z2ui5_r_smps_req decides per instance what may happen
"! to it: a New request may be changed, approved, rejected and deleted, a
"! decided one may not - and an approved one cannot even be deleted. That is
"! instance feature control, implemented in get_instance_features of the
"! behavior pool.
"!
"! The runtime asks it before every operation, so a disabled one is refused
"! whoever calls it. A UI asks the very same question up front, so it can
"! grey out what would be refused:
"!
"!     GET PERMISSIONS ONLY INSTANCE FEATURES OF z2ui5_r_smps_req
"!       ENTITY request
"!       FROM VALUE #( ( requestuuid = ... ) )
"!       REQUEST VALUE #( %update         = if_abap_behv=>mk-on
"!                        %delete         = if_abap_behv=>mk-on
"!                        %action-approve = if_abap_behv=>mk-on
"!                        %action-reject  = if_abap_behv=>mk-on )
"!       RESULT DATA(s_permissions)
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"! The switch "Ignore permissions" enables every button anyway - press one on
"! a decided request and the business object answers with FAILED: the UI only
"! mirrors the rule, the business object enforces it.
CLASS z2ui5_cl_smps_app_017 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_request,
        request_uuid    TYPE string,
        title           TYPE string,
        quantity        TYPE string,
        status          TYPE string,
        status_state    TYPE string,
        note            TYPE string,
        "! the answer of GET PERMISSIONS, one flag per operation
        update_enabled  TYPE abap_bool,
        delete_enabled  TYPE abap_bool,
        approve_enabled TYPE abap_bool,
        reject_enabled  TYPE abap_bool,
      END OF ty_s_request.
    TYPES ty_t_request TYPE STANDARD TABLE OF ty_s_request WITH EMPTY KEY.
    DATA t_requests TYPE ty_t_request.

    "! enables every button, whatever the business object says
    DATA ignore_permissions TYPE abap_bool.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_event.
    METHODS data_read.
    METHODS permissions_read.
    METHODS request_approve.
    METHODS request_reject.
    METHODS request_delete.
    METHODS data_save
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_017 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `APPROVE`.
        request_approve( ).

      WHEN `REJECT`.
        request_reject( ).

      WHEN `DELETE`.
        request_delete( ).

      WHEN `REFRESH`.
        data_read( ).

      WHEN `GENERATE`.
        client->message_toast_display( z2ui5_cl_smps_data_req=>data_reset( ) ).
        data_read( ).

      WHEN `IGNORE`.
        " the switch changes nothing in the business object - it only decides
        " whether the buttons follow the permissions, see view_display( )
        view_display( ).

    ENDCASE.

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_req                        "#EC CI_NOWHERE
      FIELDS RequestUuid,
             Title,
             Quantity,
             Status,
             Note
      ORDER BY CreatedAt DESCENDING
      INTO TABLE @DATA(t_result) UP TO 50 ROWS.

    t_requests = VALUE #( FOR s_result IN t_result
        ( request_uuid = |{ s_result-requestuuid }|
          title        = |{ s_result-title }|
          quantity     = |{ s_result-quantity }|
          status       = SWITCH #( s_result-status
                                   WHEN 'N' THEN `New`
                                   WHEN 'A' THEN `Approved`
                                   WHEN 'R' THEN `Rejected` )
          status_state = SWITCH #( s_result-status
                                   WHEN 'N' THEN `Information`
                                   WHEN 'A' THEN `Success`
                                   WHEN 'R' THEN `Error` )
          note         = |{ s_result-note }| ) ).

    permissions_read( ).

  ENDMETHOD.


  METHOD permissions_read.

    " the question itself sits in z2ui5_cl_smps_perm_req - one GET
    " PERMISSIONS statement for the whole list, see the class header
    DATA(t_permissions) = z2ui5_cl_smps_perm_req=>get(
        VALUE #( FOR s_row IN t_requests ( CONV #( s_row-request_uuid ) ) ) ).

    LOOP AT t_requests REFERENCE INTO DATA(row).

      DATA(s_permission) = VALUE #( t_permissions[ request_uuid = CONV #( row->request_uuid ) ] OPTIONAL ).
      row->update_enabled  = s_permission-update.
      row->delete_enabled  = s_permission-delete.
      row->approve_enabled = s_permission-approve.
      row->reject_enabled  = s_permission-reject.

    ENDLOOP.

  ENDMETHOD.


  METHOD request_approve.

    DATA(request_uuid) = CONV z2ui5_t_smps_req-request_uuid( client->get_event_arg( ) ).

    " the action is refused for a decided request - the feature control runs
    " before the handler, and FAILED says why (%fail-cause = disabled)
    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE approve FROM VALUE #( ( requestuuid = request_uuid ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_failed ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->message_toast_display( `Request approved` ).
    ENDIF.
    z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).

  ENDMETHOD.


  METHOD request_reject.

    DATA(request_uuid) = CONV z2ui5_t_smps_req-request_uuid( client->get_event_arg( ) ).

    " the reason is a parameter of the action - z2ui5_cl_smps_app_018 asks
    " the user for it, this sample passes a fixed one
    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE reject FROM VALUE #( ( requestuuid = request_uuid
                                       %param      = VALUE #( reason = 'Rejected in the feature control sample' ) ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_failed ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->message_toast_display( `Request rejected` ).
    ENDIF.
    z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).

  ENDMETHOD.


  METHOD request_delete.

    DATA(request_uuid) = CONV z2ui5_t_smps_req-request_uuid( client->get_event_arg( ) ).

    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        DELETE FROM VALUE #( ( requestuuid = request_uuid ) )
      FAILED DATA(s_failed).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_failed ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->message_toast_display( `Request deleted` ).
    ENDIF.

  ENDMETHOD.


  METHOD data_save.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_req
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed IS INITIAL.
      result = abap_true.
    ELSE.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
    ENDIF.

    " the list shows what was saved - and the permissions that follow from it
    data_read( ).

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
            )->a( n = `title`          v = `abap2UI5 - RAP Actions - 17 Feature Control with GET PERMISSIONS`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `The buttons of each row follow GET PERMISSIONS: a New request may be approved, rejected and ` &&
                                 `deleted, a decided one may not, and an approved one stays for good. Switch on Ignore ` &&
                                 `permissions and try anyway - the business object refuses it on its own.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    " the expression binding decides per row: the permission, or - with the
    " switch on - always true
    DATA(enabled) = COND string( WHEN ignore_permissions = abap_true THEN `true` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_requests )
        )->a( n = `noDataText` v = `No requests yet - press Reset Demo Data` ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Requests (Z2UI5_R_SMPS_REQ)`
            )->tag( `ToolbarSpacer`
            )->tag( `Label`
                )->a( n = `text` v = `Ignore permissions`
            )->tag( `Switch`
                )->a( n = `state`  v = client->_bind( ignore_permissions )
                )->a( n = `change` v = client->_event( `IGNORE` )
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `GENERATE` )
                )->a( n = `text`    v = `Reset Demo Data`
                )->a( n = `tooltip` v = `Deletes every request the business object lets go of, then creates three new ones`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REFRESH` )
                )->a( n = `icon`    v = `sap-icon://refresh`
                )->a( n = `tooltip` v = `Refresh` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Title`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Quantity`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Note`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Actions` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TITLE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{QUANTITY}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{STATUS}`
                    )->a( n = `state` v = `{= ${STATUS_STATE} || 'None' }`
                )->tag( `Text`
                    )->a( n = `text` v = `{NOTE}`
                )->ele( `HBox`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `APPROVE` arg = `${REQUEST_UUID}` )
                        )->a( n = `icon`    v = `sap-icon://accept`
                        )->a( n = `tooltip` v = `Approve`
                        )->a( n = `enabled` v = COND #( WHEN enabled IS INITIAL THEN `{APPROVE_ENABLED}` ELSE enabled )
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `REJECT` arg = `${REQUEST_UUID}` )
                        )->a( n = `icon`    v = `sap-icon://decline`
                        )->a( n = `tooltip` v = `Reject`
                        )->a( n = `enabled` v = COND #( WHEN enabled IS INITIAL THEN `{REJECT_ENABLED}` ELSE enabled )
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `DELETE` arg = `${REQUEST_UUID}` )
                        )->a( n = `icon`    v = `sap-icon://delete`
                        )->a( n = `tooltip` v = `Delete`
                        )->a( n = `enabled` v = COND #( WHEN enabled IS INITIAL THEN `{DELETE_ENABLED}` ELSE enabled ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
