" @keywords ai llm chat chatbot feedinput feedlistitem anthropic openai
" @summary a chat with a real language model over HTTPS - the conversation goes out, the answer comes back, the provider is configuration
"! <p class="shorttext synchronized">AI / LLM - Chat with a Language Model</p>
"! A chat screen in front of a REAL language model: FeedInput, a feed of
"! FeedListItems, and every question sent together with the conversation so
"! far. The screen is the one of Z2UI5_CL_SMP_APP_540 in abap2UI5/samples,
"! which answers with a local rule-based provider and points here for the
"! real call - this is that call. Its source:
"! https://github.com/abap2UI5/samples/blob/main/src/z2ui5_cl_smp_app_540.clas.abap
"!
"! The app knows one interface, Z2UI5_IF_SMPS_LLM, and asks
"! Z2UI5_CL_SMPS_LLM_FACTORY for an implementation. Which provider answers -
"! the Anthropic Messages API, an OpenAI-compatible endpoint or SAP's ABAP AI
"! SDK - is a setting (Z2UI5_CL_SMPS_APP_013), not code.
"!
"! Two roundtrips per question: POST shows the question at once and puts the
"! feed into its busy state, a timer then asks for the ANSWER. The seconds
"! the model needs are spent in the second one, behind a screen that already
"! says what is going on.
"!
"! What it needs: a configured provider. Without one the app starts anyway
"! and says what is missing - nothing is sent, nothing dumps.
CLASS z2ui5_cl_smps_app_014 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_feed,
        sender TYPE string,
        "! HTML-escaped: a FeedListItem renders its text as FormattedText
        text   TYPE string,
        icon   TYPE string,
        info   TYPE string,
      END OF ty_s_feed.
    TYPES ty_t_feed TYPE STANDARD TABLE OF ty_s_feed WITH DEFAULT KEY.

    DATA t_feed TYPE ty_t_feed.
    DATA busy TYPE abap_bool.
    DATA system_prompt TYPE string.

    DATA status_text TYPE string.
    "! bound to a MessageType, which UI5 validates even while the strip is
    "! hidden - an empty string terminates the app on the first display
    DATA status_type TYPE string VALUE `Information`.
    DATA status_visible TYPE abap_bool.
    DATA configured TYPE abap_bool.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    "! the conversation as the model sees it - raw text, oldest first. The
    "! feed is the display copy: escaped, newest first
    DATA t_history TYPE z2ui5_if_smps_llm=>ty_t_message.

    "! prompt hygiene: only the newest messages travel - a conversation
    "! grows with every turn, and so does what each turn costs
    CONSTANTS max_history TYPE i VALUE 20.

    METHODS view_display.
    METHODS on_event.
    METHODS model_init.
    METHODS config_check.

    METHODS prompt_send
      IMPORTING
        prompt TYPE string.

    METHODS answer_get.

    METHODS feed_add
      IMPORTING
        role TYPE string
        text TYPE string
        info TYPE string OPTIONAL.

    "! the three characters FormattedText reads as markup - escaped, so a
    "! model that answers with code shows the code
    METHODS html_escape
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_014 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ) IS NOT INITIAL.
      model_init( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ) IS NOT INITIAL.
      view_display( ).
    ELSEIF client->check_on_event( ) IS NOT INITIAL.
      on_event( ).
    ENDIF.

  ENDMETHOD.


  METHOD view_display.
    DATA view TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA page TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA content TYPE REF TO z2ui5_cl_ui5_view_builder.

    " every display reads the configuration again - which is what makes the
    " way back from the settings show what was saved there
    config_check( ).

    
    view = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc` ).

    
    page = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - AI / LLM - Chat`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `text`    v = `Clear Chat`
            )->a( n = `icon`    v = `sap-icon://delete`
            )->a( n = `enabled` v = |\{= !${ client->_bind( busy ) } \}|
            )->a( n = `press`   v = client->_event( `CLEAR` )
        )->tag( `Button`
            )->a( n = `text`  v = `Settings`
            )->a( n = `icon`  v = `sap-icon://action-settings`
            )->a( n = `press` v = client->_event( `SETTINGS` ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( status_text )
        )->a( n = `type`     v = client->_bind( status_type )
        )->a( n = `visible`  v = client->_bind( status_visible )
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    
    content = page->ele( `VBox`
        )->a( n = `class` v = `sapUiSmallMarginBeginEnd` ).

    content->tag( `Input`
        )->a( n = `value`       v = client->_bind( system_prompt )
        )->a( n = `placeholder` v = `Optional system prompt - how the assistant should behave`
        )->a( n = `class`       v = `sapUiSmallMarginBottom` ).

    " the typed text leaves the browser as the event argument - the
    " FeedInput clears itself after post, so its value is not bound
    content->tag( `FeedInput`
        )->a( n = `placeholder` v = `Ask the language model something...`
        )->a( n = `icon`        v = `sap-icon://customer`
        )->a( n = `enabled`     v = |\{= ${ client->_bind( configured ) } && !${ client->_bind( busy ) } \}|
        )->a( n = `post`        v = client->_event( val = `POST`
                                                    arg = `${$parameters>/value}` ) ).

    content->ele( `List`
        )->a( n = `items`              v = client->_bind( t_feed )
        )->a( n = `busy`               v = client->_bind( busy )
        )->a( n = `busyIndicatorDelay` v = `0`
        )->a( n = `showSeparators`     v = `Inner`
        )->a( n = `noDataText`         v = `No messages yet.`
        )->ele( `items`
            )->tag( `FeedListItem`
                )->a( n = `sender`       v = `{SENDER}`
                )->a( n = `text`         v = `{TEXT}`
                )->a( n = `icon`         v = `{ICON}`
                )->a( n = `info`         v = `{INFO}`
                )->a( n = `senderActive` b = abap_false
                )->a( n = `iconActive`   b = abap_false ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.
        DATA temp1 TYPE REF TO z2ui5_cl_smps_app_013.

    CASE client->get_event( ).

      WHEN `POST`.
        prompt_send( client->get_event_arg( ) ).

      WHEN `ANSWER`.
        answer_get( ).

      WHEN `CLEAR`.
        model_init( ).
        config_check( ).

      WHEN `SETTINGS`.
        
        CREATE OBJECT temp1 TYPE z2ui5_cl_smps_app_013.
        client->nav_app_call( temp1 ).

    ENDCASE.

  ENDMETHOD.


  METHOD prompt_send.
    DATA temp2 TYPE z2ui5_if_smps_llm=>ty_s_message.
    DATA temp3 TYPE string_table.

    IF prompt IS INITIAL OR busy = abap_true OR configured = abap_false.
      RETURN.
    ENDIF.

    
    CLEAR temp2.
    temp2-role = z2ui5_if_smps_llm=>cs_role-user.
    temp2-content = prompt.
    INSERT temp2 INTO TABLE t_history.
    feed_add( role = z2ui5_if_smps_llm=>cs_role-user
              text = prompt ).

    busy           = abap_true.
    status_visible = abap_false.

    " the answer comes in a SECOND roundtrip, see the class documentation -
    " the X keeps the global busy overlay down for it, so the busy feed stays
    " visible instead of disappearing behind it after a second
    
    CLEAR temp3.
    INSERT `ANSWER` INTO TABLE temp3.
    INSERT `0` INTO TABLE temp3.
    INSERT `X` INTO TABLE temp3.
    client->follow_up_action( val   = z2ui5_if_client=>cs_event-start_timer
                              t_arg = temp3 ).

  ENDMETHOD.


  METHOD answer_get.

    DATA t_send TYPE z2ui5_if_smps_llm=>ty_t_message.
    DATA first TYPE i.
    DATA message LIKE LINE OF t_history.
        DATA config TYPE z2ui5_cl_smps_llm_factory=>ty_s_config.
        DATA llm TYPE REF TO z2ui5_if_smps_llm.
        DATA answer TYPE string.
        DATA temp5 TYPE z2ui5_if_smps_llm=>ty_s_message.
        DATA temp6 TYPE string.
        DATA error TYPE REF TO z2ui5_cx_smps_llm.

    busy = abap_false.

    " the newest max_history messages, still oldest first
    
    first = nmax( val1 = 1 val2 = lines( t_history ) - max_history + 1 ).
    
    LOOP AT t_history INTO message FROM first.
      INSERT message INTO TABLE t_send.
    ENDLOOP.

    TRY.
        
        config = z2ui5_cl_smps_llm_factory=>config_read( ).
        
        llm = z2ui5_cl_smps_llm_factory=>create( config ).
        
        answer = llm->chat( system   = system_prompt
                                  messages = t_send ).

        
        CLEAR temp5.
        temp5-role = z2ui5_if_smps_llm=>cs_role-assistant.
        temp5-content = answer.
        INSERT temp5 INTO TABLE t_history.
        
        IF config-model IS INITIAL.
          temp6 = config-provider.
        ELSE.
          temp6 = config-model.
        ENDIF.
        feed_add( role = z2ui5_if_smps_llm=>cs_role-assistant
                  text = answer
                  info = temp6 ).

        
      CATCH z2ui5_cx_smps_llm INTO error.
        " the question stays in the feed and in the history - a second try
        " after fixing the setup sends it again with the next one
        status_text    = error->get_text( ).
        status_type    = `Error`.
        status_visible = abap_true.
    ENDTRY.

  ENDMETHOD.


  METHOD feed_add.

    " newest first - the order of a sap.m feed, with the FeedInput on top
    DATA temp7 TYPE z2ui5_cl_smps_app_014=>ty_s_feed.
    DATA temp1 TYPE z2ui5_cl_smps_app_014=>ty_s_feed-sender.
    DATA temp2 TYPE z2ui5_cl_smps_app_014=>ty_s_feed-icon.
    CLEAR temp7.
    
    IF role = z2ui5_if_smps_llm=>cs_role-user.
      temp1 = `You`.
    ELSE.
      temp1 = `Assistant`.
    ENDIF.
    temp7-sender = temp1.
    temp7-text = html_escape( text ).
    
    IF role = z2ui5_if_smps_llm=>cs_role-user.
      temp2 = `sap-icon://customer`.
    ELSE.
      temp2 = `sap-icon://hint`.
    ENDIF.
    temp7-icon = temp2.
    temp7-info = info.
    INSERT temp7
           INTO t_feed INDEX 1.

  ENDMETHOD.


  METHOD html_escape.

    " the ampersand FIRST, or the other two would be escaped twice
    result = replace( val = val    sub = `&` with = `&amp;` occ = 0 ).
    result = replace( val = result sub = `<` with = `&lt;`  occ = 0 ).
    result = replace( val = result sub = `>` with = `&gt;`  occ = 0 ).

  ENDMETHOD.


  METHOD config_check.

    DATA missing TYPE string.
    DATA temp1 TYPE xsdboolean.
    missing = z2ui5_cl_smps_llm_factory=>config_check( z2ui5_cl_smps_llm_factory=>config_read( ) ).
    
    temp1 = boolc( missing IS INITIAL ).
    configured = temp1.

    IF configured = abap_true.
      status_visible = abap_false.
    ELSE.
      status_text    = |{ missing } Open the settings to choose a provider, a destination and a model - | &&
                       |nothing is sent until then.|.
      status_type    = `Warning`.
      status_visible = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD model_init.

    CLEAR t_feed.
    CLEAR t_history.
    busy = abap_false.

  ENDMETHOD.

ENDCLASS.
