" @keywords file upload attachment rap action deep parameter largeobject stream eml fileuploader download
" @summary EXECUTE uploadFile with a deep parameter - the file travels as a stream property, download and delete included
"! <p class="shorttext synchronized">RAP File Upload - Deep Action Parameter</p>
"! A file enters the business object z2ui5_r_smps_fil through its static
"! action uploadFile. The action parameter is DEEP: the abstract entity
"! z2ui5_a_smps_file_upload carries a description and, through an
"! association, the abstract entity z2ui5_a_smps_file_stream with the file
"! content, its MIME type and its name.
"!
"!     MODIFY ENTITIES OF z2ui5_r_smps_fil
"!       ENTITY file
"!         EXECUTE uploadfile
"!         FROM VALUE #( ( %cid   = `UPLOAD_1`
"!                         %param = VALUE #(
"!                           description       = ...
"!                           _streamproperties = VALUE #( filecontent = ...
"!                                                        mimetype    = ...
"!                                                        filename    = ... ) ) ) )
"!       FAILED DATA(s_failed)
"!       REPORTED DATA(s_reported).
"!
"! Fiori Elements reads the @Semantics.largeObject annotations of the stream
"! entity and renders a file picker into the action dialog. abap2UI5 needs
"! neither the annotations nor an OData service: the FileUploader custom
"! control reads the file in the browser, the roundtrip brings it to the
"! backend as base64, and the app hands it to the action like any other
"! value. The business logic - what is stored, what is refused - stays in
"! the business object.
CLASS z2ui5_cl_smps_app_016 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    "! the picked file as the FileUploader delivers it - a data URL,
    "! data:&lt;mime&gt;;base64,&lt;payload&gt;
    DATA file        TYPE string.
    "! the name of the picked file
    DATA file_name   TYPE string.
    DATA description TYPE string.

    TYPES:
      BEGIN OF ty_s_file,
        file_uuid   TYPE string,
        file_name   TYPE string,
        mime_type   TYPE string,
        file_size   TYPE string,
        description TYPE string,
        created_at  TYPE string,
      END OF ty_s_file.
    TYPES ty_t_file TYPE STANDARD TABLE OF ty_s_file WITH EMPTY KEY.
    DATA t_files TYPE ty_t_file.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_event.
    METHODS file_upload.
    METHODS file_download.
    METHODS file_delete.
    METHODS data_read.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_016 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      data_read( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `UPLOAD`.
        file_upload( ).

      WHEN `DOWNLOAD`.
        file_download( ).

      WHEN `DELETE`.
        file_delete( ).

      WHEN `REFRESH`.
        " the table is bound - changing it is enough, the framework sends the
        " changed model back on its own
        data_read( ).

    ENDCASE.

  ENDMETHOD.


  METHOD file_upload.

    " the FileUploader delivers a data URL - data:<mime>;base64,<payload>.
    " The MIME type is the browser's guess from the file extension and may be
    " missing altogether, so it falls back to the generic binary type.
    SPLIT file AT `,` INTO DATA(header) DATA(base64).
    DATA(mime_type) = substring_before( val = substring_after( val = header sub = `data:` ) sub = `;` ).
    IF mime_type IS INITIAL.
      mime_type = `application/octet-stream`.
    ENDIF.
    DATA(content) = cl_web_http_utility=>decode_x_base64( base64 ).

    " a static action needs no key - the %cid is the caller's own id for it.
    " The parameter is deep: description on the first level, the file one
    " level below under the association _streamproperties.
    MODIFY ENTITIES OF z2ui5_r_smps_fil
      ENTITY file
        EXECUTE uploadfile
        FROM VALUE #( ( %cid   = `UPLOAD_1`
                        %param = VALUE #( description       = description
                                          _streamproperties = VALUE #( filecontent = content
                                                                       mimetype    = mime_type
                                                                       filename    = file_name ) ) ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-file IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-file ).
      RETURN.

    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_fil
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.

      " a failed save keeps the changes in the transactional buffer - discard
      " them, or abap2UI5's own COMMIT WORK at the end of the roundtrip runs
      " into them
      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported_commit-file ).
      RETURN.

    ENDIF.

    client->message_toast_display( |{ file_name } - { xstrlen( content ) } bytes stored in the business object| ).

    file        = VALUE #( ).
    file_name   = VALUE #( ).
    description = VALUE #( ).
    data_read( ).
    view_display( ).

  ENDMETHOD.


  METHOD file_download.

    DATA(file_uuid) = CONV z2ui5_t_smps_fil-file_uuid( client->get_event_arg( ) ).

    READ ENTITIES OF z2ui5_r_smps_fil
      ENTITY file
        FIELDS ( filename mimetype content )
        WITH VALUE #( ( fileuuid = file_uuid ) )
      RESULT DATA(t_result).

    " a file deleted in another tab is not an exception - RESULT is just empty
    IF t_result IS INITIAL.
      client->message_box_display( text = `The file is no longer there - press Refresh` type = `error` ).
      RETURN.
    ENDIF.

    " the same road back: the content becomes a data URL again, and the
    " download_b64_file frontend action saves it under its name
    DATA(s_file) = t_result[ 1 ].
    client->follow_up_action(
        val   = client->cs_event-download_b64_file
        t_arg = VALUE #( ( |data:{ s_file-mimetype };base64,{ cl_web_http_utility=>encode_x_base64( s_file-content ) }| )
                         ( |{ s_file-filename }| ) ) ).

  ENDMETHOD.


  METHOD file_delete.

    DATA(file_uuid) = CONV z2ui5_t_smps_fil-file_uuid( client->get_event_arg( ) ).

    MODIFY ENTITIES OF z2ui5_r_smps_fil
      ENTITY file
        DELETE FROM VALUE #( ( fileuuid = file_uuid ) )
      FAILED DATA(s_failed)
      REPORTED DATA(s_reported).

    IF s_failed-file IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported-file ).
      RETURN.

    ENDIF.

    COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_fil
      FAILED DATA(s_failed_commit)
      REPORTED DATA(s_reported_commit).

    IF s_failed_commit IS NOT INITIAL.

      ROLLBACK ENTITIES.
      z2ui5_cl_smps_context=>msg_display( client = client val = s_reported_commit-file ).
      RETURN.

    ENDIF.

    client->message_toast_display( `File deleted` ).
    data_read( ).

  ENDMETHOD.


  METHOD data_read.

    " EML reads by key - a list of every file is a SELECT on the CDS view.
    " The content stays in the database: the list needs its size, not its
    " bytes, and every row would otherwise travel to the browser.
    SELECT FROM z2ui5_r_smps_fil                        "#EC CI_NOWHERE
      FIELDS FileUuid,
             FileName,
             MimeType,
             FileSize,
             Description,
             CreatedAt
      ORDER BY CreatedAt DESCENDING
      INTO TABLE @DATA(t_result) UP TO 50 ROWS.

    t_files = VALUE #( FOR s_result IN t_result
        ( file_uuid   = |{ s_result-fileuuid }|
          file_name   = |{ s_result-filename }|
          mime_type   = |{ s_result-mimetype }|
          file_size   = |{ s_result-filesize } bytes|
          description = |{ s_result-description }|
          created_at  = |{ s_result-createdat TIMESTAMP = ISO }| ) ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - RAP File Upload - Deep Action Parameter`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Pick a file and press Upload: the FileUploader hands it to the backend as base64, the app ` &&
                                 `calls the static action uploadFile of Z2UI5_R_SMPS_FIL with EML and passes the file in ` &&
                                 `its deep parameter - no OData service, no annotations needed.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `MODIFY ENTITIES OF Z2UI5_R_SMPS_FIL ... EXECUTE uploadFile`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Description`
            )->tag( `Input`
                )->a( n = `placeholder` v = `optional - stored with the file`
                )->a( n = `value`       v = client->_bind( description )
            )->tag( `Label`
                )->a( n = `text` v = `File`
            )->tag( n = `FileUploader` ns = `z2ui5`
                )->a( n = `placeholder`      v = `pick a file...`
                )->a( n = `uploadButtonText` v = `Upload`
                )->a( n = `upload`           v = client->_event( `UPLOAD` )
                )->a( n = `path`             v = client->_bind( file_name )
                )->a( n = `value`            v = client->_bind( file ) ).

    DATA(table) = page->ele( `Table`
        )->a( n = `items`      v = client->_bind( t_files )
        )->a( n = `noDataText` v = `No files yet - upload one above` ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Files (Z2UI5_R_SMPS_FIL)`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press`   v = client->_event( `REFRESH` )
                )->a( n = `icon`    v = `sap-icon://refresh`
                )->a( n = `tooltip` v = `Refresh` ).

    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Name`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `MIME Type`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Size`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Description`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Created`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Actions` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{FILE_NAME}`
                )->tag( `Text`
                    )->a( n = `text` v = `{MIME_TYPE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{FILE_SIZE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DESCRIPTION}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CREATED_AT}`
                )->ele( `HBox`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `DOWNLOAD` arg = `${FILE_UUID}` )
                        )->a( n = `icon`    v = `sap-icon://download`
                        )->a( n = `tooltip` v = `Download File`
                    )->tag( `Button`
                        )->a( n = `press`   v = client->_event( val = `DELETE` arg = `${FILE_UUID}` )
                        )->a( n = `icon`    v = `sap-icon://delete`
                        )->a( n = `tooltip` v = `Delete File` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
