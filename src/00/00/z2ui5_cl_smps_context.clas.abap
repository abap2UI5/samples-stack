"! <p class="shorttext synchronized">abap2UI5 EML sample - shared context</p>
"! Everything the sample apps of this repository do more than once.
"!
"! Built after the abap-util concept: one class, only CLASS-METHODS, `val`
"! in and `result` out, and the constants that belong to the same subject
"! sitting next to the methods that use them.
"!
"! Deliberately small in what it *offers*. A sample is read, not reused, so
"! anything that is clearer written out in the app itself stays in the app -
"! the local ty_s_travel structures for instance, which every app declares
"! with just the fields it actually shows.
"!
"! The private half is larger than that, and on purpose: the RAP message
"! reader and the app-URL helper used to come from z2ui5_cl_util, which sits
"! in abap2UI5's frozen src/99 and exists only so old installations keep
"! compiling - the framework says to add no new consumers on it. They are
"! copied in here instead, verbatim from the maintained copies in
"! abap2UI5/samples, so the two repositories keep answering alike.
CLASS z2ui5_cl_smps_context DEFINITION PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.

    CONSTANTS:
      "! The overall status as the business object stores it - see the
      "! determination setInitialValues and the actions acceptTravel and
      "! rejectTravel in the behavior pools.
      BEGIN OF cs_status,
        open     TYPE string VALUE `O` ##NO_TEXT,
        accepted TYPE string VALUE `A` ##NO_TEXT,
        rejected TYPE string VALUE `X` ##NO_TEXT,
      END OF cs_status.

    CONSTANTS:
      "! The sap.m.MessageType / sap.m.ValueState names, so a message box and
      "! an ObjectStatus in this repository always agree on a state.
      BEGIN OF cs_ui5_msg_type,
        e TYPE string VALUE `Error` ##NO_TEXT,
        s TYPE string VALUE `Success` ##NO_TEXT,
        w TYPE string VALUE `Warning` ##NO_TEXT,
        i TYPE string VALUE `Information` ##NO_TEXT,
      END OF cs_ui5_msg_type.

    TYPES:
      BEGIN OF ty_s_name_value,
        n TYPE string,
        v TYPE string,
      END OF ty_s_name_value.
    TYPES ty_t_name_value TYPE STANDARD TABLE OF ty_s_name_value WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_msg,
        text       TYPE string,
        id         TYPE string,
        no         TYPE string,
        type       TYPE string,
        v1         TYPE string,
        v2         TYPE string,
        v3         TYPE string,
        v4         TYPE string,
        timestampl TYPE timestampl,
        t_meta     TYPE ty_t_name_value,
      END OF ty_s_msg,
      ty_t_msg TYPE STANDARD TABLE OF ty_s_msg WITH EMPTY KEY.

    CLASS-DATA cv_char_util_newline        TYPE c LENGTH 1 READ-ONLY.
    CLASS-DATA cv_char_util_horizontal_tab TYPE c LENGTH 1 READ-ONLY.

    CLASS-METHODS class_constructor.

    "! Collects the messages of a RAP response and shows them in a message box.
    "!
    "! @parameter client | the app's client
    "! @parameter val    | a REPORTED response, one of its entity tables, or a FAILED response
    CLASS-METHODS msg_display
      IMPORTING
        client TYPE REF TO z2ui5_if_client
        val    TYPE any.

    "! Translates the stored status into something readable.
    "! @parameter val | OverallStatus as stored, see cs_status
    CLASS-METHODS status_get_text
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    "! The matching sap.m.ObjectStatus state, so the list colours agree
    "! with the text across all apps.
    "! @parameter val | OverallStatus as stored, see cs_status
    CLASS-METHODS status_get_state
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS app_get_url
      IMPORTING
        classname     TYPE clike
        origin        TYPE clike
        pathname      TYPE clike
        search        TYPE clike
        hash          TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_s_attri_cache,
        absolute_name TYPE string,
        o_struct      TYPE REF TO cl_abap_structdescr,
        t_attri       TYPE cl_abap_structdescr=>component_table,
      END OF ty_s_attri_cache.

    CLASS-DATA mt_attri_cache TYPE HASHED TABLE OF ty_s_attri_cache WITH UNIQUE KEY absolute_name.

    "! Reads a RAP response into the message rows behind msg_display.
    CLASS-METHODS msg_get_collect
      IMPORTING
        val           TYPE any
        val2          TYPE any OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS c_trim
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS c_trim_lower
      IMPORTING
        val           TYPE clike
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS check_is_rap_struct
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS msg_get_by_oref
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE ty_t_msg.

    CLASS-METHODS msg_get_internal
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE ty_t_msg.

    CLASS-METHODS msg_get_rap
      IMPORTING
        val           TYPE any
        entity_name   TYPE string OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_msg.

    CLASS-METHODS msg_get_rap_action
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_rap_cid
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_rap_element
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_rap_fail_text
      IMPORTING
        cause         TYPE i
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_rap_flatten
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_rap_meta
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE ty_t_name_value.

    CLASS-METHODS msg_get_rap_pid
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_rap_row
      IMPORTING
        val         TYPE any
        entity_name TYPE string OPTIONAL
      EXPORTING
        messages    TYPE ty_t_msg
        is_row      TYPE abap_bool.

    CLASS-METHODS msg_get_rap_state_area
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_rap_tky
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS msg_get_t
      IMPORTING
        val           TYPE any
        val2          TYPE any OPTIONAL
      RETURNING
        VALUE(result) TYPE ty_t_msg.

    CLASS-METHODS msg_map
      IMPORTING
        name          TYPE clike
        val           TYPE data
        is_msg        TYPE ty_s_msg
      RETURNING
        VALUE(result) TYPE ty_s_msg.

    CLASS-METHODS rtti_check_clike
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

    CLASS-METHODS rtti_get_t_attri_by_any
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE cl_abap_structdescr=>component_table.

    CLASS-METHODS rtti_get_t_attri_by_include
      IMPORTING
        type          TYPE REF TO cl_abap_datadescr
      RETURNING
        VALUE(result) TYPE abap_component_tab.

    CLASS-METHODS rtti_get_t_attri_by_oref
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE abap_attrdescr_tab.

    CLASS-METHODS rtti_get_type_kind
      IMPORTING
        val           TYPE any
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS url_param_create_url
      IMPORTING
        t_params      TYPE ty_t_name_value
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS url_param_get_tab
      IMPORTING
        i_val            TYPE clike
      RETURNING
        VALUE(rt_params) TYPE ty_t_name_value.

ENDCLASS.


CLASS z2ui5_cl_smps_context IMPLEMENTATION.

  METHOD class_constructor.

    cv_char_util_newline        = cl_abap_char_utilities=>newline.
    cv_char_util_horizontal_tab = cl_abap_char_utilities=>horizontal_tab.

  ENDMETHOD.


  METHOD msg_display.

    DATA(text) = msg_get_collect( val ).

    " a business object may reject an operation without raising a message -
    " saying so beats an empty popup
    IF text IS INITIAL.
      text = `The operation failed, no further details available`.
    ENDIF.

    client->message_box_display( text = text type = cs_ui5_msg_type-e ).

  ENDMETHOD.


  METHOD msg_get_collect.

    result = concat_lines_of(
      table = VALUE string_table( FOR <r> IN msg_get_t( val = val val2 = val2 ) ( |- { <r>-text }| ) )
      sep   = cv_char_util_newline ).

  ENDMETHOD.


  METHOD status_get_text.

    result = SWITCH #( val
                       WHEN cs_status-open     THEN `Open`
                       WHEN cs_status-accepted THEN `Accepted`
                       WHEN cs_status-rejected THEN `Rejected`
                       ELSE `` ).

  ENDMETHOD.


  METHOD status_get_state.

    result = SWITCH #( val
                       WHEN cs_status-open     THEN cs_ui5_msg_type-i
                       WHEN cs_status-accepted THEN cs_ui5_msg_type-s
                       WHEN cs_status-rejected THEN cs_ui5_msg_type-e
                       ELSE `None` ).

  ENDMETHOD.


  METHOD app_get_url.

    DATA(lt_param) = url_param_get_tab( search ).
    DELETE lt_param WHERE n = `app_start`.
    INSERT VALUE #( n = `app_start` v = to_lower( classname ) ) INTO TABLE lt_param.

    " keep only the launchpad shell part of the hash: the app-owned part
    " (leading `/` standalone, or everything after `&/` inside the FLP)
    " carries THIS app's route/app-state, which the backend prefers over
    " app_start - appending it verbatim would re-open the current app
    " instead of the requested one
    DATA(lv_hash) = CONV string( hash ).
    IF lv_hash IS NOT INITIAL.
      DATA(lv_content) = lv_hash.
      IF lv_content(1) = `#`.
        lv_content = substring( val = lv_content off = 1 ).
      ENDIF.
      IF lv_content IS INITIAL OR lv_content(1) = `/`.
        " pure app hash (route or app-state) - drop it entirely
        lv_hash = ``.
      ELSE.
        " inside the FLP keep the shell part, cut the app part after `&/`
        DATA(lv_off) = find( val = lv_content sub = `&/` ).
        IF lv_off = 0.
          lv_hash = ``.
        ELSEIF lv_off > 0.
          lv_hash = |#{ lv_content(lv_off) }|.
        ELSE.
          lv_hash = |#{ lv_content }|.
        ENDIF.
      ENDIF.
    ENDIF.

    result = |{ origin }{ pathname }?| && url_param_create_url( lt_param ) && lv_hash.

  ENDMETHOD.

  METHOD c_trim.

    result = shift_left( shift_right( CONV string( val ) ) ).
    result = shift_right( val = result sub = cv_char_util_horizontal_tab ).
    result = shift_left( val = result sub = cv_char_util_horizontal_tab ).
    result = shift_left( shift_right( result ) ).

  ENDMETHOD.

  METHOD c_trim_lower.

    result = to_lower( c_trim( CONV string( val ) ) ).

  ENDMETHOD.

  METHOD check_is_rap_struct.

    DATA(lt_attri) = rtti_get_t_attri_by_any( val ).

    LOOP AT lt_attri REFERENCE INTO DATA(ls_attri).
      CASE ls_attri->name.
        WHEN `%MSG` OR `%FAIL` OR `%OTHER`.
          result = abap_true.
          RETURN.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_attri REFERENCE INTO ls_attri.
      ASSIGN COMPONENT ls_attri->name OF STRUCTURE val TO FIELD-SYMBOL(<tab>).
      CHECK sy-subrc = 0.
      CHECK rtti_get_type_kind( <tab> ) = cl_abap_datadescr=>typekind_table.

      TRY.
          DATA(lo_tab) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( <tab> ) ).
          DATA(lo_line) = lo_tab->get_table_line_type( ).
          CHECK lo_line->kind = cl_abap_typedescr=>kind_struct.
          DATA(lt_comps) = CAST cl_abap_structdescr( lo_line )->get_components( ).
          LOOP AT lt_comps REFERENCE INTO DATA(ls_comp).
            IF ls_comp->name = `%MSG` OR ls_comp->name = `%FAIL`.
              result = abap_true.
              RETURN.
            ENDIF.
          ENDLOOP.
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.

  METHOD msg_get_by_oref.

    DATA obj    TYPE REF TO object.
    DATA lr_tab TYPE REF TO data.

    FIELD-SYMBOLS <comp> TYPE any.

    TRY.
        DATA(lx) = CAST cx_root( val ).
        DATA(ls_result) = VALUE ty_s_msg( type = `E` text = lx->get_text( ) ).
        DATA(lt_attri_o) = rtti_get_t_attri_by_oref( val ).
        LOOP AT lt_attri_o REFERENCE INTO DATA(ls_attri_o) WHERE visibility = `U`.
          DATA(lv_name) = ls_attri_o->name.
          ASSIGN val->(lv_name) TO <comp>.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.
          ls_result = msg_map( name = ls_attri_o->name val = <comp> is_msg = ls_result ).
        ENDLOOP.
        INSERT ls_result INTO TABLE result.
      CATCH cx_root.

        obj = val.

        TRY.

            CREATE DATA lr_tab TYPE (`if_bali_log=>ty_item_table`).
            ASSIGN lr_tab->* TO FIELD-SYMBOL(<tab2>).

            CALL METHOD obj->(`IF_BALI_LOG~GET_ALL_ITEMS`)
              RECEIVING
                item_table = <tab2>.

            DATA(lt_tab2) = msg_get_internal( <tab2> ).
            INSERT LINES OF lt_tab2 INTO TABLE result.

          CATCH cx_root.

            TRY.

                CREATE DATA lr_tab TYPE (`BAPIRETTAB`).
                ASSIGN lr_tab->* TO <tab2>.

                CALL METHOD obj->(`ZIF_LOGGER~EXPORT_TO_TABLE`)
                  RECEIVING
                    rt_bapiret = <tab2>.

                lt_tab2 = msg_get_internal( <tab2> ).
                INSERT LINES OF lt_tab2 INTO TABLE result.

              CATCH cx_root.

                lt_attri_o = rtti_get_t_attri_by_oref( val ).
                LOOP AT lt_attri_o REFERENCE INTO ls_attri_o
                     WHERE visibility = `U`.
                  lv_name = ls_attri_o->name.
                  ASSIGN obj->(lv_name) TO <comp>.
                  IF sy-subrc <> 0.
                    CONTINUE.
                  ENDIF.
                  ls_result = msg_map( name = ls_attri_o->name val = <comp> is_msg = ls_result ).
                ENDLOOP.
                INSERT ls_result INTO TABLE result.

            ENDTRY.
        ENDTRY.
    ENDTRY.

  ENDMETHOD.

  METHOD msg_get_internal.

    FIELD-SYMBOLS <tab> TYPE ANY TABLE.

    DATA(lv_kind) = rtti_get_type_kind( val ).
    CASE lv_kind.

      WHEN cl_abap_datadescr=>typekind_table.
        ASSIGN val TO <tab>.
        LOOP AT <tab> ASSIGNING FIELD-SYMBOL(<row>).
          DATA(lt_tab) = msg_get_internal( <row> ).
          INSERT LINES OF lt_tab INTO TABLE result.
        ENDLOOP.

      WHEN cl_abap_datadescr=>typekind_struct1 OR cl_abap_datadescr=>typekind_struct2.

        IF val IS INITIAL.
          RETURN.
        ENDIF.

        IF check_is_rap_struct( val ) = abap_true.
          result = msg_get_rap( val ).
          RETURN.
        ENDIF.

        DATA(lt_attri) = rtti_get_t_attri_by_any( val ).

        DATA(ls_result) = VALUE ty_s_msg( ).
        LOOP AT lt_attri REFERENCE INTO DATA(ls_attri).
          ASSIGN COMPONENT ls_attri->name OF STRUCTURE val TO FIELD-SYMBOL(<comp>).
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.

          IF ls_attri->name = `ITEM`.
            lt_tab = msg_get_internal( <comp> ).
            INSERT LINES OF lt_tab INTO TABLE result.
            RETURN.
          ELSE.
            ls_result = msg_map( name = ls_attri->name val = <comp> is_msg = ls_result ).
          ENDIF.

        ENDLOOP.
        IF ls_result-text IS INITIAL AND ls_result-id IS NOT INITIAL.
          ls_result-id = to_upper( ls_result-id ).
          MESSAGE ID ls_result-id TYPE `I` NUMBER ls_result-no
                  WITH ls_result-v1 ls_result-v2 ls_result-v3 ls_result-v4
                  INTO ls_result-text.
        ENDIF.
        INSERT ls_result INTO TABLE result.

      WHEN cl_abap_datadescr=>typekind_oref.
        result = msg_get_by_oref( val ).

      WHEN OTHERS.

        IF rtti_check_clike( val ).
          INSERT VALUE #( text = val ) INTO TABLE result.
        ENDIF.
    ENDCASE.

  ENDMETHOD.

  METHOD msg_get_rap.

    FIELD-SYMBOLS <ftab> TYPE ANY TABLE.

    DATA(lv_kind) = rtti_get_type_kind( val ).
    IF lv_kind <> cl_abap_datadescr=>typekind_struct1
       AND lv_kind <> cl_abap_datadescr=>typekind_struct2.
      RETURN.
    ENDIF.

    msg_get_rap_row( EXPORTING val         = val
                               entity_name = entity_name
                     IMPORTING messages    = result
                               is_row      = DATA(lv_is_row) ).
    IF lv_is_row = abap_true.
      RETURN.
    ENDIF.

    DATA(lt_attri) = rtti_get_t_attri_by_any( val ).
    LOOP AT lt_attri REFERENCE INTO DATA(ls_attri).
      ASSIGN COMPONENT ls_attri->name OF STRUCTURE val TO FIELD-SYMBOL(<tab>).
      CHECK sy-subrc = 0.
      CHECK rtti_get_type_kind( <tab> ) = cl_abap_datadescr=>typekind_table.

      ASSIGN <tab> TO <ftab>.

      LOOP AT <ftab> ASSIGNING FIELD-SYMBOL(<row>).
        IF rtti_get_type_kind( <row> ) = cl_abap_datadescr=>typekind_oref.
          IF <row> IS NOT INITIAL.
            TRY.
                INSERT LINES OF msg_get_t( <row> ) INTO TABLE result.
              CATCH cx_root ##NO_HANDLER.
            ENDTRY.
          ENDIF.
        ELSE.
          INSERT LINES OF msg_get_rap( val = <row> entity_name = ls_attri->name ) INTO TABLE result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD msg_get_rap_action.

    DATA(lt_attri) = rtti_get_t_attri_by_any( val ).
    LOOP AT lt_attri REFERENCE INTO DATA(ls_attri).
      CHECK strlen( ls_attri->name ) > 12.
      CHECK ls_attri->name(12) = `%OP-%ACTION-`.
      ASSIGN COMPONENT ls_attri->name OF STRUCTURE val TO FIELD-SYMBOL(<flag>).
      CHECK sy-subrc = 0.
      CHECK <flag> IS NOT INITIAL.
      result = ls_attri->name+12.
      RETURN.
    ENDLOOP.

  ENDMETHOD.

  METHOD msg_get_rap_cid.

    ASSIGN COMPONENT `%CID` OF STRUCTURE val TO FIELD-SYMBOL(<cid>).
    IF sy-subrc = 0.
      result = <cid>.
    ENDIF.

  ENDMETHOD.

  METHOD msg_get_rap_element.

    DATA(lt_attri) = rtti_get_t_attri_by_any( val ).
    LOOP AT lt_attri REFERENCE INTO DATA(ls_attri).
      CHECK strlen( ls_attri->name ) > 9.
      CHECK ls_attri->name(9) = `%ELEMENT-`.
      ASSIGN COMPONENT ls_attri->name OF STRUCTURE val TO FIELD-SYMBOL(<flag>).
      CHECK sy-subrc = 0.
      CHECK <flag> IS NOT INITIAL.

      IF result IS INITIAL.
        result = ls_attri->name+9.
      ELSE.
        result = |{ result }, { ls_attri->name+9 }|.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD msg_get_rap_fail_text.

    result = SWITCH string( cause
      WHEN 0  THEN `Operation failed`
      WHEN 1  THEN `Entity not found`
      WHEN 2  THEN `Entity is locked`
      WHEN 3  THEN `Authorization failure`
      WHEN 4  THEN `Concurrent modification`
      WHEN 5  THEN `Concurrent modification`
      WHEN 6  THEN `Operation disabled`
      WHEN 7  THEN `Operation forbidden`
      WHEN 8  THEN `Semantic error`
      WHEN 9  THEN `Determination failed`
      WHEN 10 THEN `Permission denied`
      WHEN 11 THEN `Validation failed`
      ELSE         |Operation failed (cause code { cause })| ).

  ENDMETHOD.

  METHOD msg_get_rap_flatten.

    DATA lv_str TYPE string.

    DATA(lv_kind) = rtti_get_type_kind( val ).
    IF lv_kind <> cl_abap_datadescr=>typekind_struct1
       AND lv_kind <> cl_abap_datadescr=>typekind_struct2.
      RETURN.
    ENDIF.

    DATA(lt_attri) = rtti_get_t_attri_by_any( val ).
    LOOP AT lt_attri REFERENCE INTO DATA(ls_attri).
      ASSIGN COMPONENT ls_attri->name OF STRUCTURE val TO FIELD-SYMBOL(<comp>).
      CHECK sy-subrc = 0.

      DATA(lv_sub_kind) = rtti_get_type_kind( <comp> ).
      IF lv_sub_kind = cl_abap_datadescr=>typekind_struct1
         OR lv_sub_kind = cl_abap_datadescr=>typekind_struct2.
        DATA(lv_sub) = msg_get_rap_flatten( <comp> ).
        IF lv_sub IS NOT INITIAL.
          IF result IS NOT INITIAL.
            result = |{ result }, |.
          ENDIF.
          result = |{ result }{ lv_sub }|.
        ENDIF.
      ELSEIF <comp> IS NOT INITIAL.
        TRY.
            lv_str = <comp>.
            IF result IS NOT INITIAL.
              result = |{ result }, |.
            ENDIF.
            result = |{ result }{ ls_attri->name }={ lv_str }|.
          CATCH cx_root ##NO_HANDLER.
        ENDTRY.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD msg_get_rap_meta.

    DATA lv TYPE string.

    lv = msg_get_rap_element( val ).
    IF lv IS NOT INITIAL.
      INSERT VALUE #( n = `element` v = lv ) INTO TABLE result.
    ENDIF.

    lv = msg_get_rap_state_area( val ).
    IF lv IS NOT INITIAL.
      INSERT VALUE #( n = `state_area` v = lv ) INTO TABLE result.
    ENDIF.

    lv = msg_get_rap_action( val ).
    IF lv IS NOT INITIAL.
      INSERT VALUE #( n = `action` v = lv ) INTO TABLE result.
    ENDIF.

    lv = msg_get_rap_pid( val ).
    IF lv IS NOT INITIAL.
      INSERT VALUE #( n = `pid` v = lv ) INTO TABLE result.
    ENDIF.

    lv = msg_get_rap_cid( val ).
    IF lv IS NOT INITIAL.
      INSERT VALUE #( n = `cid` v = lv ) INTO TABLE result.
    ENDIF.

    lv = msg_get_rap_tky( val ).
    IF lv IS NOT INITIAL.
      INSERT VALUE #( n = `tky` v = lv ) INTO TABLE result.
    ENDIF.

  ENDMETHOD.

  METHOD msg_get_rap_pid.

    ASSIGN COMPONENT `%PID` OF STRUCTURE val TO FIELD-SYMBOL(<pid>).
    IF sy-subrc = 0.
      result = <pid>.
    ENDIF.

  ENDMETHOD.

  METHOD msg_get_rap_row.

    DATA lv_cause TYPE i.

    CLEAR messages.
    is_row = abap_false.

    DATA(lt_meta) = msg_get_rap_meta( val ).

    ASSIGN COMPONENT `%MSG` OF STRUCTURE val TO FIELD-SYMBOL(<msg>).
    IF sy-subrc = 0.
      is_row = abap_true.
      IF <msg> IS NOT INITIAL.
        TRY.
            DATA(lt_one) = msg_get_t( <msg> ).
            LOOP AT lt_one ASSIGNING FIELD-SYMBOL(<m>).
              <m>-t_meta = lt_meta.
            ENDLOOP.
            INSERT LINES OF lt_one INTO TABLE messages.
          CATCH cx_root ##NO_HANDLER.
        ENDTRY.
      ENDIF.
    ENDIF.

    ASSIGN COMPONENT `%FAIL` OF STRUCTURE val TO FIELD-SYMBOL(<fail>).
    IF sy-subrc = 0.
      is_row = abap_true.
      ASSIGN COMPONENT `CAUSE` OF STRUCTURE <fail> TO FIELD-SYMBOL(<cause>).
      IF sy-subrc = 0.
        lv_cause = <cause>.
        DATA(lv_text) = msg_get_rap_fail_text( lv_cause ).
        IF entity_name IS NOT INITIAL.
          lv_text = |{ entity_name }: { lv_text }|.
        ENDIF.
        INSERT VALUE #( type = `E` text = lv_text t_meta = lt_meta ) INTO TABLE messages.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD msg_get_rap_state_area.

    ASSIGN COMPONENT `%STATE_AREA` OF STRUCTURE val TO FIELD-SYMBOL(<sa>).
    IF sy-subrc = 0.
      result = <sa>.
    ENDIF.

  ENDMETHOD.

  METHOD msg_get_rap_tky.

    ASSIGN COMPONENT `%TKY` OF STRUCTURE val TO FIELD-SYMBOL(<tky>).
    IF sy-subrc <> 0 OR <tky> IS INITIAL.
      RETURN.
    ENDIF.
    result = msg_get_rap_flatten( <tky> ).

  ENDMETHOD.

  METHOD msg_get_t.

    result = msg_get_internal( val ).
    IF result IS INITIAL AND val2 IS NOT INITIAL.
      result = msg_get_internal( val2 ).
    ENDIF.

  ENDMETHOD.

  METHOD msg_map.

    result = is_msg.
    CASE name.
      WHEN `ID` OR `MSGID`.
        result-id = val.
      WHEN `NO` OR `NUMBER` OR `MSGNO`.
        result-no = val.
      WHEN `MESSAGE` OR `TEXT`.
        result-text = val.
      WHEN `TYPE` OR `MSGTY` OR `M_SEVERITY`.
        result-type = val.
      WHEN `MESSAGE_V1` OR `MSGV1` OR `V1`.
        result-v1 = val.
      WHEN `MESSAGE_V2` OR `MSGV2` OR `V2`.
        result-v2 = val.
      WHEN `MESSAGE_V3` OR `MSGV3` OR `V3`.
        result-v3 = val.
      WHEN `MESSAGE_V4` OR `MSGV4` OR `V4`.
        result-v4 = val.
      WHEN `TIME_STMP`.
        result-timestampl = val.
    ENDCASE.

  ENDMETHOD.

  METHOD rtti_check_clike.

    DATA(lv_type) = rtti_get_type_kind( val ).
    CASE lv_type.
      WHEN cl_abap_datadescr=>typekind_char OR
          cl_abap_datadescr=>typekind_clike OR
          cl_abap_datadescr=>typekind_csequence OR
          cl_abap_datadescr=>typekind_string.
        result = abap_true.
    ENDCASE.

  ENDMETHOD.

  METHOD rtti_get_t_attri_by_any.

    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lo_type   TYPE REF TO cl_abap_typedescr.

    TRY.
        lo_type = cl_abap_typedescr=>describe_by_data( val ).
        IF lo_type->kind = cl_abap_typedescr=>kind_ref.
          lo_type = cl_abap_typedescr=>describe_by_data_ref( val ).
        ENDIF.
      CATCH cx_root.
        TRY.
            lo_type = cl_abap_typedescr=>describe_by_data_ref( val ).
          CATCH cx_root.
            lo_type = cl_abap_structdescr=>describe_by_name( val ).
        ENDTRY.
    ENDTRY.

    CASE lo_type->kind.
      WHEN cl_abap_typedescr=>kind_struct.
        lo_struct = CAST #( lo_type ).
      WHEN cl_abap_typedescr=>kind_table.
        lo_struct = CAST #( CAST cl_abap_tabledescr( lo_type )->get_table_line_type( ) ).
      WHEN OTHERS.
        lo_struct ?= lo_type.
    ENDCASE.

    " descriptor instances are singletons per type, so the identity check
    " guards against absolute names reused by other (local/anonymous) types
    DATA(lv_absolute_name) = CONV string( lo_struct->absolute_name ).
    READ TABLE mt_attri_cache REFERENCE INTO DATA(lr_cache) WITH TABLE KEY absolute_name = lv_absolute_name.
    IF sy-subrc = 0 AND lr_cache->o_struct = lo_struct.
      result = lr_cache->t_attri.
      RETURN.
    ENDIF.

    DATA(comps) = lo_struct->get_components( ).

    LOOP AT comps REFERENCE INTO DATA(lr_comp).

      IF lr_comp->as_include = abap_false.
        APPEND lr_comp->* TO result.
      ELSE.
        DATA(lt_attri) = rtti_get_t_attri_by_include( lr_comp->type ).
        APPEND LINES OF lt_attri TO result.
      ENDIF.
    ENDLOOP.

    IF lr_cache IS BOUND.
      lr_cache->o_struct = lo_struct.
      lr_cache->t_attri  = result.
    ELSE.
      INSERT VALUE #( absolute_name = lv_absolute_name
                      o_struct      = lo_struct
                      t_attri       = result ) INTO TABLE mt_attri_cache.
    ENDIF.

  ENDMETHOD.

  METHOD rtti_get_t_attri_by_include.

    TRY.

        cl_abap_typedescr=>describe_by_name( EXPORTING  p_name         = type->absolute_name
                                             RECEIVING  p_descr_ref    = DATA(type_desc)
                                             EXCEPTIONS type_not_found = 1 ).

      CATCH cx_root.
        " the one deliberate difference to the abap2UI5/samples copy, which
        " raises its own z2ui5_cx_smp_error here: this repository has no
        " exception class, and importing one for a describe_by_name that
        " cannot fail - the type was just handed to us by RTTI - would pull
        " in a class and a UUID generator for an unreachable path. Both
        " callers APPEND the result, so contributing nothing is the same
        " outcome as never having been asked.
        RETURN.
    ENDTRY.
    DATA(sdescr) = CAST cl_abap_structdescr( type_desc ).
    DATA(comps) = sdescr->get_components( ).

    LOOP AT comps REFERENCE INTO DATA(lr_comp).

      IF lr_comp->as_include = abap_true.

        DATA(incl_comps) = rtti_get_t_attri_by_include( lr_comp->type ).

        LOOP AT incl_comps REFERENCE INTO DATA(lr_incl_comp).
          APPEND lr_incl_comp->* TO result.
        ENDLOOP.

      ELSE.

        APPEND lr_comp->* TO result.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD rtti_get_t_attri_by_oref.

    DATA(lo_obj_ref) = cl_abap_objectdescr=>describe_by_object_ref( val ).
    result = CAST cl_abap_classdescr( lo_obj_ref )->attributes.

  ENDMETHOD.

  METHOD rtti_get_type_kind.

    result = cl_abap_datadescr=>get_data_type_kind( val ).

  ENDMETHOD.

  METHOD url_param_create_url.

    LOOP AT t_params INTO DATA(ls_param).
      result = |{ result }{ ls_param-n }={ ls_param-v }&|.
    ENDLOOP.
    result = shift_right( val = result sub = `&` ).

  ENDMETHOD.

  METHOD url_param_get_tab.

    DATA(lv_search) = replace( val  = i_val
                               sub  = `%3D`
                               with = `=`
                               occ  = 0 ).

    " RFC 3986 allows lowercase hex digits in percent-encodings, so decode
    " %3d the same way as %3D (%26 contains no letters and needs no twin)
    lv_search = replace( val  = lv_search
                         sub  = `%3d`
                         with = `=`
                         occ  = 0 ).

    lv_search = replace( val  = lv_search
                         sub  = `%26`
                         with = `&`
                         occ  = 0 ).

    lv_search = shift_left( val = lv_search sub = `?` ).

    " prepend & before searching so sap-startup-params is also unwrapped
    " when it is the first/only query parameter (typical FLP target mapping)
    DATA(lv_search2) = substring_after( val = |&{ lv_search }| sub = `&sap-startup-params=` ).
    lv_search = COND #( WHEN lv_search2 IS NOT INITIAL THEN lv_search2 ELSE lv_search ).

    lv_search2 = substring_after( val = lv_search sub = `?` ).
    IF lv_search2 IS NOT INITIAL.
      lv_search = lv_search2.
    ENDIF.

    SPLIT lv_search AT `&` INTO TABLE DATA(lt_param).

    LOOP AT lt_param REFERENCE INTO DATA(lr_param).
      SPLIT lr_param->* AT `=` INTO DATA(lv_name) DATA(lv_value).
      " an empty segment (empty search string, trailing &) would otherwise
      " produce a phantom nameless parameter that url_param_create_url
      " writes back out as a stray `=&`
      IF lv_name IS INITIAL.
        CONTINUE.
      ENDIF.
      " normalize the name so lookups are case-insensitive on every input
      " shape (with or without a leading path/question mark) - the value
      " keeps its original case
      INSERT VALUE #( n = c_trim_lower( lv_name ) v = lv_value ) INTO TABLE rt_params.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
