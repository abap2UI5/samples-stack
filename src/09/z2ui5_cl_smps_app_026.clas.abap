" @keywords launchpad fiori flp smart link popover getlinks intent semantic object cross_app_nav_get_links
" @summary a list of products whose ids are smart links - a press asks the launchpad which apps the user may open for the product and lists them in a popover
"! <p class="shorttext synchronized">Launchpad - Smart Link Popover with getLinks</p>
"! A Fiori elements list shows a key as a smart link: a press opens a
"! popover with every app the user may open for the object, each called
"! with the row's keys. Which apps those are depends on the user's roles
"! and catalogs, so only the launchpad knows - the backend asks it with
"! the frontend action cs_event-cross_app_nav_get_links:
"!
"!     client->follow_up_action(
"!         val   = client->cs_event-cross_app_nav_get_links
"!         t_arg = VALUE #( ( `{"semanticObject":"Z2UI5_CL_LP_SAMPLE_04"}` )
"!                          ( `{"PRODUCT":"102343333","QUANTITY":"500"}` )
"!                          ( `LINKS_READ` ) ) ).
"!
"! The answer arrives as the event LINKS_READ, its argument a JSON array
"! with one object per intent - intent (the hash), text, subTitle. The
"! sample lists them in a popover next to the pressed link, and a press on
"! an entry navigates there with cs_event-cross_app_nav_to_ext and the
"! hash as shellHash target.
"!
"! Needs abap2UI5 newer than 1.148.0 (cross_app_nav_get_links) and a
"! launchpad. The default semantic object is the one of the receiver
"! z2ui5_cl_smps_app_484, so the target mapping the package README sets up
"! for it is all the sample needs - the popover then lists the receiver,
"! which shows the product and quantity of the pressed row.
CLASS z2ui5_cl_smps_app_026 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_product,
        product  TYPE string,
        name     TYPE string,
        quantity TYPE string,
      END OF ty_s_product.
    TYPES ty_t_product TYPE STANDARD TABLE OF ty_s_product WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_s_link,
        intent    TYPE string,
        text      TYPE string,
        sub_title TYPE string,
      END OF ty_s_link.
    TYPES ty_t_link TYPE STANDARD TABLE OF ty_s_link WITH DEFAULT KEY.

    DATA semantic_object TYPE string.
    DATA t_products      TYPE ty_t_product.

    "! the intents of the last answer
    DATA t_links         TYPE ty_t_link.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    "! the row the intents were asked for
    DATA s_product TYPE ty_s_product.

    "! the id of the pressed link - the popover opens next to it
    DATA anchor TYPE string.

    METHODS view_display.
    METHODS on_event_links.
    METHODS on_event_links_read.
    METHODS on_event_navigate.

    METHODS on_event.
    METHODS popover_display.

  PRIVATE SECTION.

    "! reads the string value behind marker, searching from offset - which
    "! is moved behind the value, or set to -1 when there is none
    METHODS json_read_string
      IMPORTING
        json   TYPE string
        marker TYPE string
      EXPORTING
        result TYPE string
      CHANGING
        offset TYPE i.

    METHODS json_escape
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_smps_app_026 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.
      DATA temp1 TYPE z2ui5_cl_smps_app_026=>ty_t_product.
      DATA temp2 LIKE LINE OF temp1.

    me->client = client.
    IF client->check_on_init( ) IS NOT INITIAL.

      semantic_object = `Z2UI5_CL_LP_SAMPLE_04`.
      
      CLEAR temp1.
      
      temp2-product = `102343333`.
      temp2-name = `Notebook Basic 15`.
      temp2-quantity = `500`.
      INSERT temp2 INTO TABLE temp1.
      temp2-product = `102343334`.
      temp2-name = `Notebook Basic 17`.
      temp2-quantity = `25`.
      INSERT temp2 INTO TABLE temp1.
      temp2-product = `102343335`.
      temp2-name = `Ergo Screen E-I`.
      temp2-quantity = `3`.
      INSERT temp2 INTO TABLE temp1.
      t_products = temp1.

      IF client->get( )-check_launchpad_active = abap_false.
        client->message_box_display( `No Launchpad Active, Sample not working!` ).
      ENDIF.
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
    DATA temp1 TYPE xsdboolean.
    DATA table TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA temp3 TYPE string_table.
    view = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    
    
    temp1 = boolc( client->get( )-check_launchpad_active = abap_false ).
    page = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - Launchpad - Smart Link Popover with getLinks`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( )
            )->a( n = `showHeader`     b = temp1 ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Press a product: follow_up_action( cs_event-cross_app_nav_get_links ) asks the ` &&
                                 `launchpad which apps the user may open for the semantic object with the row's ` &&
                                 `PRODUCT and QUANTITY, and the popover lists what it answers - a press on an entry ` &&
                                 `navigates there with cs_event-cross_app_nav_to_ext. Only works inside a launchpad; ` &&
                                 `with the target mapping of z2ui5_cl_smps_app_484 the receiver is in the list.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `The links of`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `Semantic Object`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( semantic_object ) ).

    
    table = page->ele( `Table`
        )->a( n = `items` v = client->_bind( t_products ) ).
    table->ele( `headerToolbar`
        )->ele( `Toolbar`
            )->tag( `Title`
                )->a( n = `text` v = `Products` ).
    table->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Product`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Name`
        )->end(
        )->ele( `Column`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Quantity` ).
    
    CLEAR temp3.
    INSERT `${$source>/id}` INTO TABLE temp3.
    INSERT `${PRODUCT}` INTO TABLE temp3.
    INSERT `${NAME}` INTO TABLE temp3.
    INSERT `${QUANTITY}` INTO TABLE temp3.
    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Link`
                    )->a( n = `text`  v = `{PRODUCT}`
                    )->a( n = `press` v = client->_event( val   = `LINKS`
                                                          t_arg = temp3 )
                )->tag( `Text`
                    )->a( n = `text` v = `{NAME}`
                )->tag( `Text`
                    )->a( n = `text` v = `{QUANTITY}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    CASE client->get_event( ).
      WHEN `LINKS`.
        on_event_links( ).
      WHEN `LINKS_READ`.
        " raised by the frontend once getLinks has answered - named in the
        " third argument of cross_app_nav_get_links in on_event_links( )
        on_event_links_read( ).
      WHEN `NAVIGATE`.
        on_event_navigate( ).
    ENDCASE.

  ENDMETHOD.


  METHOD on_event_links.
    DATA temp5 TYPE string_table.
    DATA temp1 LIKE LINE OF temp5.
    DATA temp2 LIKE LINE OF temp5.

    " the pressed link and its row - the popover opens next to the link
    " once the launchpad has answered, in the roundtrip of LINKS_READ
    anchor = client->get_event_arg( ).
    CLEAR s_product.
    s_product-product = client->get_event_arg( 2 ).
    s_product-name = client->get_event_arg( 3 ).
    s_product-quantity = client->get_event_arg( 4 ).

    " target, intent parameters, the event that receives the answer - the
    " parameters are the keys the target mappings expect, so an intent that
    " needs one the row does not have is not offered
    
    CLEAR temp5.
    
    temp1 = |\{"semanticObject":"{ json_escape( semantic_object ) }"\}|.
    INSERT temp1 INTO TABLE temp5.
    
    temp2 = |\{"PRODUCT":"{ json_escape( s_product-product ) }",| && |"QUANTITY":"{ json_escape( s_product-quantity ) }"\}|.
    INSERT temp2 INTO TABLE temp5.
    INSERT `LINKS_READ` INTO TABLE temp5.
    client->follow_up_action(
        val   = client->cs_event-cross_app_nav_get_links
        t_arg = temp5 ).

  ENDMETHOD.


  METHOD on_event_links_read.

    " [{"intent":"#SO-action?PRODUCT=...","text":"...","subTitle":"...",
    "   "semanticObject":"SO","action":"action","params":{...}}, ...]
    " - written by the framework, one object per intent and intent always
    " its first key, so the walk takes the three strings it shows in order
    " and leaves the split parts alone
    DATA json TYPE string.
    DATA offset TYPE i.
    DATA s_link TYPE ty_s_link.
    json = client->get_event_arg( ).
    
    offset = 0.
    

    CLEAR t_links.
    DO.
      CLEAR s_link.
      json_read_string( EXPORTING json   = json
                                  marker = `{"intent":"`
                        IMPORTING result = s_link-intent
                        CHANGING  offset = offset ).
      IF offset < 0.
        EXIT.
      ENDIF.
      json_read_string( EXPORTING json   = json
                                  marker = `"text":"`
                        IMPORTING result = s_link-text
                        CHANGING  offset = offset ).
      IF offset < 0.
        EXIT.
      ENDIF.
      json_read_string( EXPORTING json   = json
                                  marker = `"subTitle":"`
                        IMPORTING result = s_link-sub_title
                        CHANGING  offset = offset ).
      IF offset < 0.
        EXIT.
      ENDIF.
      INSERT s_link INTO TABLE t_links.
    ENDDO.

    popover_display( ).

  ENDMETHOD.


  METHOD on_event_navigate.

    " the hash exactly as getLinks returned it - hrefForExternal takes a
    " shellHash target as it is, parameters included
    DATA intent TYPE string.
    DATA temp7 TYPE string_table.
    DATA temp3 LIKE LINE OF temp7.
    intent = client->get_event_arg( ).

    client->popover_destroy( ).
    
    CLEAR temp7.
    
    temp3 = |\{"shellHash":"{ json_escape( intent ) }"\}|.
    INSERT temp3 INTO TABLE temp7.
    client->follow_up_action(
        val   = client->cs_event-cross_app_nav_to_ext
        t_arg = temp7 ).

  ENDMETHOD.


  METHOD json_read_string.
    DATA start TYPE i.
    DATA pos TYPE i.
    DATA length TYPE i.
      DATA char TYPE string.
      DATA escaped TYPE string.

    CLEAR result.
    
    start = find( val = json sub = marker off = offset ).
    IF start < 0.
      offset = -1.
      RETURN.
    ENDIF.

    
    pos    = start + strlen( marker ).
    
    length = strlen( json ).

    " walked rather than cut at the next quote: a quote inside the value
    " stands in the JSON as \" and would end it early
    WHILE pos < length.
      
      char = substring( val = json off = pos len = 1 ).
      pos = pos + 1.

      IF char = `"`.
        offset = pos.
        RETURN.
      ENDIF.

      IF char <> `\`.
        result = result && char.
        CONTINUE.
      ENDIF.

      " an escape - a backslash at the very end is a truncated payload
      IF pos >= length.
        EXIT.
      ENDIF.
      
      escaped = substring( val = json off = pos len = 1 ).
      pos = pos + 1.

      CASE escaped.
        WHEN `n`.
          result = result && |\n|.
        WHEN `t`.
          result = result && |\t|.
        WHEN OTHERS.
          " `"`, `\` and `/` stand for themselves
          result = result && escaped.
      ENDCASE.
    ENDWHILE.

    " no closing quote
    offset = -1.

  ENDMETHOD.


  METHOD json_escape.

    result = replace( val = val sub = `\` with = `\\` occ = 0 ).
    result = replace( val = result sub = `"` with = `\"` occ = 0 ).

  ENDMETHOD.


  METHOD popover_display.

    DATA popover TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA list TYPE REF TO z2ui5_cl_ui5_view_builder.
    popover = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`      v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).
    
    list = popover->ele( `Popover`
        )->a( n = `title`         t = |{ s_product-name } ({ s_product-product })|
        )->a( n = `placement`     v = `Auto`
        )->a( n = `contentWidth`  v = `20rem`
        )->ele( `List`
            )->a( n = `items`       v = client->_bind( t_links )
            )->a( n = `noDataText`  t = |The launchpad offers you no app for { semantic_object }.| ).
    list->ele( `StandardListItem`
        )->a( n = `title`       v = `{TEXT}`
        )->a( n = `description` v = `{SUB_TITLE}`
        )->a( n = `type`        v = `Navigation`
        )->a( n = `press`       v = client->_event( val = `NAVIGATE`
                                                    arg = `${INTENT}` ) ).

    client->popover_display( xml = popover->stringify( ) by_id = anchor ).

  ENDMETHOD.

ENDCLASS.
