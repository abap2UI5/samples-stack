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
      DATA temp6 TYPE z2ui5_if_smps_llm_http=>ty_s_header.
    DATA response TYPE z2ui5_if_smps_llm_http=>ty_s_response.
      DATA temp7 TYPE string_table.
      DATA error TYPE string.
      DATA temp9 TYPE string.
    DATA temp10 TYPE string_table.
      DATA temp12 TYPE string_table.
      DATA stop_reason TYPE string.
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

    " system is a top-level field here - there is no system role in messages
    
    IF system IS NOT INITIAL.
      temp3 = |"system":"{ z2ui5_cl_smps_llm_json=>string_escape( system ) }",|.
    ELSE.
      CLEAR temp3.
    ENDIF.
    
    body = |\{"model":"{ z2ui5_cl_smps_llm_json=>string_escape( model ) }",| &&
                 |"max_tokens":{ max_tokens },| &&
                 temp3 &&
                 |"messages":[{ list }]\}|.

    
    CLEAR temp4.
    
    temp5-name = `anthropic-version`.
    temp5-value = api_version.
    INSERT temp5 INTO TABLE temp4.
    t_header = temp4.
    IF api_key IS NOT INITIAL.
      
      CLEAR temp6.
      temp6-name = `x-api-key`.
      temp6-value = api_key.
      INSERT temp6 INTO TABLE t_header.
    ENDIF.

    
    response = http->post( path     = path
                                 t_header = t_header
                                 body     = body ).

    IF response-status <> 200.
      
      CLEAR temp7.
      INSERT `error` INTO TABLE temp7.
      INSERT `message` INTO TABLE temp7.
      
      error = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                        path = temp7 ).
      
      IF error IS INITIAL.
        temp9 = response-body.
      ELSE.
        temp9 = error.
      ENDIF.
      z2ui5_cx_smps_llm=>raise( |Messages API, HTTP { response-status }: { temp9 }| ).
    ENDIF.

    
    CLEAR temp10.
    INSERT `content` INTO TABLE temp10.
    INSERT `text` INTO TABLE temp10.
    result = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                 path = temp10 ).

    " a 200 without a text block: the token limit ran out first - with
    " thinking on, before the model wrote a single word of its answer
    IF result IS INITIAL.
      
      CLEAR temp12.
      INSERT `stop_reason` INTO TABLE temp12.
      
      stop_reason = z2ui5_cl_smps_llm_json=>get_string( json = response-body
                                                              path = temp12 ).
      z2ui5_cx_smps_llm=>raise( |The model returned no text (stop_reason { stop_reason }) - raise Max Tokens in the settings| ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
