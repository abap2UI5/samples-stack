" The lock helpers below fail the way a classic function module fails - with a
" message in sy-msg*, not with an exception - so they need one of their own to
" carry that text out to the app. It is local on purpose: this repository ships
" no exception class (see the note in z2ui5_cl_smps_context), and the framework's
" z2ui5_cx_util_error, which this sample used to borrow, sits in abap2UI5's
" frozen src/99 - shipped so old installations keep compiling, with no new
" consumers allowed. Unchecked (cx_no_check), so acquire_lock and
" get_lock_counter keep their signatures and the exception travels through
" on_event to the handler in z2ui5_if_app~main.
CLASS lcx_error DEFINITION INHERITING FROM cx_no_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        val TYPE string OPTIONAL
          PREFERRED PARAMETER val.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA text TYPE string.
ENDCLASS.


CLASS lcx_error IMPLEMENTATION.

  METHOD constructor.

    super->constructor( ).
    CLEAR textid.
    text = val.

  ENDMETHOD.

  METHOD if_message~get_text.

    result = COND #( WHEN text IS INITIAL THEN `UNKNOWN_ERROR` ELSE text ).

  ENDMETHOD.

ENDCLASS.


CLASS lcl_locking DEFINITION CREATE PRIVATE.
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_seqg3,
        " Elementary Lock of Lock Entry (Table Name)
        gname    TYPE c LENGTH 30,
        " Argument String (=Key Fields) of Lock Entry
        garg     TYPE c LENGTH 150,
        " Lock Mode (Shared/Exclusive) of a Lock Entry
        gmode    TYPE c LENGTH 1,
        " Lock Owner, ID of Logical Unit of Work (LUW)
        gusr     TYPE c LENGTH 58,
        " Lock Owner, ID of Logical Unit of Work (LUW) / Update Task
        gusrvb   TYPE c LENGTH 58,
        " Cumulative Counter for Lock Entry / Dialog
        guse     TYPE int4,
        " Cumulative Counter for Lock Entry / Update Task
        gusevb   TYPE int4,
        " Name of Lock Object in the Lock Entry
        gobj     TYPE c LENGTH 16,
        " Client in the lock entry
        gclient  TYPE c LENGTH 3,
        " User name in lock entry
        guname   TYPE c LENGTH 12,
        " Argument String of Lock Entry (Table Key Fields)
        gtarg    TYPE c LENGTH 50,
        " Transaction Code in the Lock Entry
        gtcode   TYPE c LENGTH 20,
        " Backup flag for lock entry
        gbcktype TYPE c LENGTH 1,
        " Host Name in the Lock Owner ID
        gthost   TYPE c LENGTH 32,
        " Work Process Number in Lock Owner ID
        gtwp     TYPE n LENGTH 2,
        " SAP System Number in Lock Owner ID
        gtsysnr  TYPE n LENGTH 2,
        " Date within lock owner ID
        gtdate   TYPE d,
        " Time in Lock Owner ID
        gttime   TYPE t,
        " Time/Microseconds Share in Lock Owner ID
        gtusec   TYPE n LENGTH 6,
        " Selection Indicator of Lock Entry
        gtmark   TYPE c LENGTH 1,
        " Cumulative Counter for Lock Entry
        gusetxt  TYPE n LENGTH 10,
        " Cumulative Counter for Lock Entry / Update Task
        gusevbt  TYPE n LENGTH 10,
      END OF ty_seqg3.

    " the key this sample locks. Z2UI5_T_SMPS_01 is client-dependent, and
    " ENQUEUE_E_TABLE takes the table key as one string, client included -
    " see lock_argument
    CONSTANTS lock_key TYPE c LENGTH 4 VALUE 'Z100'.

    CLASS-METHODS acquire_lock.

    CLASS-METHODS get_lock_counter
      RETURNING
        VALUE(result) TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS lock_argument
      RETURNING
        VALUE(result) TYPE char120.

ENDCLASS.

CLASS lcl_locking IMPLEMENTATION.

  METHOD acquire_lock.

    DATA(lv_varkey) = lock_argument( ).
    DATA(lv_fm) = 'ENQUEUE_E_TABLE'.
    CALL FUNCTION lv_fm
      EXPORTING
        tabname        = 'Z2UI5_T_SMPS_01'
        varkey         = lv_varkey
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO DATA(error_text).
      RAISE EXCEPTION TYPE lcx_error EXPORTING val = error_text.
    ENDIF.

  ENDMETHOD.


  METHOD get_lock_counter.
    DATA enqueue_table TYPE STANDARD TABLE OF ty_seqg3 WITH EMPTY KEY.

    " no GARG filter: the lock argument of E_TABLE is the table name padded to
    " the length of RSTABLE-TABNAME followed by the key, and a filter string
    " that gets that padding wrong matches nothing. All locks of this user are
    " read and the one of this sample is picked out below - by lock object,
    " table name and key, independent of the column layout
    DATA(lv_fm) = 'ENQUEUE_READ'.
    CALL FUNCTION lv_fm
      EXPORTING
        guname                = sy-uname
      TABLES
        enq                   = enqueue_table
      EXCEPTIONS
        communication_failure = 1
        system_failure        = 2
        OTHERS                = 3.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO DATA(error_text).
      RAISE EXCEPTION TYPE lcx_error EXPORTING val = error_text.
    ENDIF.

    DATA(lv_pattern) = |Z2UI5_T_SMPS_01*{ lock_argument( ) }*|.
    LOOP AT enqueue_table INTO DATA(ls_enqueue).
      IF ls_enqueue-gobj = 'E_TABLE' AND ls_enqueue-garg CP lv_pattern.
        " the cumulative counter of the update task owner - ENQUEUE_E_TABLE
        " locks with the default _SCOPE 2, which hands the lock to it
        result = ls_enqueue-gusevb.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD lock_argument.

    result = |{ sy-mandt }{ lock_key }|.

  ENDMETHOD.

ENDCLASS.
