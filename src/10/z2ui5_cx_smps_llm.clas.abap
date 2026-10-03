"! <p class="shorttext synchronized">LLM - Exception</p>
"! Everything that can go wrong between a sample and a language model, as one
"! checked exception with a readable text: a missing configuration, a
"! destination that does not exist, a connection that fails, an error object
"! the provider sent back. The samples show get_text( ) in a MessageStrip -
"! it is written for the person who has to fix the setup.
CLASS z2ui5_cx_smps_llm DEFINITION PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA text TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        text     TYPE string OPTIONAL
        previous TYPE REF TO cx_root OPTIONAL.

    "! Raises this exception - the one statement of the package that does.
    "! The package runs from 7.40 SP08 on, where RAISE EXCEPTION NEW (7.52)
    "! does not parse, while the shared rule set this repository is linted
    "! with asks for NEW over RAISE EXCEPTION TYPE. Raising an object created
    "! with NEW satisfies both, and doing it here keeps it to one place.
    CLASS-METHODS raise
      IMPORTING
        text     TYPE string
        previous TYPE REF TO cx_root OPTIONAL
      RAISING
        z2ui5_cx_smps_llm.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cx_smps_llm IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( previous = previous ).
    me->text = text.

  ENDMETHOD.


  METHOD raise.

    DATA(error) = NEW z2ui5_cx_smps_llm( text     = text
                                         previous = previous ).
    RAISE EXCEPTION error.

  ENDMETHOD.


  METHOD if_message~get_text.

    result = text.
    IF result IS INITIAL AND previous IS BOUND.
      result = previous->get_text( ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
