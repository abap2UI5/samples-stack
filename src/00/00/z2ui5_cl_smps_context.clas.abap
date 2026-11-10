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
"! Messages are not here: a RAP response goes to the framework as it is -
"! client-&gt;message_box_display( text = s_reported-travel type = `error` ) -
"! which reads REPORTED and FAILED itself and shows a standard text when an
"! error came back without one (abap2UI5 z2ui5_cl_ui5_srv_message). The copy
"! of the RAP message reader this class carried for that is gone.
"!
"! The app-URL helper used to come from z2ui5_cl_util, which sits in
"! abap2UI5's frozen src/99 and exists only so old installations keep
"! compiling - the framework says to add no new consumers on it. It is
"! copied in here instead.
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
      "! The sap.m.ValueState names, so every ObjectStatus in this
      "! repository agrees on a state.
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

    CLASS-DATA cv_char_util_horizontal_tab TYPE c LENGTH 1 READ-ONLY.

    CLASS-METHODS class_constructor.

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

    cv_char_util_horizontal_tab = cl_abap_char_utilities=>horizontal_tab.

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

  METHOD url_param_create_url.

    LOOP AT t_params INTO DATA(ls_param).
      result = |{ result }{ ls_param-n }={ ls_param-v }&|.
    ENDLOOP.
    result = shift_right( val = result sub = `&` ).

  ENDMETHOD.

  METHOD url_param_get_tab.

    " a full URL or a request URI carries a path before its query: cut at
    " the FIRST `?` only. A later `?` is a legal, unencoded character of a
    " value (`title=why?`) - cutting there dropped every parameter before it
    " declared, not inline: DATA( ) from a generic CLIKE parameter is "fixed
    " type STRING used for generic type CLIKE" in the extended check
    DATA lv_search TYPE string.
    lv_search = i_val.
    IF lv_search CS `?`.
      lv_search = substring_after( val = lv_search sub = `?` ).
    ENDIF.

    " The FLP packs the target's own parameters into ONE value,
    " sap-startup-params, with its `=` and `&` percent-encoded. Prepend &
    " before searching so it is also unwrapped when it is the first/only
    " query parameter (typical FLP target mapping). Only THAT value is
    " decoded: decoding the whole query first tore every legitimately encoded
    " `&` or `=` in any other value apart (`a=x%26y` became a=x and y=), and
    " what stands BEFORE the wrapper - sap-client, sap-language - is kept:
    " it used to be dropped from every link built from this table
    " (abap2UI5's z2ui5_cl_ui5_util_context carries the same fix)
    DATA(lv_startup) = substring_after( val = |&{ lv_search }| sub = `&sap-startup-params=` ).
    IF lv_startup IS NOT INITIAL.
      " lv_before keeps the prepended `&`, so the empty first segment it
      " produces below is skipped like a trailing one
      DATA(lv_before) = substring_before( val = |&{ lv_search }| sub = `&sap-startup-params=` ).
      SPLIT lv_startup AT `&` INTO DATA(lv_packed) DATA(lv_rest).
      lv_packed = replace( val  = lv_packed
                           sub  = `%3D`
                           with = `=`
                           occ  = 0 ).
      " RFC 3986 allows lowercase hex digits in percent-encodings, so decode
      " %3d the same way as %3D (%26 contains no letters and needs no twin)
      lv_packed = replace( val  = lv_packed
                           sub  = `%3d`
                           with = `=`
                           occ  = 0 ).
      lv_packed = replace( val  = lv_packed
                           sub  = `%26`
                           with = `&`
                           occ  = 0 ).
      lv_search = lv_packed.
      IF lv_rest IS NOT INITIAL.
        lv_search = |{ lv_packed }&{ lv_rest }|.
      ENDIF.
      IF lv_before IS NOT INITIAL.
        lv_search = |{ lv_before }&{ lv_search }|.
      ENDIF.
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
