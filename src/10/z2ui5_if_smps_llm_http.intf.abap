"! <p class="shorttext synchronized">LLM - HTTP Transport, One per Stack</p>
"! How a provider reaches its endpoint: one POST with a JSON body. Split off
"! from the providers because it is the one part that differs between the two
"! stacks this package runs on, and it differs in exactly one way - which
"! HTTP client the system releases:
"!
"!   Z2UI5_CL_SMPS_LLM_SM59    Standard (on-premise) - cl_http_client and an
"!                             SM59 destination (src/10/01)
"!   Z2UI5_CL_SMPS_LLM_CLOUD   ABAP Cloud - cl_web_http_client_manager and a
"!                             destination of the BTP destination service
"!                             (src/10/02)
"!
"! Each one activates on its own stack only, which is why nothing references
"! them statically: Z2UI5_CL_SMPS_LLM_FACTORY creates whichever this system
"! has, by name. The providers in src/10 see this interface and nothing else.
INTERFACE z2ui5_if_smps_llm_http PUBLIC.

  TYPES:
    BEGIN OF ty_s_header,
      name  TYPE string,
      value TYPE string,
    END OF ty_s_header.
  TYPES ty_t_header TYPE STANDARD TABLE OF ty_s_header WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_s_response,
      "! the HTTP status code - 200 is success, everything else carries an
      "! error object in the body
      status TYPE i,
      body   TYPE string,
    END OF ty_s_response.

  "! POSTs BODY, UTF-8 encoded, as application/json.
  "! @parameter path     | the request path, appended to the host the
  "!                       destination points at - /v1/messages, say
  "! @parameter t_header | additional request header fields, the
  "!                       authentication header among them
  "! @parameter body     | the JSON request body
  "! @parameter result   | status code and body of the response, whatever
  "!                       the status - reading an error is the provider's job
  "! @raising z2ui5_cx_smps_llm | the destination is missing or the endpoint
  "!                       could not be reached at all
  METHODS post
    IMPORTING
      path          TYPE string
      t_header      TYPE ty_t_header OPTIONAL
      body          TYPE string
    RETURNING
      VALUE(result) TYPE ty_s_response
    RAISING
      z2ui5_cx_smps_llm.

ENDINTERFACE.
