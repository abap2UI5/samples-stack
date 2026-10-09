"! <p class="shorttext synchronized">LLM - JSON Written and Read by Hand</p>
"! The two JSON jobs of this package, done the way abap2UI5 asks an app to do
"! them: by hand. The framework releases no JSON parser, /ui2/cl_json is not
"! released for ABAP Cloud and xco_cp_json does not exist on-premise below
"! the cloud releases - and this package runs on both stacks from 7.40 SP08
"! on. So:
"!
"!   - OUTBOUND, the request body is a string template; string_escape( )
"!     makes free text - a chat message, a table cell - safe inside it.
"!   - INBOUND, get_string( ) reads the ONE string field a provider's answer
"!     is about (content -> text, choices -> message -> content, or error ->
"!     message). It walks the document token by token, so a key that only
"!     appears INSIDE a string value never matches, and it resolves escapes.
"!
"! The same idea as json_build / json_escape / json_get_string in
"! Z2UI5_CL_SMPS_APP_489, which writes its payload itself - here the payload
"! comes from somebody else, so the reader honours the whole JSON string
"! syntax instead of the five escapes it wrote.
CLASS z2ui5_cl_smps_llm_json DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Escapes free text for use inside a JSON string literal (without the
    "! surrounding quotes).
    CLASS-METHODS string_escape
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! Reads one string value out of a JSON document.
    "! @parameter json   | the document
    "! @parameter path   | the keys to pass, in document order - the value of
    "!                     the LAST key is returned. `content` then `text` finds
    "!                     the first text key after the content key, which is
    "!                     how the Messages API's content[0].text is read even
    "!                     when a thinking block comes first
    "! @parameter result | the decoded value, empty when the path is not there
    "!                     or the value is not a string (null, a number)
    CLASS-METHODS get_string
      IMPORTING
        json          TYPE string
        path          TYPE string_table
      RETURNING
        VALUE(result) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_byte TYPE x LENGTH 1.

    "! Reads the string token that starts at POS (the character after the
    "! opening quote) and leaves POS behind its closing quote.
    CLASS-METHODS string_read
      IMPORTING
        json   TYPE string
      EXPORTING
        result TYPE string
      CHANGING
        pos    TYPE i.

    "! The code of a control character (below U+0020), for its \u00XX
    "! escape. Read from the character's bytes, as ABAP has no function
    "! from a character to its code that both stacks release.
    "! @parameter char   | one character below the blank
    "! @parameter result | its code, 00 to 1F
    CLASS-METHODS control_code
      IMPORTING
        char          TYPE string
      RETURNING
        VALUE(result) TYPE ty_byte.

    "! Moves POS past blanks, tabs and line breaks.
    CLASS-METHODS blanks_skip
      IMPORTING
        json TYPE string
      CHANGING
        pos  TYPE i.

    "! The character of a \uXXXX escape. Only the ASCII range is decoded:
    "! decoding beyond it needs a codepage API, and those differ between the
    "! two stacks (cl_abap_conv_codepage on ABAP Cloud, cl_abap_conv_in_ce
    "! on 7.40). The providers send non-ASCII text as UTF-8, not escaped, so
    "! in practice the escape only carries control and markup characters.
    CLASS-METHODS unicode_decode
      IMPORTING
        hex           TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_smps_llm_json IMPLEMENTATION.

  METHOD string_escape.

    DATA escaped TYPE string.

    " The backslash goes FIRST - escaping it after the others would escape
    " the backslashes they just introduced. Tab, line feed and carriage
    " return are the control characters business text usually contains.
    result = val.
    result = replace( val = result sub = `\` with = `\\` occ = 0 ).
    result = replace( val = result sub = `"` with = `\"` occ = 0 ).
    result = replace( val = result sub = |\n| with = `\n` occ = 0 ).
    result = replace( val = result sub = |\r| with = `\r` occ = 0 ).
    result = replace( val = result sub = |\t| with = `\t` occ = 0 ).

    " Every other character below the blank (U+0000 to U+001F) is just as
    " illegal raw in a JSON string - the provider answers 400 - and text
    " pasted from a PDF or a spreadsheet does carry form feeds and vertical
    " tabs. JSON writes them \u00XX. A run without one is copied whole.
    DATA(length) = strlen( result ).
    DATA(pos)    = 0.
    DATA(start)  = 0.
    WHILE pos < length.
      DATA(char) = substring( val = result off = pos len = 1 ).
      IF char < ` `.
        escaped = escaped && substring( val = result off = start len = pos - start )
                          && |\\u00{ control_code( char ) }|.
        start = pos + 1.
      ENDIF.
      pos = pos + 1.
    ENDWHILE.

    IF start > 0.
      result = escaped && substring( val = result off = start ).
    ENDIF.

  ENDMETHOD.


  METHOD control_code.

    " ABAP has no function from a character to its code that both stacks
    " release, so the code is read from the character's bytes: two on a
    " Unicode system (UTF-16), one of them 00 - which one depends on the
    " byte order of the platform, so all of them are OR-ed together
    DATA single TYPE c LENGTH 1.
    DATA offset TYPE i.
    FIELD-SYMBOLS <bytes> TYPE x.

    single = char.
    ASSIGN single TO <bytes> CASTING.
    IF <bytes> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    DO xstrlen( <bytes> ) TIMES.
      result = result BIT-OR <bytes>+offset(1).
      offset = offset + 1.
    ENDDO.

  ENDMETHOD.


  METHOD get_string.

    DATA key TYPE string.
    DATA token TYPE string.

    DATA(length) = strlen( json ).
    DATA(pos)    = 0.
    DATA(level)  = 1.

    WHILE pos < length.

      DATA(char) = substring( val = json off = pos len = 1 ).
      pos = pos + 1.

      " only a string token can be a key - and reading every string token
      " whole is what keeps a key-like text inside a VALUE from matching
      IF char <> `"`.
        CONTINUE.
      ENDIF.
      string_read( EXPORTING json   = json
                   IMPORTING result = token
                   CHANGING  pos    = pos ).

      " a key is a string followed by a colon
      blanks_skip( EXPORTING json = json CHANGING pos = pos ).
      IF pos >= length OR substring( val = json off = pos len = 1 ) <> `:`.
        CONTINUE.
      ENDIF.

      READ TABLE path INDEX level INTO key.
      IF sy-subrc <> 0 OR token <> key.
        CONTINUE.
      ENDIF.

      IF level < lines( path ).
        level = level + 1.
        CONTINUE.
      ENDIF.

      " the last key of the path - its value is the answer, if it is a string
      pos = pos + 1.
      blanks_skip( EXPORTING json = json CHANGING pos = pos ).
      IF pos < length AND substring( val = json off = pos len = 1 ) = `"`.
        pos = pos + 1.
        string_read( EXPORTING json   = json
                     IMPORTING result = result
                     CHANGING  pos    = pos ).
      ENDIF.
      RETURN.

    ENDWHILE.

  ENDMETHOD.


  METHOD string_read.

    CLEAR result.
    DATA(length) = strlen( json ).

    WHILE pos < length.

      DATA(char) = substring( val = json off = pos len = 1 ).
      pos = pos + 1.

      " the closing quote - an escaped one never gets here, the branch
      " below consumes it
      IF char = `"`.
        RETURN.
      ENDIF.

      IF char <> `\`.
        result = result && char.
        CONTINUE.
      ENDIF.

      " a backslash at the very end is a truncated document - stop rather
      " than read past it
      IF pos >= length.
        RETURN.
      ENDIF.
      DATA(escaped) = substring( val = json off = pos len = 1 ).
      pos = pos + 1.

      CASE escaped.
        WHEN `n`.
          result = result && |\n|.
        WHEN `r`.
          result = result && |\r|.
        WHEN `t`.
          result = result && |\t|.
        WHEN `b` OR `f`.
          " backspace and form feed carry nothing a screen can show
        WHEN `u`.
          IF pos + 4 > length.
            RETURN.
          ENDIF.
          result = result && unicode_decode( substring( val = json off = pos len = 4 ) ).
          pos = pos + 4.
        WHEN OTHERS.
          " `"`, `\` and `/` stand for themselves
          result = result && escaped.
      ENDCASE.

    ENDWHILE.

  ENDMETHOD.


  METHOD blanks_skip.

    DATA(length) = strlen( json ).
    WHILE pos < length AND substring( val = json off = pos len = 1 ) CA | \t\r\n|.
      pos = pos + 1.
    ENDWHILE.

  ENDMETHOD.


  METHOD unicode_decode.

    " the printable ASCII range in code point order, starting at the blank
    " (0x20) - the backtick is doubled because this is a backtick literal
    CONSTANTS printable TYPE string VALUE ` !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_``abcdefghijklmnopqrstuvwxyz{|}~`.

    DATA code_x TYPE x LENGTH 2.
    DATA code TYPE i.

    " hex digits only - anything else is not an escape this method can read,
    " and it is kept as it came
    IF hex CN `0123456789abcdefABCDEF`.
      result = |\\u{ hex }|.
      RETURN.
    ENDIF.

    code_x = to_upper( hex ).
    code = code_x.

    IF code = 10.
      result = |\n|.
    ELSEIF code = 13.
      result = |\r|.
    ELSEIF code = 9.
      result = |\t|.
    ELSEIF code >= 32 AND code <= 126.
      result = substring( val = printable off = code - 32 len = 1 ).
    ELSE.
      " outside ASCII: kept as written, see the method documentation
      result = |\\u{ hex }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
