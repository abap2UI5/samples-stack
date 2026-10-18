"! <p class="shorttext synchronized">abap2UI5 sample - Excel read and write with XCO</p>
"! The XCO XLSX library behind the samples of package 13: an .xlsx file in,
"! a table of strings out - and the way back. Every cell travels as a string,
"! so one table type serves every sheet, and the app converts what it needs.
"!
"! Six columns, A to F, are read and written - enough for the samples, and a
"! fixed row structure is what the XCO row stream maps the cells onto.
CLASS z2ui5_cl_smps_xlsx DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_s_row,
        a TYPE string,
        b TYPE string,
        c TYPE string,
        d TYPE string,
        e TYPE string,
        f TYPE string,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH EMPTY KEY.

    "! the MIME type of an .xlsx file - for a data URL or a mail attachment
    CONSTANTS mime_type TYPE string
      VALUE `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` ##NO_TEXT.

    "! the first worksheet, every row from the first one on, columns A to F
    CLASS-METHODS read
      IMPORTING
        val           TYPE xstring
      RETURNING
        VALUE(result) TYPE ty_t_row.

    "! one worksheet, the rows from A1 on
    CLASS-METHODS write
      IMPORTING
        t_row         TYPE ty_t_row
      RETURNING
        VALUE(result) TYPE xstring.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_xlsx IMPLEMENTATION.

  METHOD read.

    DATA(worksheet) = xco_cp_xlsx=>document->for_file_content( val
        )->read_access(
        )->get_workbook(
        )->worksheet->at_position( 1 ).

    " A1 down to the last row: a pattern without an end reads as far as the
    " sheet has rows, and the six columns of ty_s_row decide how wide
    DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
        )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( `A` )
        )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( `F` )
        )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
        )->get_pattern( ).

    " the string value transformation turns every cell into its text - a
    " number comes back as it is stored, a date as its serial number
    worksheet->select( pattern
        )->row_stream(
        )->operation->write_to( REF #( result )
        )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
        )->execute( ).

  ENDMETHOD.


  METHOD write.

    DATA(document) = xco_cp_xlsx=>document->empty( )->write_access( ).

    DATA(pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
        )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( `A` )
        )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( `F` )
        )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
        )->get_pattern( ).

    document->get_workbook(
        )->worksheet->at_position( 1
        )->select( pattern
        )->row_stream(
        )->operation->write_from( REF #( t_row )
        )->execute( ).

    result = document->get_file_content( ).

  ENDMETHOD.

ENDCLASS.
