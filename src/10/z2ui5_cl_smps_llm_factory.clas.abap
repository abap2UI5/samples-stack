"! <p class="shorttext synchronized">LLM - Configuration and Provider Factory</p>
"! Where the samples of this package get their Z2UI5_IF_SMPS_LLM from, and
"! the one place that knows the configuration. Nothing about a provider is
"! written into the code - no endpoint, no model, no key:
"!
"!   - the ENDPOINT is a destination of the system: an SM59 destination on
"!     Standard, a destination of the BTP destination service on ABAP Cloud,
"!     an intelligent scenario for the ABAP AI SDK
"!   - the MODEL, the token limit, the request path and - where nothing in
"!     front of the endpoint adds it - the API KEY are one row of the table
"!     Z2UI5_T_SMPS_LLM, maintained with the settings sample
"!     Z2UI5_CL_SMPS_APP_013
"!
"! The transport is created BY NAME (transport_get( )): Z2UI5_CL_SMPS_LLM_SM59
"! activates on Standard only and Z2UI5_CL_SMPS_LLM_CLOUD on ABAP Cloud only,
"! so a static reference to either would leave this class inactive on the
"! other stack. Same reason, same technique for Z2UI5_CL_SMPS_LLM_ISLM, which
"! needs the ABAP AI SDK.
CLASS z2ui5_cl_smps_llm_factory DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_s_config,
        "! one of cs_provider
        provider    TYPE string,
        "! SM59 destination, BTP destination or intelligent scenario
        destination TYPE string,
        "! request path - empty for the provider's own default
        uri_path    TYPE string,
        "! the model id, exactly as the provider spells it
        model       TYPE string,
        max_tokens  TYPE i,
        "! empty when the destination or a gateway authenticates instead
        api_key     TYPE string,
      END OF ty_s_config.

    CONSTANTS:
      BEGIN OF cs_provider,
        anthropic TYPE string VALUE `ANTHROPIC` ##NO_TEXT,
        openai    TYPE string VALUE `OPENAI` ##NO_TEXT,
        islm      TYPE string VALUE `ISLM` ##NO_TEXT,
      END OF cs_provider.

    CONSTANTS:
      "! the classes created by name - see the class documentation
      BEGIN OF cs_class,
        sm59  TYPE string VALUE `Z2UI5_CL_SMPS_LLM_SM59` ##NO_TEXT,
        cloud TYPE string VALUE `Z2UI5_CL_SMPS_LLM_CLOUD` ##NO_TEXT,
        islm  TYPE string VALUE `Z2UI5_CL_SMPS_LLM_ISLM` ##NO_TEXT,
      END OF cs_class.

    "! the token limit when the configuration leaves it at 0 - the Messages
    "! API requires one, and thinking spends from it before the answer starts
    CONSTANTS default_max_tokens TYPE i VALUE 2048.

    "! The configuration of this client - initial when nobody saved one yet.
    CLASS-METHODS config_read
      RETURNING
        VALUE(result) TYPE ty_s_config.

    "! Saves the configuration; the database commit is the one that ends the
    "! request.
    CLASS-METHODS config_save
      IMPORTING
        config TYPE ty_s_config
      RAISING
        z2ui5_cx_smps_llm.

    "! What is still missing, as a sentence for the screen - empty when the
    "! configuration is complete enough to try.
    CLASS-METHODS config_check
      IMPORTING
        config        TYPE ty_s_config
      RETURNING
        VALUE(result) TYPE string.

    "! The provider the configuration describes, wired to the transport of
    "! this system's stack.
    CLASS-METHODS create
      IMPORTING
        config        TYPE ty_s_config
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_if_smps_llm
      RAISING
        z2ui5_cx_smps_llm.

    "! The HTTP transport this system has - Z2UI5_CL_SMPS_LLM_SM59 or
    "! Z2UI5_CL_SMPS_LLM_CLOUD, empty for neither. A system that carries
    "! both (an on-premise release that also has the cloud client) gets SM59.
    CLASS-METHODS transport_get
      RETURNING
        VALUE(result) TYPE string.

    "! Is the class on this system and active?
    CLASS-METHODS class_check
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
    "! the key of the one configuration row
    CONSTANTS config_id TYPE c LENGTH 10 VALUE 'DEFAULT' ##NO_TEXT.

ENDCLASS.


CLASS z2ui5_cl_smps_llm_factory IMPLEMENTATION.

  METHOD config_read.

    DATA row TYPE z2ui5_t_smps_llm.

    SELECT SINGLE * FROM z2ui5_t_smps_llm WHERE id = @config_id INTO @row.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    result = VALUE #( provider    = row-provider
                      destination = row-destination
                      uri_path    = row-uri_path
                      model       = row-model
                      max_tokens  = row-max_tokens
                      api_key     = row-api_key ).

  ENDMETHOD.


  METHOD config_save.

    DATA(row) = VALUE z2ui5_t_smps_llm( id          = config_id
                                        provider    = config-provider
                                        destination = config-destination
                                        uri_path    = config-uri_path
                                        model       = config-model
                                        max_tokens  = config-max_tokens
                                        api_key     = config-api_key ).

    MODIFY z2ui5_t_smps_llm FROM @row.
    IF sy-subrc <> 0.
      z2ui5_cx_smps_llm=>raise( `The configuration could not be saved.` ).
    ENDIF.

  ENDMETHOD.


  METHOD config_check.

    IF config-provider IS INITIAL.
      result = `No language model is configured on this system yet.`.
    ELSEIF config-destination IS INITIAL.
      result = COND #( WHEN config-provider = cs_provider-islm
                       THEN `The intelligent scenario is missing.`
                       ELSE `The destination is missing.` ).
    ELSEIF config-model IS INITIAL AND config-provider <> cs_provider-islm.
      " the ABAP AI SDK takes the model from the intelligent scenario - the
      " two HTTP providers have nowhere else to take it from
      result = `The model is missing.`.
    ENDIF.

  ENDMETHOD.


  METHOD create.

    DATA http TYPE REF TO z2ui5_if_smps_llm_http.

    DATA(missing) = config_check( config ).
    IF missing IS NOT INITIAL.
      z2ui5_cx_smps_llm=>raise( missing ).
    ENDIF.

    DATA(max_tokens) = COND i( WHEN config-max_tokens > 0 THEN config-max_tokens ELSE default_max_tokens ).

    IF config-provider = cs_provider-islm.
      TRY.
          CREATE OBJECT result TYPE (cs_class-islm)
            EXPORTING
              scenario   = config-destination
              max_tokens = max_tokens.
        CATCH cx_sy_create_object_error INTO DATA(islm_error).
          z2ui5_cx_smps_llm=>raise( text     = |{ cs_class-islm } is not active on this system - it needs the ABAP AI SDK | &&
                                    |(CL_AIC_ISLM_COMPL_API_FACTORY). Pick another provider in the settings.|
                                    previous = islm_error ).
      ENDTRY.
      RETURN.
    ENDIF.

    DATA(transport) = transport_get( ).
    IF transport IS INITIAL.
      z2ui5_cx_smps_llm=>raise( |Neither { cs_class-sm59 } (Standard) nor { cs_class-cloud } (ABAP Cloud) is active on this system.| ).
    ENDIF.

    TRY.
        CREATE OBJECT http TYPE (transport)
          EXPORTING
            destination = config-destination.
      CATCH cx_sy_create_object_error INTO DATA(http_error).
        z2ui5_cx_smps_llm=>raise( text     = |{ transport } could not be created: { http_error->get_text( ) }|
                                  previous = http_error ).
    ENDTRY.

    CASE config-provider.
      WHEN cs_provider-anthropic.
        result = NEW z2ui5_cl_smps_llm_claude( http       = http
                                               model      = config-model
                                               api_key    = config-api_key
                                               max_tokens = max_tokens
                                               path       = config-uri_path ).
      WHEN cs_provider-openai.
        result = NEW z2ui5_cl_smps_llm_openai( http       = http
                                               model      = config-model
                                               api_key    = config-api_key
                                               max_tokens = max_tokens
                                               path       = config-uri_path ).
      WHEN OTHERS.
        z2ui5_cx_smps_llm=>raise( |Unknown provider { config-provider }.| ).
    ENDCASE.

  ENDMETHOD.


  METHOD transport_get.

    IF class_check( cs_class-sm59 ) = abap_true.
      result = cs_class-sm59.
    ELSEIF class_check( cs_class-cloud ) = abap_true.
      result = cs_class-cloud.
    ENDIF.

  ENDMETHOD.


  METHOD class_check.

    " existence of an ACTIVE class - a class that never activated on this
    " stack has no active version and is reported as not found
    cl_abap_classdescr=>describe_by_name( EXPORTING  p_name         = val
                                          EXCEPTIONS type_not_found = 1
                                                     OTHERS         = 2 ).
    result = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.

ENDCLASS.
