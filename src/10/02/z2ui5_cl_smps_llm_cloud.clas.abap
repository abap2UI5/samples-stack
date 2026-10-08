"! <p class="shorttext synchronized">LLM - HTTP Transport for ABAP Cloud</p>
"! Z2UI5_IF_SMPS_LLM_HTTP for ABAP Cloud (SAP BTP ABAP environment, and the
"! S/4HANA releases that run ABAP Cloud): the released HTTP client
"! cl_web_http_client_manager on a destination from cl_http_destination_provider.
"!
"! The destination comes from the BTP destination service, by name:
"!   - BTP subaccount: a destination of type HTTP, URL
"!     https://api.anthropic.com, https://api.openai.com or your gateway -
"!     scheme and host only, the provider appends the path - and
"!     authentication NoAuthentication (the key is a header, see below)
"!   - ABAP environment: the communication arrangement for scenario
"!     SAP_COM_0276 (SAP BTP Destination Service Integration), which is what
"!     lets create_by_cloud_destination( ) read that destination
"! The API key travels in the configuration (Z2UI5_T_SMPS_LLM), or a gateway
"! in front of the provider adds it and the configuration leaves it empty.
"!
"! cl_web_http_client_manager does not exist on 7.40 - on an older
"! on-premise release this class does not activate, and nothing notices:
"! Z2UI5_CL_SMPS_LLM_FACTORY creates it by name and takes
"! Z2UI5_CL_SMPS_LLM_SM59 there instead.
CLASS z2ui5_cl_smps_llm_cloud DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_smps_llm_http.

    "! @parameter destination | the name of the destination in the BTP
    "!                          destination service
    METHODS constructor
      IMPORTING
        destination TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA destination TYPE string.

    "! Closes the connection, on every path of post( ) - a timeout in
    "! execute( ) or a response that is not UTF-8 would otherwise leave it
    "! open until the session ends.
    "! @parameter client | the client, unbound when it was never created
    METHODS client_close
      IMPORTING
        client TYPE REF TO if_web_http_client.

ENDCLASS.


CLASS z2ui5_cl_smps_llm_cloud IMPLEMENTATION.

  METHOD constructor.

    me->destination = destination.

  ENDMETHOD.


  METHOD z2ui5_if_smps_llm_http~post.

    DATA client TYPE REF TO if_web_http_client.

    TRY.
        " service_specific: the destination authenticates as itself, not as
        " the user in front of the screen - an API key belongs to the system
        DATA(http_destination) = cl_http_destination_provider=>create_by_cloud_destination(
                                     i_name       = destination
                                     i_authn_mode = if_a4c_cp_service=>service_specific ).

        client = cl_web_http_client_manager=>create_by_http_destination( http_destination ).
        DATA(request) = client->get_http_request( ).

        request->set_uri_path( path ).
        request->set_header_field( i_name  = `Content-Type`
                                   i_value = `application/json; charset=utf-8` ).
        LOOP AT t_header INTO DATA(header).
          request->set_header_field( i_name  = header-name
                                     i_value = header-value ).
        ENDLOOP.

        " UTF-8 on the wire both ways, set explicitly rather than left to the
        " content type of the response
        request->set_binary( cl_abap_conv_codepage=>create_out( )->convert( body ) ).

        DATA(response) = client->execute( if_web_http_client=>post ).
        result-status = response->get_status( )-code.
        result-body   = cl_abap_conv_codepage=>create_in( )->convert( response->get_binary( ) ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error
            cx_sy_conversion_codepage INTO DATA(error).
        " closed here as well: a CLEANUP would not run, it runs only when an
        " exception LEAVES the TRY, and this one catches its own
        client_close( client ).
        z2ui5_cx_smps_llm=>raise( text     = |Destination { destination }: { error->get_text( ) }|
                                  previous = error ).
    ENDTRY.

    client_close( client ).

  ENDMETHOD.


  METHOD client_close.

    IF client IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        client->close( ).
      CATCH cx_web_http_client_error ##NO_HANDLER.
        " already closed - nothing left to release
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
