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
    DATA temp1 TYPE string.

    me->http       = http.
    me->model      = model.
    me->api_key    = api_key.
    me->max_tokens = max_tokens.
    
    IF path IS INITIAL.
      temp1 = default_path.
    ELSE.
      temp1 = path.
    ENDIF.
    me->path       = temp1.

  ENDMETHOD.


  METHOD z2ui5_if_smps_llm~chat.

    DATA t_header TYPE z2ui5_if_smps_llm_http=>ty_t_header.
    DATA list TYPE string.
    DATA message LIKE LINE OF messages.
      DATA temp2 TYPE string.
    DATA temp3 TYPE string.
    DATA body TYPE string.
      DATA temp4 TYPE z2ui5_if_smps_llm_http=>ty_t_header.
      DATA temp5 LIKE LINE OF temp4.
    DATA response TYPE z2ui5_if_smps_llm_http=>ty_s_response.
      DATA temp6 TYPE string_table.
      DATA error TYPE string.
      DATA temp8 TYPE string.
    DATA temp9 TYPE string_table.
      DATA temp11 TYPE string_table.
      DATA finish_reason TYPE string.

    IF system IS NOT INITIAL.
      list = |\{"role":"system","content":"{ z2ui5_cl_smps_llm_json=>string_escape( system ) }"\}|.
    ENDIF.

    
    LOOP AT messages INTO message.
      
      IF list IS NOT INITIAL.
        temp2 = `,`.
      ELSE.
        CLEAR temp2.
      ENDIF.
      list = list && temp2 &&
             |\{"role":"{ z2ui5_cl_smps_llm_json=>string_escape( message-role ) }",| &&
             |"content":"{ z2ui5_cl_smps_llm_json=>string_escape( message-content ) }"\}|.
    ENDLOOP.

    
    IF max_tokens > 0.
      temp3 = |"{ token_field }":{ max_tokens },|.
    ELSE.
      CLEAR temp3.
    ENDIF.
    
    body = |\{"model":"{ z2ui5_cl_smps_llm_json=>string_escape( model ) }",| &&
                 temp3 &&
                 |"messages":[{ list }]\}|.

    IF api_key IS NOT INITIAL.
      
      CLEAR temp4.
      
      temp5-name = `Authorization`.
      temp5-value = |Bearer { api_key }|.
      INSERT temp5 INTO TABLE temp4.
      t_header = temp4.
    ENDIF.

    
    response = http->post( path     = path
                                 t_header = t_header
                                 body     = body ).

    IF response-status <> 200.
      
      CLEAR temp6.
      INSERT `error` INTO TABLE temp6.
      INSERT `message` INTO TABLE temp6.
      
      error = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                        path = temp6 ).
      
      IF error IS INITIAL.
        temp8 = response-body.
      ELSE.
        temp8 = error.
      ENDIF.
      z2ui5_cx_smps_llm=>raise( |Chat Completions, HTTP { response-status }: { temp8 }| ).
    ENDIF.

    
    CLEAR temp9.
    INSERT `choices` INTO TABLE temp9.
    INSERT `message` INTO TABLE temp9.
    INSERT `content` INTO TABLE temp9.
    result = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                 path = temp9 ).

    IF result IS INITIAL.
      
      CLEAR temp11.
      INSERT `finish_reason` INTO TABLE temp11.
      
      finish_reason = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                                path = temp11 ).
      z2ui5_cx_smps_llm=>raise( |The model returned no text (finish_reason { finish_reason }) - raise Max Tokens in the settings| ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
