"! <p class="shorttext synchronized">LLM - HTTP Transport over an SM59 Destination</p>
"! Z2UI5_IF_SMPS_LLM_HTTP for ABAP Standard (on-premise), from 7.40 SP08 on:
"! cl_http_client=>create_by_destination( ) with an SM59 destination of type
"! G (HTTP connection to external server).
"!
"! What the destination carries, so that nothing of it is in the code:
"!   Target Host   api.anthropic.com, api.openai.com or your gateway
"!   Service No.   443
"!   Path Prefix   empty - the provider appends /v1/messages or the path the
"!                 configuration names
"!   SSL           active, with an SSL client PSE (STRUST) that trusts the
"!                 endpoint's certificate chain
"!   Proxy         if the system reaches the internet only through one
"! The API key is NOT a field of SM59 - SM59 knows user/password and
"! certificates, not an x-api-key header. It travels in the configuration
"! (Z2UI5_T_SMPS_LLM), or a gateway between the system and the provider adds
"! it and the configuration leaves it empty.
"!
"! cl_http_client is not released for ABAP Cloud: on a cloud stack this class
"! does not activate, and nothing notices - Z2UI5_CL_SMPS_LLM_FACTORY creates
"! it by name and takes Z2UI5_CL_SMPS_LLM_CLOUD there instead.
CLASS z2ui5_cl_smps_llm_sm59 DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_smps_llm_http.

    "! @parameter destination | the SM59 destination (type G)
    METHODS constructor
      IMPORTING
        destination TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA destination TYPE string.

ENDCLASS.


CLASS z2ui5_cl_smps_llm_sm59 IMPLEMENTATION.

  METHOD constructor.

    me->destination = destination.

  ENDMETHOD.


  METHOD z2ui5_if_smps_llm_http~post.

    DATA client TYPE REF TO if_http_client.
    DATA message TYPE string.
    DATA t_field TYPE tihttpnvp.

    cl_http_client=>create_by_destination( EXPORTING  destination              = CONV rfcdest( destination )
                                           IMPORTING  client                   = client
                                           EXCEPTIONS argument_not_found       = 1
                                                      destination_not_found    = 2
                                                      destination_no_authority = 3
                                                      plugin_not_active        = 4
                                                      internal_error           = 5
                                                      OTHERS                   = 6 ).
    IF sy-subrc <> 0.
      z2ui5_cx_smps_llm=>raise( |SM59 destination { destination } cannot be opened (sy-subrc { sy-subrc }) - | &&
                                |does it exist, is it of type G, may you use it?| ).
    ENDIF.

    client->request->set_method( if_http_request=>co_request_method_post ).
    cl_http_utility=>set_request_uri( request = client->request
                                      uri     = path ).

    t_field = VALUE #( ( name = `Content-Type` value = `application/json; charset=utf-8` ) ).
    LOOP AT t_header INTO DATA(header).
      INSERT VALUE #( name = header-name value = header-value ) INTO TABLE t_field.
    ENDLOOP.
    client->request->set_header_fields( t_field ).

    " UTF-8 on the wire both ways, set explicitly: set_cdata( ) / get_cdata( )
    " take the code page from the content type, and a response that names
    " none would be read in the system's default instead
    client->request->set_data( cl_abap_codepage=>convert_to( body ) ).

    client->send( EXCEPTIONS http_communication_failure = 1
                             http_invalid_state         = 2
                             http_processing_failed     = 3
                             http_invalid_timeout       = 4
                             OTHERS                     = 5 ).
    IF sy-subrc = 0.
      client->receive( EXCEPTIONS http_communication_failure = 1
                                  http_invalid_state         = 2
                                  http_processing_failed     = 3
                                  OTHERS                     = 4 ).
    ENDIF.

    IF sy-subrc <> 0.
      " the usual causes: no SSL client PSE trusting the endpoint (STRUST),
      " a proxy the destination does not name, a host the system cannot resolve
      client->get_last_error( IMPORTING message = message ).
      client->close( EXCEPTIONS OTHERS = 1 ).
      z2ui5_cx_smps_llm=>raise( |SM59 destination { destination }: { message }| ).
    ENDIF.

    client->response->get_status( IMPORTING code = result-status ).
    DATA(raw) = client->response->get_data( ).
    client->close( EXCEPTIONS OTHERS = 1 ).

    " a body that is not UTF-8 - typically the HTML error page of a proxy or
    " gateway in its own code page - raises a dynamic check exception the
    " callers would not catch; turned into the one exception they do, as the
    " cloud transport does
    TRY.
        result-body = cl_abap_codepage=>convert_from( raw ).
      CATCH cx_sy_conversion_codepage cx_sy_codepage_converter_init cx_parameter_invalid_range
            cx_parameter_invalid_type INTO DATA(error).
        z2ui5_cx_smps_llm=>raise( text     = |SM59 destination { destination }: HTTP { result-status }, | &&
                                             |the response is not UTF-8 - { error->get_text( ) }|
                                  previous = error ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
