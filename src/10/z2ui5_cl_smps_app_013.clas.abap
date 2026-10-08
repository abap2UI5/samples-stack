" @keywords ai llm chat settings configuration destination sm59 islm
" @summary where the two AI samples get their model from - provider, destination, model and key, saved once and tested with one press
"! <p class="shorttext synchronized">AI / LLM - Settings and Connection Test</p>
"! The configuration screen of package 10: which provider, which destination,
"! which model, which key - and a Test button that sends one message and
"! shows what came back. Z2UI5_CL_SMPS_APP_014 (chat) and
"! Z2UI5_CL_SMPS_APP_015 (summarize a table) read what is saved here.
"!
"! Nothing of it is in the code. The endpoint is a destination of the system
"! - SM59 on Standard, the BTP destination service on ABAP Cloud, an
"! intelligent scenario for SAP's ABAP AI SDK - and model, token limit, path
"! and key are one row of Z2UI5_T_SMPS_LLM (Z2UI5_CL_SMPS_LLM_FACTORY).
"!
"! The API key is WRITE-ONLY on this screen: it is never read back into the
"! view model, so it never reaches a browser after it was typed. Leave it
"! empty when the destination or a gateway in front of the provider adds the
"! header - that is the better place for a secret than a table, which
"! anybody with a data browser can read. And restrict who may start this
"! class (ICF node, role): any user who reaches it can change the setup.
CLASS z2ui5_cl_smps_app_013 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA provider TYPE string.
    DATA destination TYPE string.
    DATA model TYPE string.
    DATA max_tokens TYPE i.
    DATA uri_path TYPE string.
    "! what was TYPED - empty on every display, see the class documentation
    DATA api_key TYPE string.
    DATA key_placeholder TYPE string.
    DATA key_stored TYPE abap_bool.
    DATA key_remove TYPE abap_bool.

    DATA transport_text TYPE string.
    DATA result_text TYPE string.
    "! bound to a MessageType, which UI5 validates even while the strip is
    "! hidden - an empty string terminates the app on the first display
    DATA result_type TYPE string VALUE `Information`.
    DATA result_visible TYPE abap_bool.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS on_event.
    METHODS view_display.
    METHODS model_init.

    "! the configuration as the form describes it - the stored key unless a
    "! new one was typed or the stored one is to be removed
    METHODS config_from_form
      RETURNING
        VALUE(result) TYPE z2ui5_cl_smps_llm_factory=>ty_s_config.

    METHODS on_save.
    METHODS on_test.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_013 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      model_init( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).

      WHEN `SAVE`.
        on_save( ).

      WHEN `TEST`.
        on_test( ).

    ENDCASE.

  ENDMETHOD.


  METHOD on_save.

    TRY.
        z2ui5_cl_smps_llm_factory=>config_save( config_from_form( ) ).
        model_init( ).
        client->message_toast_display( `Settings saved` ).

      CATCH z2ui5_cx_smps_llm INTO DATA(error).
        result_text    = error->get_text( ).
        result_type    = `Error`.
        result_visible = abap_true.
    ENDTRY.

  ENDMETHOD.


  METHOD on_test.

    " what the FORM says, saved or not - testing before saving is the point
    TRY.
        DATA(llm) = z2ui5_cl_smps_llm_factory=>create( config_from_form( ) ).
        DATA(answer) = llm->chat( system   = `You are a connection test. Answer with one short sentence.`
                                  messages = VALUE #( ( role    = z2ui5_if_smps_llm=>cs_role-user
                                                        content = `Say hello to an ABAP developer.` ) ) ).
        result_text = |The model answered: { answer }|.
        result_type = `Success`.

      CATCH z2ui5_cx_smps_llm INTO DATA(error).
        result_text = error->get_text( ).
        result_type = `Error`.
    ENDTRY.

    result_visible = abap_true.

  ENDMETHOD.


  METHOD config_from_form.

    DATA(stored) = z2ui5_cl_smps_llm_factory=>config_read( ).

    result = VALUE #( provider    = provider
                      destination = condense( destination )
                      model       = condense( model )
                      max_tokens  = max_tokens
                      uri_path    = condense( uri_path )
                      api_key     = stored-api_key ).

    IF api_key IS NOT INITIAL.
      result-api_key = condense( api_key ).
    ELSEIF key_remove = abap_true.
      CLEAR result-api_key.
    ENDIF.

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).

    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - AI / LLM - Settings`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Where the AI samples of this package get their model from. The endpoint is a ` &&
                                 `destination of this system, everything else is saved here - nothing is in the ` &&
                                 `code. Test sends one message with what the form says, saved or not.`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( transport_text )
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBeginEnd` ).

    DATA(form) = page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` v = `true`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->ele( n = `content` ns = `form` ).

    form->tag( `Label`
        )->a( n = `text` v = `Provider`
        )->ele( `Select`
            )->a( n = `selectedKey` v = client->_bind( provider )
            )->ele( `items`
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = z2ui5_cl_smps_llm_factory=>cs_provider-anthropic
                    )->a( n = `text` v = `Anthropic Messages API`
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = z2ui5_cl_smps_llm_factory=>cs_provider-openai
                    )->a( n = `text` v = `OpenAI-compatible Chat Completions`
                )->tag( n = `Item` ns = `core`
                    )->a( n = `key`  v = z2ui5_cl_smps_llm_factory=>cs_provider-islm
                    )->a( n = `text` v = `SAP ABAP AI SDK (ISLM)` ).

    form->tag( `Label`
        )->a( n = `text` v = `Destination`
        )->tag( `Input`
            )->a( n = `value`       v = client->_bind( destination )
            )->a( n = `placeholder` v = `SM59 destination, BTP destination or intelligent scenario`
        )->tag( `Label`
            )->a( n = `text` v = `Model`
        )->tag( `Input`
            )->a( n = `value`       v = client->_bind( model )
            )->a( n = `placeholder` v = `the model id exactly as your provider spells it - empty for ISLM`
        )->tag( `Label`
            )->a( n = `text` v = `Max Tokens`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( max_tokens )
            )->a( n = `type`  v = `Number`
        )->tag( `Label`
            )->a( n = `text` v = `Request Path`
        )->tag( `Input`
            )->a( n = `value`       v = client->_bind( uri_path )
            )->a( n = `placeholder` v = `empty for /v1/messages or /v1/chat/completions`
        )->tag( `Label`
            )->a( n = `text` v = `API Key`
        )->tag( `Input`
            )->a( n = `value`       v = client->_bind( api_key )
            )->a( n = `type`        v = `Password`
            )->a( n = `placeholder` v = client->_bind( key_placeholder )
        )->tag( `Label`
        )->tag( `CheckBox`
            )->a( n = `text`     v = `Remove the stored key`
            )->a( n = `selected` v = client->_bind( key_remove )
            )->a( n = `visible`  v = client->_bind( key_stored ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( result_text )
        )->a( n = `type`     v = client->_bind( result_type )
        )->a( n = `visible`  v = client->_bind( result_visible )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `text`  v = `Test Connection`
                )->a( n = `icon`  v = `sap-icon://connected`
                )->a( n = `press` v = client->_event( `TEST` )
            )->tag( `Button`
                )->a( n = `text`  v = `Save`
                )->a( n = `type`  v = `Emphasized`
                )->a( n = `press` v = client->_event( `SAVE` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD model_init.

    DATA(config) = z2ui5_cl_smps_llm_factory=>config_read( ).

    provider    = COND #( WHEN config-provider IS INITIAL
                          THEN z2ui5_cl_smps_llm_factory=>cs_provider-anthropic
                          ELSE config-provider ).
    destination = config-destination.
    model       = config-model.
    uri_path    = config-uri_path.
    max_tokens  = COND #( WHEN config-max_tokens > 0
                          THEN config-max_tokens
                          ELSE z2ui5_cl_smps_llm_factory=>default_max_tokens ).

    " the key itself stays on the server - the form only learns that there is one
    CLEAR api_key.
    CLEAR key_remove.
    key_stored      = xsdbool( config-api_key IS NOT INITIAL ).
    key_placeholder = COND #( WHEN key_stored = abap_true
                              THEN `a key is stored - type a new one to replace it`
                              ELSE `empty when the destination or a gateway adds the key` ).

    DATA(transport) = z2ui5_cl_smps_llm_factory=>transport_get( ).
    transport_text = SWITCH #( transport
        WHEN z2ui5_cl_smps_llm_factory=>cs_class-sm59
        THEN |This system calls out with { transport }: Destination is an SM59 destination of type G.|
        WHEN z2ui5_cl_smps_llm_factory=>cs_class-cloud
        THEN |This system calls out with { transport }: Destination is a destination of the BTP | &&
             |destination service (communication arrangement SAP_COM_0276).|
        ELSE |No HTTP transport is active on this system - only the ABAP AI SDK (ISLM) can work here.| ).

    IF z2ui5_cl_smps_llm_factory=>class_check( z2ui5_cl_smps_llm_factory=>cs_class-islm ) = abap_true.
      transport_text = |{ transport_text } The ABAP AI SDK is available too: for it, Destination is the intelligent scenario.|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
