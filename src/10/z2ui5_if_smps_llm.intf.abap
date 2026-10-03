"! <p class="shorttext synchronized">LLM - Provider-Neutral Chat Interface</p>
"! What the samples of this package talk to: a conversation in, the next
"! answer out. Nothing in it names a vendor, an endpoint or a model - that is
"! what the implementations and the configuration are for:
"!
"!   Z2UI5_CL_SMPS_LLM_CLAUDE   the Anthropic Messages API (POST /v1/messages)
"!   Z2UI5_CL_SMPS_LLM_OPENAI   an OpenAI-compatible Chat Completions endpoint
"!   Z2UI5_CL_SMPS_LLM_ISLM     SAP's ABAP AI SDK powered by ISLM (src/10/03)
"!
"! Z2UI5_CL_SMPS_LLM_FACTORY=>create( ) picks one from the configuration, so
"! an app never names an implementation and switching the provider is a
"! settings change, not a code change.
INTERFACE z2ui5_if_smps_llm PUBLIC.

  TYPES:
    "! one turn of the conversation - ROLE is user or assistant, the system
    "! prompt travels separately (the Messages API has no system role)
    BEGIN OF ty_s_message,
      role    TYPE string,
      content TYPE string,
    END OF ty_s_message.
  TYPES ty_t_message TYPE STANDARD TABLE OF ty_s_message WITH EMPTY KEY.

  CONSTANTS:
    BEGIN OF cs_role,
      user      TYPE string VALUE `user` ##NO_TEXT,
      assistant TYPE string VALUE `assistant` ##NO_TEXT,
    END OF cs_role.

  "! Sends the whole conversation and returns the model's answer as plain text.
  "! @parameter system   | instructions for the model - empty for none
  "! @parameter messages | the conversation so far, oldest first, ending with
  "!                       the user message that is to be answered
  "! @parameter result   | the text of the answer
  "! @raising z2ui5_cx_smps_llm | no configuration, no connection, or an
  "!                       error returned by the provider - the text says which
  METHODS chat
    IMPORTING
      system        TYPE string OPTIONAL
      messages      TYPE ty_t_message
    RETURNING
      VALUE(result) TYPE string
    RAISING
      z2ui5_cx_smps_llm.

ENDINTERFACE.
