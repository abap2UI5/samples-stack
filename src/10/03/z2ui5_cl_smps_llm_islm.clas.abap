"! <p class="shorttext synchronized">LLM - SAP ABAP AI SDK (ISLM)</p>
"! Z2UI5_IF_SMPS_LLM on SAP's own route to a model: the ABAP AI SDK powered by
"! Intelligent Scenario Lifecycle Management (ISLM), which reaches the models
"! of the generative AI hub in SAP AI Core. No HTTP, no destination, no key in
"! this package - all of that is configured in the intelligent scenario:
"!
"!   cl_aic_islm_compl_api_factory=>get( )->create_instance( scenario )
"!   api->create_message_container( ) - set_system_role / add_user_message /
"!                                      add_assistant_message
"!   api->execute_for_messages( container )->get_completion( )
"!
"! (as in SAP's own samples: SAP-samples/abap-cheat-sheets, 30_Generative_AI,
"! and SAP-samples/abap-partner-reference-application, tutorial 42)
"!
"! What it needs: a system that carries the ABAP AI SDK - SAP BTP ABAP
"! environment and the S/4HANA releases that ship it - with SAP AI Core
"! connected and an intelligent scenario plus model set up in the ISLM apps.
"! The scenario's id is the Destination of the configuration; the Model field
"! stays empty, the scenario names the model. Where the SDK is missing this
"! class does not activate, and nothing else notices:
"! Z2UI5_CL_SMPS_LLM_FACTORY creates it by name and says so instead.
CLASS z2ui5_cl_smps_llm_islm DEFINITION PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_smps_llm.

    "! @parameter scenario   | the id of the intelligent scenario (ISLM)
    "! @parameter max_tokens | the answer's token limit
    METHODS constructor
      IMPORTING
        scenario   TYPE string
        max_tokens TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA scenario TYPE string.
    DATA max_tokens TYPE i.

ENDCLASS.


CLASS z2ui5_cl_smps_llm_islm IMPLEMENTATION.

  METHOD constructor.

    me->scenario   = scenario.
    me->max_tokens = max_tokens.

  ENDMETHOD.


  METHOD z2ui5_if_smps_llm~chat.

    TRY.
        DATA(api) = cl_aic_islm_compl_api_factory=>get( )->create_instance( CONV #( scenario ) ).
        api->get_parameter_setter( )->set_maximum_tokens( max_tokens ).

        DATA(container) = api->create_message_container( ).
        IF system IS NOT INITIAL.
          container->set_system_role( system ).
        ENDIF.

        LOOP AT messages INTO DATA(message).
          IF message-role = z2ui5_if_smps_llm=>cs_role-assistant.
            container->add_assistant_message( message-content ).
          ELSE.
            container->add_user_message( message-content ).
          ENDIF.
        ENDLOOP.

        result = api->execute_for_messages( container )->get_completion( ).

      CATCH cx_aic_api_factory cx_aic_completion_api INTO DATA(error).
        z2ui5_cx_smps_llm=>raise( text     = |Intelligent scenario { scenario }: { error->get_text( ) }|
                                  previous = error ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
