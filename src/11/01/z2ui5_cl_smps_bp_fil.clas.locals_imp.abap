CLASS lhc_file DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR file RESULT result.

    METHODS uploadfile FOR MODIFY
      IMPORTING keys FOR ACTION file~uploadfile RESULT result.

ENDCLASS.


CLASS lhc_file IMPLEMENTATION.

  METHOD get_global_authorizations.

    " the sample deliberately grants everything - a real business object would
    " check an authorization object here. Only what was asked for is answered.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-uploadfile = if_abap_behv=>mk-on.
      result-%action-uploadfile = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.


  METHOD uploadfile.

    " A static action has no instance yet, so a key row carries only the %cid
    " of the caller and the parameter. The parameter is DEEP: next to its own
    " field Description it holds the association _StreamProperties as a
    " component, and that one carries the file - content, MIME type, name.
    DATA creates TYPE TABLE FOR CREATE z2ui5_r_smps_fil.

    LOOP AT keys INTO DATA(key) WHERE %param-_streamproperties-filecontent IS NOT INITIAL.

      DATA(stream) = key-%param-_streamproperties.
      APPEND VALUE #( %cid        = key-%cid
                      filename    = stream-filename
                      mimetype    = stream-mimetype
                      description = key-%param-description
                      filesize    = xstrlen( stream-filecontent )
                      content     = stream-filecontent ) TO creates.

    ENDLOOP.

    " the CREATE is INTERNAL in the behavior definition - IN LOCAL MODE is the
    " only way in, which is exactly what keeps every other caller out. The
    " action's %cid is reused, so MAPPED reaches the caller under the very
    " %cid it sent and it can read the new key from there.
    MODIFY ENTITIES OF z2ui5_r_smps_fil IN LOCAL MODE
      ENTITY file
        CREATE FIELDS ( filename mimetype description filesize content )
        WITH creates
      MAPPED DATA(create_mapped)
      FAILED DATA(create_failed)
      REPORTED DATA(create_reported).

    mapped   = CORRESPONDING #( DEEP create_mapped ).
    failed   = CORRESPONDING #( DEEP create_failed ).
    reported = CORRESPONDING #( DEEP create_reported ).

    " an empty file is not refused by the type system - it is refused here,
    " with a message the caller can show
    LOOP AT keys INTO key WHERE %param-_streamproperties-filecontent IS INITIAL.

      APPEND VALUE #( %cid = key-%cid ) TO failed-file.
      APPEND VALUE #( %cid = key-%cid
                      %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'The file is empty - nothing to upload' ) ) TO reported-file.

    ENDLOOP.

    IF create_mapped-file IS INITIAL.
      RETURN.
    ENDIF.

    " result [1] $self: the new instance goes back to the caller. Content is
    " left out of the READ - the caller just sent it, no need to copy it twice.
    READ ENTITIES OF z2ui5_r_smps_fil IN LOCAL MODE
      ENTITY file
        FIELDS ( filename mimetype description filesize createdby createdat lastchangedat )
        WITH VALUE #( FOR m IN create_mapped-file ( %tky = m-%tky ) )
      RESULT DATA(files).

    result = VALUE #( FOR m IN create_mapped-file
                      FOR f IN files WHERE ( fileuuid = m-fileuuid )
                      ( %cid   = m-%cid
                        %param = CORRESPONDING #( f ) ) ).

  ENDMETHOD.

ENDCLASS.
