CLASS ltcl_string_escape DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS quote_and_backslash FOR TESTING.
    METHODS line_breaks_and_tab FOR TESTING.
    METHODS other_control_characters FOR TESTING.
    METHODS plain_text_unchanged FOR TESTING.
    METHODS round_trip FOR TESTING.

ENDCLASS.


CLASS ltcl_string_escape IMPLEMENTATION.

  METHOD quote_and_backslash.

    cl_abap_unit_assert=>assert_equals(
        exp = `say \"hi\" to C:\\temp`
        act = z2ui5_cl_smps_llm_json=>string_escape( `say "hi" to C:\temp` ) ).

  ENDMETHOD.


  METHOD line_breaks_and_tab.

    cl_abap_unit_assert=>assert_equals(
        exp = `a\nb\r\nc\td`
        act = z2ui5_cl_smps_llm_json=>string_escape( |a\nb\r\nc\td| ) ).

  ENDMETHOD.


  METHOD other_control_characters.

    " raw below U+0020 is a 400 from the provider - each one is written as
    " \u00XX, and the text around it stays as it was
    DATA(text) = `page` && cl_abap_char_utilities=>form_feed &&
                 `next` && cl_abap_char_utilities=>vertical_tab &&
                 `line` && cl_abap_char_utilities=>backspace && `end`.

    cl_abap_unit_assert=>assert_equals(
        exp = `page\u000Cnext\u000Bline\u0008end`
        act = z2ui5_cl_smps_llm_json=>string_escape( text ) ).

  ENDMETHOD.


  METHOD plain_text_unchanged.

    cl_abap_unit_assert=>assert_equals(
        exp = `Revenue 2025: 1,250.00 EUR - {region} / 100%`
        act = z2ui5_cl_smps_llm_json=>string_escape( `Revenue 2025: 1,250.00 EUR - {region} / 100%` ) ).

  ENDMETHOD.


  METHOD round_trip.

    " what string_escape( ) writes, get_string( ) reads back unchanged
    DATA(text) = |a "quoted" C:\\path\nnext line|.
    DATA(json) = |\{"text":"{ z2ui5_cl_smps_llm_json=>string_escape( text ) }"\}|.

    cl_abap_unit_assert=>assert_equals(
        exp = text
        act = z2ui5_cl_smps_llm_json=>get_string( json = json
                                                  path = VALUE #( ( `text` ) ) ) ).

  ENDMETHOD.

ENDCLASS.
