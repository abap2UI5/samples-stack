" @keywords adobe forms pdf ads fp_job_open print form output zip download cl_abap_zip
" @summary Renders Adobe Forms of the system to PDF with FP_JOB_OPEN and the generated function module - one form as a PDF download, several at once as one ZIP file
"! <p class="shorttext synchronized">Adobe Forms - Render to PDF, Download One or a ZIP</p>
"! An Adobe Form is rendered by the function module the form generates. Its
"! name comes from FP_FUNCTION_MODULE_NAME, and between FP_JOB_OPEN and
"! FP_JOB_CLOSE it returns the PDF instead of printing it:
"!
"!     CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
"!       EXPORTING i_name = form IMPORTING e_funcname = function.
"!
"!     CALL FUNCTION 'FP_JOB_OPEN'
"!       CHANGING ie_outputparams = VALUE sfpoutputparams( getpdf = abap_true nodialog = abap_true ).
"!
"!     CALL FUNCTION function
"!       EXPORTING /1bcdwb/docparams  = docparams
"!       IMPORTING /1bcdwb/formoutput = output.   " output-pdf is the file
"!
"!     CALL FUNCTION 'FP_JOB_CLOSE'.
"!
"! The generated function module has the interface of its form, so the app
"! calls it with a PARAMETER-TABLE: the form name is typed in at runtime, and
"! a form whose interface has mandatory parameters of its own says so.
"! Several forms go into one ZIP file with cl_abap_zip.
"!
"! Needs Adobe Document Services (ADS) configured for the system - the
"! destination ADS in SM59. On ABAP Cloud forms are rendered by the Forms
"! Service by Adobe through cl_fp_ads_util instead; this sample is Standard
"! only.
CLASS z2ui5_cl_smps_app_024 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    "! one form name per line
    DATA forms TYPE string.

    TYPES:
      BEGIN OF ty_s_result,
        form   TYPE string,
        size   TYPE string,
        status TYPE string,
        state  TYPE string,
      END OF ty_s_result.
    TYPES ty_t_result TYPE STANDARD TABLE OF ty_s_result WITH EMPTY KEY.
    "! what the last run produced, one row per form
    DATA t_results TYPE ty_t_result.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    TYPES:
      BEGIN OF ty_s_pdf,
        form TYPE string,
        pdf  TYPE xstring,
      END OF ty_s_pdf.
    TYPES ty_t_pdf TYPE STANDARD TABLE OF ty_s_pdf WITH EMPTY KEY.

    METHODS on_event.

    "! renders every form of FORMS - the ones that worked come back, every
    "! form gets its row in T_RESULTS
    METHODS forms_render
      RETURNING
        VALUE(result) TYPE ty_t_pdf.

    "! one form to PDF - ERROR says why when it does not render
    METHODS form_render
      IMPORTING
        form  TYPE string
      EXPORTING
        pdf   TYPE xstring
        error TYPE string.

    METHODS file_download
      IMPORTING
        name      TYPE string
        mime_type TYPE string
        content   TYPE xstring.

    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_024 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    DATA(t_pdf) = forms_render( ).

    IF t_pdf IS INITIAL.
      view_display( ).
      RETURN.
    ENDIF.

    CASE client->get_event( ).

      WHEN `PDF`.
        " the first form that rendered - one file, no ZIP needed
        DATA(s_pdf) = t_pdf[ 1 ].
        file_download( name      = |{ to_lower( s_pdf-form ) }.pdf|
                       mime_type = `application/pdf`
                       content   = s_pdf-pdf ).

      WHEN `ZIP`.
        DATA(zip) = NEW cl_abap_zip( ).
        LOOP AT t_pdf INTO s_pdf.
          zip->add( name    = |{ to_lower( s_pdf-form ) }.pdf|
                    content = s_pdf-pdf ).
        ENDLOOP.
        file_download( name      = `forms.zip`
                       mime_type = `application/zip`
                       content   = zip->save( ) ).

    ENDCASE.

    view_display( ).

  ENDMETHOD.


  METHOD forms_render.

    CLEAR t_results.
    SPLIT forms AT cl_abap_char_utilities=>newline INTO TABLE DATA(t_form).

    LOOP AT t_form INTO DATA(form).

      form = to_upper( condense( form ) ).
      IF form IS INITIAL.
        CONTINUE.
      ENDIF.

      form_render( EXPORTING form  = form
                   IMPORTING pdf   = DATA(pdf)
                             error = DATA(error) ).

      IF error IS INITIAL.
        APPEND VALUE #( form = form pdf = pdf ) TO result.
        APPEND VALUE #( form   = form
                        size   = |{ xstrlen( pdf ) } bytes|
                        status = `rendered`
                        state  = `Success` ) TO t_results.
      ELSE.
        APPEND VALUE #( form   = form
                        status = error
                        state  = `Error` ) TO t_results.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD form_render.

    DATA function  TYPE funcname.
    DATA output    TYPE fpformoutput.
    DATA docparams TYPE sfpdocparams.
    DATA outputpar TYPE sfpoutputparams.

    CLEAR: pdf, error.

    " the name of the function module the form generated - it differs per
    " system, which is why it is asked for and never written down
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = CONV fpname( form )
          IMPORTING
            e_funcname = function.
      CATCH cx_fp_api INTO DATA(api_error).
        error = api_error->get_text( ).
        RETURN.
    ENDTRY.

    " getpdf: hand the PDF back instead of sending it to a printer,
    " nodialog: no print dialog - there is no SAP GUI to show it in
    outputpar-getpdf   = abap_true.
    outputpar-nodialog = abap_true.

    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = outputpar
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        system_error    = 3
        internal_error  = 4
        OTHERS          = 5.
    IF sy-subrc <> 0.
      error = |FP_JOB_OPEN failed with sy-subrc { sy-subrc } - is ADS configured?|.
      RETURN.
    ENDIF.

    " the generated function module has the interface of its form - called
    " with a parameter table, so any form name typed in at runtime works
    DATA(t_param) = VALUE abap_func_parmbind_tab(
        ( name  = '/1BCDWB/DOCPARAMS'
          kind  = abap_func_exporting
          value = REF #( docparams ) )
        ( name  = '/1BCDWB/FORMOUTPUT'
          kind  = abap_func_importing
          value = REF #( output ) ) ).
    DATA(t_exc) = VALUE abap_func_excpbind_tab(
        ( name = 'USAGE_ERROR'    value = 1 )
        ( name = 'SYSTEM_ERROR'   value = 2 )
        ( name = 'INTERNAL_ERROR' value = 3 )
        ( name = 'OTHERS'         value = 4 ) ).

    TRY.
        CALL FUNCTION function
          PARAMETER-TABLE t_param
          EXCEPTION-TABLE t_exc.
        IF sy-subrc <> 0.
          error = |{ function } failed with sy-subrc { sy-subrc }|.
        ENDIF.

      CATCH cx_sy_dyn_call_error INTO DATA(call_error).
        " a form whose interface wants more than the two parameters above
        error = call_error->get_text( ).
    ENDTRY.

    " closed in every case - an open job would make the next FP_JOB_OPEN of
    " this session fail
    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0 AND error IS INITIAL.
      error = |FP_JOB_CLOSE failed with sy-subrc { sy-subrc }|.
    ENDIF.

    IF error IS INITIAL.
      pdf = output-pdf.
    ENDIF.

  ENDMETHOD.


  METHOD file_download.

    " base64 through the classic utility class - this package is Standard
    " only, and cl_http_utility is there on every release it runs on
    client->follow_up_action(
        val   = client->cs_event-download_b64_file
        t_arg = VALUE #( ( |data:{ mime_type };base64,{ cl_http_utility=>encode_x_base64( content ) }| )
                         ( name ) ) ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Adobe Forms - 24 Render to PDF`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Type one Adobe Form name per line. Download PDF renders the first one, Download ZIP all of ` &&
                                 `them into one ZIP file. Needs Adobe Document Services configured for this system, and ` &&
                                 `forms whose interface needs no parameters of its own.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `FP_JOB_OPEN - generated function module - FP_JOB_CLOSE`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Forms`
            )->tag( `TextArea`
                )->a( n = `value`       v = client->_bind( forms )
                )->a( n = `rows`        v = `4`
                )->a( n = `placeholder` v = `one form name per line` ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_results )
        )->a( n = `noDataText` v = `Nothing rendered yet` ).
    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Form`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Size`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Result` ).
    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{FORM}`
                )->tag( `Text`
                    )->a( n = `text` v = `{SIZE}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{STATUS}`
                    )->a( n = `state` v = `{= ${STATE} || 'None' }` ).

    page->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `PDF` )
                )->a( n = `text`  v = `Download PDF`
                )->a( n = `icon`  v = `sap-icon://pdf-attachment`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `ZIP` )
                )->a( n = `text`  v = `Download ZIP`
                )->a( n = `icon`  v = `sap-icon://attachment-zip-file`
                )->a( n = `type`  v = `Emphasized` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
