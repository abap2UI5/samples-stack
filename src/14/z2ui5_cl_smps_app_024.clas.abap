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
    TYPES ty_t_result TYPE STANDARD TABLE OF ty_s_result WITH DEFAULT KEY.
    "! what the last run produced, one row per form
    DATA t_results TYPE ty_t_result.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    TYPES:
      BEGIN OF ty_s_pdf,
        form TYPE string,
        pdf  TYPE xstring,
      END OF ty_s_pdf.
    TYPES ty_t_pdf TYPE STANDARD TABLE OF ty_s_pdf WITH DEFAULT KEY.

    METHODS view_display.

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

    METHODS on_event.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_024 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ) IS NOT INITIAL.
      view_display( ).
    ELSEIF client->check_on_event( ) IS NOT INITIAL.
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA view TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA page TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA table TYPE REF TO z2ui5_cl_ui5_view_builder.
    view = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    
    page = view->ele( `Shell`
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

    
    table = page->ele( `Table`
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


  METHOD on_event.

    DATA t_pdf TYPE z2ui5_cl_smps_app_024=>ty_t_pdf.
        DATA s_pdf LIKE LINE OF t_pdf.
        FIELD-SYMBOLS <temp1> LIKE LINE OF t_pdf.
        DATA temp2 LIKE sy-tabix.
        DATA zip TYPE REF TO cl_abap_zip.
    t_pdf = forms_render( ).

    IF t_pdf IS INITIAL.
      RETURN.
    ENDIF.

    CASE client->get_event( ).

      WHEN `PDF`.
        " the first form that rendered - one file, no ZIP needed
        
        
        
        temp2 = sy-tabix.
        READ TABLE t_pdf INDEX 1 ASSIGNING <temp1>.
        sy-tabix = temp2.
        IF sy-subrc <> 0.
          ASSERT 1 = 0.
        ENDIF.
        s_pdf = <temp1>.
        file_download( name      = |{ to_lower( s_pdf-form ) }.pdf|
                       mime_type = `application/pdf`
                       content   = s_pdf-pdf ).

      WHEN `ZIP`.
        
        CREATE OBJECT zip TYPE cl_abap_zip.
        LOOP AT t_pdf INTO s_pdf.
          zip->add( name    = |{ to_lower( s_pdf-form ) }.pdf|
                    content = s_pdf-pdf ).
        ENDLOOP.
        file_download( name      = `forms.zip`
                       mime_type = `application/zip`
                       content   = zip->save( ) ).

    ENDCASE.

  ENDMETHOD.


  METHOD forms_render.
    DATA t_form TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA form LIKE LINE OF t_form.
      DATA pdf TYPE xstring.
      DATA error TYPE string.
        DATA temp1 TYPE z2ui5_cl_smps_app_024=>ty_s_pdf.
        DATA temp2 TYPE z2ui5_cl_smps_app_024=>ty_s_result.
        DATA temp3 TYPE z2ui5_cl_smps_app_024=>ty_s_result.

    CLEAR t_results.
    
    SPLIT forms AT cl_abap_char_utilities=>newline INTO TABLE t_form.

    
    LOOP AT t_form INTO form.

      form = to_upper( condense( form ) ).
      IF form IS INITIAL.
        CONTINUE.
      ENDIF.

      
      
      form_render( EXPORTING form  = form
                   IMPORTING pdf   = pdf
                             error = error ).

      IF error IS INITIAL.
        
        CLEAR temp1.
        temp1-form = form.
        temp1-pdf = pdf.
        INSERT temp1 INTO TABLE result.
        
        CLEAR temp2.
        temp2-form = form.
        temp2-size = |{ xstrlen( pdf ) } bytes|.
        temp2-status = `rendered`.
        temp2-state = `Success`.
        INSERT temp2 INTO TABLE t_results.
      ELSE.
        
        CLEAR temp3.
        temp3-form = form.
        temp3-status = error.
        temp3-state = `Error`.
        INSERT temp3 INTO TABLE t_results.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD form_render.

    DATA function  TYPE funcname.
    DATA output    TYPE fpformoutput.
    DATA docparams TYPE sfpdocparams.
    DATA outputpar TYPE sfpoutputparams.
        DATA temp3 TYPE fpname.
        DATA temp4 LIKE temp3.
        DATA api_error TYPE REF TO cx_fp_api.
    DATA temp5 LIKE REF TO output.
DATA temp8 LIKE REF TO docparams.
DATA temp1 TYPE abap_func_parmbind_tab.
DATA temp2 LIKE LINE OF temp1.
DATA t_param LIKE temp1.
    DATA temp6 TYPE abap_func_excpbind_tab.
    DATA temp7 LIKE LINE OF temp6.
    DATA t_exc LIKE temp6.
        DATA call_error TYPE REF TO cx_sy_dyn_call_error.

    CLEAR: pdf, error.

    " the name of the function module the form generated - it differs per
    " system, which is why it is asked for and never written down
    TRY.
        
        temp3 = form.
        
        temp4 = temp3.
CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = temp4
          IMPORTING
            e_funcname = function.
        
      CATCH cx_fp_api INTO api_error.
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
    
    GET REFERENCE OF output INTO temp5.

GET REFERENCE OF docparams INTO temp8.

CLEAR temp1.

temp2-name = '/1BCDWB/DOCPARAMS'.
temp2-kind = abap_func_exporting.
temp2-value = temp8.
INSERT temp2 INTO TABLE temp1.
temp2-name = '/1BCDWB/FORMOUTPUT'.
temp2-kind = abap_func_importing.
temp2-value = temp5.
INSERT temp2 INTO TABLE temp1.

t_param = temp1.
    
    CLEAR temp6.
    
    temp7-name = 'USAGE_ERROR'.
    temp7-value = 1.
    INSERT temp7 INTO TABLE temp6.
    temp7-name = 'SYSTEM_ERROR'.
    temp7-value = 2.
    INSERT temp7 INTO TABLE temp6.
    temp7-name = 'INTERNAL_ERROR'.
    temp7-value = 3.
    INSERT temp7 INTO TABLE temp6.
    temp7-name = 'OTHERS'.
    temp7-value = 4.
    INSERT temp7 INTO TABLE temp6.
    
    t_exc = temp6.

    TRY.
        CALL FUNCTION function
          PARAMETER-TABLE t_param
          EXCEPTION-TABLE t_exc.
        IF sy-subrc <> 0.
          error = |{ function } failed with sy-subrc { sy-subrc }|.
        ENDIF.

        
      CATCH cx_sy_dyn_call_error INTO call_error.
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
    DATA temp8 TYPE string_table.
    DATA temp9 LIKE LINE OF temp8.
    CLEAR temp8.
    
    temp9 = |data:{ mime_type };base64,{ cl_http_utility=>encode_x_base64( content ) }|.
    INSERT temp9 INTO TABLE temp8.
    INSERT name INTO TABLE temp8.
    client->follow_up_action(
        val   = client->cs_event-download_b64_file
        t_arg = temp8 ).

  ENDMETHOD.

ENDCLASS.
