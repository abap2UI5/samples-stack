"! <p class="shorttext synchronized">LLM - Anthropic Messages API</p>
"! Z2UI5_IF_SMPS_LLM for the Anthropic Messages API:
"!
"!   POST /v1/messages
"!   x-api-key: &lt;key&gt;            anthropic-version: 2023-06-01
"!   {"model": ..., "max_tokens": ..., "system": ..., "messages": [{"role": "user", "content": "..."}]}
"!
"! The answer is the first text block of the response's content array. It
"! is read by key rather than as content[0]: current models may put a
"! thinking block in front of the text, and that block has no text key. An
"! error comes back as {"type": "error", "error": {"type": ..., "message": ...}}
"! with a 4xx/5xx status, and its message is what the exception carries.
"!
"! Model, key and token limit are handed in from the configuration
"! (Z2UI5_CL_SMPS_LLM_FACTORY) - this class knows the wire format and
"! nothing else. Reference: https://platform.claude.com/docs/en/api/messages
CLASS z2ui5_cl_smps_llm_claude DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_smps_llm.

    CONSTANTS:
      "! the request path when the configuration names none
      default_path TYPE string VALUE `/v1/messages` ##NO_TEXT,
      "! the API version this wire format is written against - a header the
      "! Messages API requires on every request
      api_version  TYPE string VALUE `2023-06-01` ##NO_TEXT.

    "! @parameter http       | the transport of this system's stack
    "! @parameter model      | the model id - configuration, never a default
    "! @parameter api_key    | sent as x-api-key; empty when the destination or
    "!                         a gateway in front of it adds the header itself
    "! @parameter max_tokens | the answer's token limit; thinking counts too
    "! @parameter path       | the request path, empty for /v1/messages
    METHODS constructor
      IMPORTING
        http       TYPE REF TO z2ui5_if_smps_llm_http
        model      TYPE string
        api_key    TYPE string OPTIONAL
        max_tokens TYPE i
        path       TYPE string OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA http TYPE REF TO z2ui5_if_smps_llm_http.
    DATA model TYPE string.
    DATA api_key TYPE string.
    DATA max_tokens TYPE i.
    DATA path TYPE string.

ENDCLASS.


CLASS z2ui5_cl_smps_llm_claude IMPLEMENTATION.

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

    LOOP AT messages INTO DATA(message).
      list = list && COND string( WHEN list IS NOT INITIAL THEN `,` ) &&
             |\{"role":"{ z2ui5_cl_smps_llm_json=>string_escape( message-role ) }",| &&
             |"content":"{ z2ui5_cl_smps_llm_json=>string_escape( message-content ) }"\}|.
    ENDLOOP.

    " system is a top-level field here - there is no system role in messages
    DATA(body) = |\{"model":"{ z2ui5_cl_smps_llm_json=>string_escape( model ) }",| &&
                 |"max_tokens":{ max_tokens },| &&
                 COND string( WHEN system IS NOT INITIAL
                              THEN |"system":"{ z2ui5_cl_smps_llm_json=>string_escape( system ) }",| ) &&
                 |"messages":[{ list }]\}|.

    t_header = VALUE #( ( name = `anthropic-version` value = api_version ) ).
    IF api_key IS NOT INITIAL.
      INSERT VALUE #( name = `x-api-key` value = api_key ) INTO TABLE t_header.
    ENDIF.

    DATA(response) = http->post( path     = path
                                 t_header = t_header
                                 body     = body ).

    IF response-status <> 200.
      DATA(error) = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                        path = VALUE #( ( `error` ) ( `message` ) ) ).
      z2ui5_cx_smps_llm=>raise( |Messages API, HTTP { response-status }: { COND string( WHEN error IS INITIAL THEN response-body ELSE error ) }| ).
    ENDIF.

    result = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                 path = VALUE #( ( `content` ) ( `text` ) ) ).

    " a 200 without a text block: the token limit ran out first - with
    " thinking on, before the model wrote a single word of its answer
    IF result IS INITIAL.
      DATA(stop_reason) = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                              path = VALUE #( ( `stop_reason` ) ) ).
      z2ui5_cx_smps_llm=>raise( |The model returned no text (stop_reason { stop_reason }) - raise Max Tokens in the settings| ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
