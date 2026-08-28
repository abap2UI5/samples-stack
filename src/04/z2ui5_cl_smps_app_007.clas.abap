" @keywords eml rap draft edit enter lock mode
" @summary Edit copies the active instance into a new draft, Resume picks up an existing one
"! <p class="shorttext synchronized">RAP with Draft - Enter Draft Mode</p>
"! Edit copies the active instance into a new draft, Resume picks up a draft
"! that already exists.
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_trd
"!       ENTITY travel
"!         EXECUTE Edit FROM VALUE #( ( %key-traveluuid = uuid ) )
"!       FAILED s_failed
"!       REPORTED s_reported.
"!
"! The table shows the description of the active instance and of the draft
"! side by side. That is what makes the two actions visible: Edit fills the
"! draft column, Resume leaves it exactly as it is - it only takes the lock
"! back. Without the second column a press on Resume looks like nothing
"! happened at all.
"!
"! Worth knowing: a draft action takes the key and nothing else. Which of the
"! two instances it addresses is part of the action - Edit always starts from
"! the active one, Resume from the draft - so there is no %is_draft here. And
"! Edit on an instance that already has a draft fails, which is why this sample
"! asks first (sample 06) and calls Resume instead.
CLASS z2ui5_cl_smps_app_007 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_travel,
        travel_uuid       TYPE string,
        travel_id         TYPE string,
        "! of the ACTIVE instance
        description       TYPE string,
        "! of the draft, empty while there is none - the column that makes
        "! Edit and Resume visible at all
        draft_description TYPE string,
        draft_text        TYPE string,
        has_draft         TYPE abap_bool,
      END OF ty_s_travel.
    DATA t_travels TYPE STANDARD TABLE OF ty_s_travel WITH EMPTY KEY.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS data_read.
    METHODS draft_open.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_007 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `OPEN` ).
      draft_open( ).
    ENDIF.

  ENDMETHOD.


  METHOD draft_open.

    DATA s_failed   TYPE RESPONSE FOR FAILED EARLY z2ui5_r_smps_trd.
    DATA s_reported TYPE RESPONSE FOR REPORTED EARLY z2ui5_r_smps_trd.

    DATA(uuid) = client->get_event_arg( 1 ).

    IF t_travels[ travel_uuid = uuid ]-has_draft = abap_false.

      " No draft yet. Edit copies the active instance into a new draft.
      " Only the key is passed: a draft action already knows which of the
      " two instances it works on - Edit always starts from the active one.
      MODIFY ENTITIES OF z2ui5_r_smps_trd
        ENTITY travel
          EXECUTE Edit FROM VALUE #( ( %key-traveluuid = uuid ) )
        FAILED s_failed
        REPORTED s_reported.

      DATA(text) = |Draft created - it starts as a copy, so both description | &&
                   |columns show the same text now|.

    ELSE.

      " A draft already exists - Edit would fail here. Resume reactivates
      " the existing draft instead, so the user continues exactly where the
      " last session ended. Again only the key: Resume addresses the draft
      " by definition.
      MODIFY ENTITIES OF z2ui5_r_smps_trd
        ENTITY travel
          EXECUTE Resume FROM VALUE #( ( %key-traveluuid = uuid ) )
        FAILED s_failed
        REPORTED s_reported.

      " Resume takes the lock back, it does not touch the data - so the
      " table looks exactly as before and the message has to say so, or the
      " press looks like nothing happened
      text = |Draft resumed - the lock is yours again. Resume changes no | &&
             |data, that is what sample 08 does|.

    ENDIF.

    IF s_failed-travel IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-travel ).
      RETURN.

    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trd
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.

      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported_commit-travel ).
      RETURN.

    ENDIF.

    data_read( ).
    client->message_toast_display( text ).

  ENDMETHOD.


  METHOD data_read.

    SELECT FROM z2ui5_r_smps_trd
      FIELDS TravelUuid,
             TravelId,
             Description
      ORDER BY TravelId
      INTO TABLE @DATA(t_result) UP TO 20 ROWS.

    " see z2ui5_cl_smps_app_006 for what this read does - the description is
    " read along so the table can show the draft next to the active instance
    READ ENTITIES OF z2ui5_r_smps_trd
      ENTITY travel
        FIELDS ( travelid description ) WITH VALUE #( FOR s_row IN t_result
                                                      ( %tky = VALUE #( traveluuid = s_row-traveluuid
                                                                        %is_draft  = if_abap_behv=>mk-on ) ) )
      RESULT DATA(t_drafts).

    t_travels = VALUE #( FOR s_result IN t_result
        ( travel_uuid       = |{ s_result-traveluuid }|
          travel_id         = |{ s_result-travelid ALPHA = OUT }|
          description       = |{ s_result-description }|
          has_draft         = xsdbool( line_exists( t_drafts[ KEY entity traveluuid = s_result-traveluuid ] ) )
          draft_description = COND #( WHEN line_exists( t_drafts[ KEY entity traveluuid = s_result-traveluuid ] )
                                      THEN |{ t_drafts[ KEY entity traveluuid = s_result-traveluuid ]-description }| )
          draft_text        = COND #( WHEN line_exists( t_drafts[ KEY entity traveluuid = s_result-traveluuid ] )
                                      THEN `Resume` ELSE `Edit` ) ) ).

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
            )->a( n = `title`          v = `abap2UI5 - EML - 07 Enter Draft Mode`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
            )->ele( `Table`
                )->a( n = `items` v = client->_bind( t_travels ) ).

    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `EXECUTE Edit  /  EXECUTE Resume` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `ID`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description - active`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description - draft`
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
                    )->a( n = `text` v = `{DESCRIPTION}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DRAFT_DESCRIPTION}`
                )->tag( `Button`
                    )->a( n = `press` v = client->_event( val   = `OPEN`
                                            t_arg = VALUE #( ( `${TRAVEL_UUID}` ) ) )
                    )->a( n = `text`  v = `{DRAFT_TEXT}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
