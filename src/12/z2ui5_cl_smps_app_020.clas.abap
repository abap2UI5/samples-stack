" @keywords rap eml projection behavior definition contract cl_abap_behv_aux interface consumer approve
" @summary One business object, two contracts - approve through the projection Z2UI5_C_SMPS_REQ or on the business object itself, and the handler records which one it was
"! <p class="shorttext synchronized">RAP Actions - One Business Object, Two Contracts</p>
"! A projection is a second contract on the same business object. Its
"! behavior definition z2ui5_c_smps_req exposes a SUBSET of what
"! z2ui5_r_smps_req offers - update and approve, nothing else:
"!
"!     projection;
"!     define behavior for z2ui5_c_smps_req alias Request
"!     {
"!       use update;
"!       use action approve;
"!     }
"!
"! EML works against both. What the projection does not expose cannot even be
"! written: an EXECUTE reject on z2ui5_c_smps_req does not compile.
"!
"!     MODIFY ENTITIES OF z2ui5_c_smps_req
"!       ENTITY request
"!         EXECUTE approve FROM VALUE #( ( requestuuid = ... ) ) ...
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_req
"!       ENTITY request
"!         EXECUTE approve FROM VALUE #( ( requestuuid = ... ) ) ...
"!
"! Both end in the same handler. It asks cl_abap_behv_aux which contract it
"! was called through and stores the answer in ApprovedVia - the column of the
"! list below.
CLASS z2ui5_cl_smps_app_020 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_request,
        request_uuid TYPE string,
        title        TYPE string,
        status       TYPE string,
        approved_via TYPE string,
        is_new       TYPE abap_bool,
      END OF ty_s_request.
    TYPES ty_t_request TYPE STANDARD TABLE OF ty_s_request WITH EMPTY KEY.
    DATA t_requests TYPE ty_t_request.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_event.
    METHODS approve_via_projection.
    METHODS approve_via_business_object.
    METHODS data_save
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS data_read.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_020 IMPLEMENTATION.

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

      WHEN `APPROVE_C`.
        approve_via_projection( ).

      WHEN `APPROVE_R`.
        approve_via_business_object( ).

      WHEN `REFRESH`.
        data_read( ).

      WHEN `GENERATE`.
        client->message_toast_display( z2ui5_cl_smps_data_req=>data_reset( ) ).
        data_read( ).

    ENDCASE.

  ENDMETHOD.


  METHOD approve_via_projection.

    " the entity is the projection - this statement only compiles for what
    " z2ui5_c_smps_req exposes
    MODIFY ENTITIES OF z2ui5_c_smps_req
      ENTITY request
        EXECUTE approve FROM VALUE #( ( requestuuid = CONV #( client->get_event_arg( ) ) ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->message_toast_display( `Approved through the projection Z2UI5_C_SMPS_REQ` ).
    ENDIF.

  ENDMETHOD.


  METHOD approve_via_business_object.

    MODIFY ENTITIES OF z2ui5_r_smps_req
      ENTITY request
        EXECUTE approve FROM VALUE #( ( requestuuid = CONV #( client->get_event_arg( ) ) ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-request IS NOT INITIAL.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
      RETURN.
    ENDIF.

    IF data_save( ).
      client->message_toast_display( `Approved on the business object Z2UI5_R_SMPS_REQ` ).
    ENDIF.

  ENDMETHOD.


  METHOD data_save.

    " one save for both contracts - the transactional buffer belongs to the
    " business object, the projection only shapes the access to it
    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_req
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed IS INITIAL.
      result = abap_true.
      data_read( ).
    ELSE.
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-request ).
    ENDIF.

  ENDMETHOD.


  METHOD data_read.

    " read through the projection - it is a CDS view like any other
    SELECT FROM z2ui5_c_smps_req                        "#EC CI_NOWHERE
      FIELDS RequestUuid,
             Title,
             Status,
             ApprovedVia
      ORDER BY CreatedAt DESCENDING
      INTO TABLE @DATA(t_result) UP TO 50 ROWS.

    t_requests = VALUE #( FOR s_result IN t_result
        ( request_uuid = |{ s_result-requestuuid }|
          title        = |{ s_result-title }|
          status       = SWITCH #( s_result-status
                                   WHEN 'N' THEN `New`
                                   WHEN 'A' THEN `Approved`
                                   WHEN 'R' THEN `Rejected` )
          approved_via = |{ s_result-approvedvia }|
          is_new       = xsdbool( s_result-status = 'N' ) ) ).

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
            )->a( n = `title`          v = `abap2UI5 - RAP Actions - 20 One Business Object, Two Contracts`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Approve a New request through the projection Z2UI5_C_SMPS_REQ or on the business object ` &&
                                 `Z2UI5_R_SMPS_REQ - the same handler runs, asks cl_abap_behv_aux which contract called it ` &&
                                 `and writes the answer into Approved via.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_requests )
        )->a( n = `noDataText` v = `No requests yet - press Reset Demo Data` ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Requests (Z2UI5_C_SMPS_REQ)`
            )->tag( `ToolbarSpacer`
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
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Approved via`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Approve` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{TITLE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{STATUS}`
                )->tag( `Text`
                    )->a( n = `text` v = `{APPROVED_VIA}`
                )->ele( `HBox`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `APPROVE_C` arg = `${REQUEST_UUID}` )
                        )->a( n = `text`    v = `via projection`
                        )->a( n = `enabled` v = `{IS_NEW}`
                        )->a( n = `class`   v = `sapUiTinyMarginEnd`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `APPROVE_R` arg = `${REQUEST_UUID}` )
                        )->a( n = `text`    v = `on the business object`
                        )->a( n = `enabled` v = `{IS_NEW}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
