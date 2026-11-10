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

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_context IMPLEMENTATION.

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

ENDCLASS.
