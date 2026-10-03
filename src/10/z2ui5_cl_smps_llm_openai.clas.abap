"! <p class="shorttext synchronized">LLM - OpenAI-Compatible Chat Completions</p>
"! Z2UI5_IF_SMPS_LLM for an OpenAI-compatible Chat Completions endpoint -
"! OpenAI itself, or any of the many servers and gateways that speak the
"! same wire format (Azure OpenAI, a local Ollama or vLLM, LiteLLM, ...):
"!
"!   POST /v1/chat/completions
"!   Authorization: Bearer &lt;key&gt;
"!   {"model": ..., "max_completion_tokens": ..., "messages": [{"role": "system", ...}, {"role": "user", ...}]}
"!
"! The answer is choices[0].message.content, an error comes back as
"! {"error": {"message": ...}}. The system prompt travels as the first
"! message with role system - this API has no top-level field for it.
"!
"! The token limit is sent as max_completion_tokens, the name OpenAI's
"! current models require (they reject the older max_tokens). A server that
"! only knows max_tokens ignores the field and answers without a limit; if
"! yours rejects it instead, change token_field below. Compatible servers
"! differ in their path too - Azure OpenAI is one - which is why the path is
"! configuration as well.
CLASS z2ui5_cl_smps_llm_openai DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_smps_llm.

    CONSTANTS:
      "! the request path when the configuration names none
      default_path TYPE string VALUE `/v1/chat/completions` ##NO_TEXT,
      "! the name of the token limit field in the request body
      token_field  TYPE string VALUE `max_completion_tokens` ##NO_TEXT.

    "! @parameter http       | the transport of this system's stack
    "! @parameter model      | the model id - configuration, never a default
    "! @parameter api_key    | sent as a Bearer token; empty when the
    "!                         destination or a gateway authenticates instead
    "! @parameter max_tokens | the answer's token limit, 0 for none
    "! @parameter path       | the request path, empty for /v1/chat/completions
    METHODS constructor
      IMPORTING
        http       TYPE REF TO z2ui5_if_smps_llm_http
        model      TYPE string
        api_key    TYPE string OPTIONAL
        max_tokens TYPE i OPTIONAL
        path       TYPE string OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA http TYPE REF TO z2ui5_if_smps_llm_http.
    DATA model TYPE string.
    DATA api_key TYPE string.
    DATA max_tokens TYPE i.
    DATA path TYPE string.

ENDCLASS.


CLASS z2ui5_cl_smps_llm_openai IMPLEMENTATION.

  METHOD constructor.

    me->http       = http.
    me->model      = model.
    me->api_key    = api_key.
    me->max_tokens = max_tokens.
    me->path       = COND #( WHEN path IS INITIAL THEN default_path ELSE path ).

  ENDMETHOD.


  METHOD z2ui5_if_smps_llm~chat.

    DATA t_header TYPE z2ui5_if_smps_llm_http=>ty_t_header.
    DATA list TYPE string.

    IF system IS NOT INITIAL.
      list = |\{"role":"system","content":"{ z2ui5_cl_smps_llm_json=>string_escape( system ) }"\}|.
    ENDIF.

    LOOP AT messages INTO DATA(message).
      list = list && COND string( WHEN list IS NOT INITIAL THEN `,` ) &&
             |\{"role":"{ z2ui5_cl_smps_llm_json=>string_escape( message-role ) }",| &&
             |"content":"{ z2ui5_cl_smps_llm_json=>string_escape( message-content ) }"\}|.
    ENDLOOP.

    DATA(body) = |\{"model":"{ z2ui5_cl_smps_llm_json=>string_escape( model ) }",| &&
                 COND string( WHEN max_tokens > 0
                              THEN |"{ token_field }":{ max_tokens },| ) &&
                 |"messages":[{ list }]\}|.

    IF api_key IS NOT INITIAL.
      t_header = VALUE #( ( name = `Authorization` value = |Bearer { api_key }| ) ).
    ENDIF.

    DATA(response) = http->post( path     = path
                                 t_header = t_header
                                 body     = body ).

    IF response-status <> 200.
      DATA(error) = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                        path = VALUE #( ( `error` ) ( `message` ) ) ).
      z2ui5_cx_smps_llm=>raise( |Chat Completions, HTTP { response-status }: { COND string( WHEN error IS INITIAL THEN response-body ELSE error ) }| ).
    ENDIF.

    result = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                 path = VALUE #( ( `choices` ) ( `message` ) ( `content` ) ) ).

    IF result IS INITIAL.
      DATA(finish_reason) = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                                path = VALUE #( ( `finish_reason` ) ) ).
      z2ui5_cx_smps_llm=>raise( |The model returned no text (finish_reason { finish_reason }) - raise Max Tokens in the settings| ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
