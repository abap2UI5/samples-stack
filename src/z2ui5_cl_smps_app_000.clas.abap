" @keywords overview launchpad index start nav_app_call popover all samples
" @summary every sample in this repository, grouped by what it needs from the system
"! <p class="shorttext synchronized">Overview - All Samples in This Repository</p>
"! The entry point of this repository: every sample of every package in one
"! list, one press away. Start it with ?app_start=z2ui5_cl_smps_app_000.
"!
"! The Open button of a row starts its sample in a NEW BROWSER TAB, so the
"! overview stays where it is and several samples can run side by side. That
"! is a pure frontend action: the row carries the finished ?app_start= URL of
"! its class and the button is wired with follow_up_action( ), which opens the
"! tab inside the click handler without a roundtrip - a window.open( ) from a
"! server response would be swallowed by the popup blocker.
"!
"! Every sample is referenced BY NAME and looked up at runtime, never with a
"! NEW z2ui5_cl_smps_app_&lt;no&gt;( ). A static reference would compile the whole
"! repository into this one class, and this class has to survive the two
"! cases where that is exactly what must not happen:
"!
"!   - a package the system cannot activate. src/05 needs RAP business
"!     events, src/07 needs on-premise APC - on a release or a stack without
"!     them the classes stay inactive, and a static reference would take the
"!     overview down with them instead of listing them as unavailable.
"!   - a package that is not installed at all, because the system only got
"!     part of this repository.
"!
"! So the list is complete no matter what is on the system: what is there
"! opens, what is missing says so in its Status column and keeps its Open
"! button disabled. The price is that a renamed class no longer breaks the
"! build - the CI check `npm run check:overview` covers that instead.
"!
"! The page has no header of its own: render_header( ) puts a Bar into its
"! customHeader, with the back button and the title on the left and the SHARED
"! OVERVIEW HEADER of the abap2UI5 family on the right - one core:Icon per
"! sample repository, then, set apart by a wider gap, the documentation and
"! this repository. It answers the same question per icon, and for the same reason:
"! a sibling repository is installed on its own, so an installed overview app
"! is entered with nav_app_call( ) and a missing one opens a popover saying it
"! has to be installed first, with the link to its repository. Keep it in sync
"! with the copies in abap2UI5/samples and abap2UI5/samples-controls.
CLASS z2ui5_cl_smps_app_000 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_sample,
        no        TYPE string,
        title     TYPE string,
        detail    TYPE string,
        classname TYPE string,
        "! the app URL of CLASSNAME - the frontend opens it in a new tab
        url       TYPE string,
        "! the class answered to CREATE OBJECT, so the sample can be started
        installed TYPE abap_bool,
        "! empty while INSTALLED - only the missing rows explain themselves
        status    TYPE string,
        state     TYPE string,
      END OF ty_s_sample.
    TYPES ty_t_sample TYPE STANDARD TABLE OF ty_s_sample WITH EMPTY KEY.

    "! one table per package - the order is the reading order of the README
    DATA t_odata     TYPE ty_t_sample.
    DATA t_smart     TYPE ty_t_sample.
    DATA t_rap       TYPE ty_t_sample.
    DATA t_draft     TYPE ty_t_sample.
    DATA t_events    TYPE ty_t_sample.
    DATA t_stateful  TYPE ty_t_sample.
    DATA t_websocket TYPE ty_t_sample.
    DATA t_mime      TYPE ty_t_sample.
    DATA t_launchpad TYPE ty_t_sample.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    "! at least one of the two demo data classes is on the system, so the
    "! Regenerate Demo Data button has something to call
    DATA demo_data_installed TYPE abap_bool.

    CONSTANTS:
      "! sap.ui.core.IconColor knows no blue - Positive, Critical, Negative and
      "! Neutral are the semantic four - so the interactive icons of the header
      "! carry the accent of the sap_horizon theme as a plain CSS colour, and the
      "! one that leads nowhere keeps the semantic grey
      BEGIN OF cs_color,
        active   TYPE string VALUE `#0064D9` ##NO_TEXT,
        inactive TYPE string VALUE `Neutral` ##NO_TEXT,
      END OF cs_color.

    CONSTANTS:
      BEGIN OF cs_event,
        regenerate TYPE string VALUE `REGENERATE` ##NO_TEXT,
        nav        TYPE string VALUE `NAV_APP` ##NO_TEXT,
        install    TYPE string VALUE `INSTALL` ##NO_TEXT,
      END OF cs_event.

    CONSTANTS:
      "! the overview apps of the abap2UI5 family, in the order the shared header
      "! renders them - each repository is installed on its own, so the header
      "! asks per entry whether its overview app is on THIS system
      BEGIN OF cs_overview,
        samples      TYPE string VALUE `z2ui5_cl_smp_app_000` ##NO_TEXT,
        "! the overview app of samples before its rename - an installation that
        "! predates it still answers to this name
        samples_old  TYPE string VALUE `z2ui5_cl_demo_app_g00` ##NO_TEXT,
        controls     TYPE string VALUE `z2ui5_cl_smpc_app_000` ##NO_TEXT,
        "! the overview app of samples-controls before its 2026-08 rename to
        "! the three-digit number scheme - an installation that predates it
        "! still answers to this name (the dmo-era name is older still and no
        "! longer tried)
        controls_old TYPE string VALUE `z2ui5_cl_smpc_app_overview` ##NO_TEXT,
        stack        TYPE string VALUE `z2ui5_cl_smps_app_000` ##NO_TEXT,
      END OF cs_overview.

    CONSTANTS:
      BEGIN OF cs_url,
        docs      TYPE string VALUE `https://abap2UI5.org` ##NO_TEXT,
        samples   TYPE string VALUE `https://github.com/abap2UI5/samples` ##NO_TEXT,
        controls  TYPE string VALUE `https://github.com/abap2UI5/samples-controls` ##NO_TEXT,
        stack     TYPE string VALUE `https://github.com/abap2UI5/samples-stack` ##NO_TEXT,
      END OF cs_url.

    CONSTANTS:
      "! the demo data of the two RAP packages - called by name for the same
      "! reason the samples are, see the class documentation
      BEGIN OF cs_class,
        data_trv TYPE string VALUE `Z2UI5_CL_SMPS_DATA_TRV` ##NO_TEXT,
        data_trd TYPE string VALUE `Z2UI5_CL_SMPS_DATA_TRD` ##NO_TEXT,
      END OF cs_class.

    METHODS on_event.
    METHODS view_display.
    METHODS model_init.

    "! The header every abap2UI5 overview app shares: one icon button per
    "! sample repository - it jumps into that repository's overview app when
    "! the app is on this system and says how to install it when it is not -
    "! followed by a wider gap and what leaves the system, the documentation
    "! and this repository. Exactly one entry is inactive: the repository you
    "! are looking at, there is nowhere to go from it. Keep it in sync with the
    "! copies in abap2UI5/samples and abap2UI5/samples-controls.
    METHODS render_header
      IMPORTING
        page  TYPE REF TO z2ui5_cl_ui5_view_builder
        title TYPE string.

    "! A repository that is not on this system stays clickable and says what is
    "! missing - a popover on the icon that was pressed, with the GitHub link
    "! to install it from.
    METHODS install_display
      IMPORTING
        anchor TYPE string
        href   TYPE string
        name   TYPE string.

    "! @parameter name | the entry's name - the tooltip opens with it and the
    "! popover of an uninstalled repository is titled after it
    "! @parameter class_old | the overview app's PREVIOUS name, tried when
    "! CLASS is not on the system: a repository that renamed its overview app
    "! is installed under both names in the wild for a while
    "! @parameter group_start | this entry opens a new group of the header row,
    "! so it carries the wider margin that sets the groups apart - see
    "! render_header( )
    METHODS header_button
      IMPORTING
        toolbar     TYPE REF TO z2ui5_cl_ui5_view_builder
        icon        TYPE string
        name        TYPE string
        descr       TYPE string
        href        TYPE string
        class       TYPE string OPTIONAL
        class_old   TYPE string OPTIONAL
        here        TYPE abap_bool DEFAULT abap_false
        group_start TYPE abap_bool DEFAULT abap_false.

    "! the press wire of a button whose target is EXTERNAL: a Button carries no
    "! href, and cs_event-open_new_tab is same-origin only, so the new tab is
    "! opened by the URLHELPER frontend action - client-side, inside the click
    "! handler, which is what keeps the popup blocker quiet
    METHODS open_url
      IMPORTING
        href          TYPE string
      RETURNING
        VALUE(result) TYPE string.

    "! one package each - same markup, different binding
    METHODS render_package
      IMPORTING
        page  TYPE REF TO z2ui5_cl_ui5_view_builder
        title TYPE string
        hint  TYPE string
        items TYPE string.

    "! one row of a list, including the runtime lookup of CLASSNAME
    METHODS sample
      IMPORTING
        no            TYPE string
        title         TYPE string
        detail        TYPE string
        classname     TYPE string
      RETURNING
        VALUE(result) TYPE ty_s_sample.

    "! is the class on this system and instantiable? The framework asks the
    "! same question the same way when you type a class name into its start
    "! page - an inactive or absent class raises, it does not return a flag.
    "! This is the question a SAMPLE ROW asks: its Open button starts that very
    "! class, so "can it be created" is exactly what the row reports.
    METHODS class_check_installed
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! is the class ON this system - the question the shared HEADER asks about
    "! a sibling repository, and deliberately a smaller one than
    "! class_check_installed( ), see there.
    METHODS class_check_exists
      IMPORTING
        val           TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! calls DATA_RESET on one of the demo data classes, empty if absent
    METHODS data_reset
      IMPORTING
        classname     TYPE string
      RETURNING
        VALUE(result) TYPE string.

  PRIVATE SECTION.

    " The url of a sample, built here rather than borrowed. The overview ships
    " on every generated package branch while src/00 travels only with the two
    " packages that name it in .github/packages.json, so calling
    " z2ui5_cl_smps_context left seven of the nine branches with an overview
    " that does not activate. The framework has the same helper, but in its
    " vendored utility package (src/00/03) - not released API, "renamed and
    " restructured without notice", and the linter says so. Which leaves
    " carrying it: forty lines, and the class owes nothing to anyone.
    TYPES:
      BEGIN OF ty_s_param,
        n TYPE string,
        v TYPE string,
      END OF ty_s_param.
    TYPES ty_t_param TYPE STANDARD TABLE OF ty_s_param WITH EMPTY KEY.

    "! the address of a sample: the url of the running overview with app_start
    "! exchanged, so the tab that opens lands on the same ICF node with the
    "! same parameters
    METHODS app_get_url
      IMPORTING
        classname     TYPE clike
        origin        TYPE clike
        pathname      TYPE clike
        search        TYPE clike
        hash          TYPE clike OPTIONAL
      RETURNING
        VALUE(result) TYPE string.

    METHODS url_param_get_tab
      IMPORTING
        val              TYPE clike
      RETURNING
        VALUE(rt_params) TYPE ty_t_param.

    METHODS url_param_create_url
      IMPORTING
        t_params      TYPE ty_t_param
      RETURNING
        VALUE(result) TYPE string.

ENDCLASS.


CLASS z2ui5_cl_smps_app_000 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      model_init( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ELSEIF client->check_on_navigated( ).
      " a sample the user left with the back button lands here - without
      " this branch the overview would come back blank
      view_display( ).
    ENDIF.

  ENDMETHOD.


  METHOD on_event.

    DATA li_app TYPE REF TO z2ui5_if_app.

    CASE client->get_event( ).

      WHEN cs_event-regenerate.

        " both business objects at once - the samples of src/03 run against
        " the one without draft, those of src/04 against the draft enabled
        " one, and an empty table is the most common reason a sample looks
        " broken. data_reset( ) deletes first, so the travel ids stay 1, 2, 3.
        DATA(text) = condense( |{ data_reset( cs_class-data_trv ) } { data_reset( cs_class-data_trd ) }| ).
        IF text IS INITIAL.
          text = `No demo data on this system - the two RAP packages are not installed`.
        ENDIF.
        client->message_toast_display( text ).

      WHEN cs_event-install.

        " a header icon whose repository is not on this system - anchor class,
        " GitHub URL and repository name travel as the event arguments
        install_display( anchor = client->get_event_arg( )
                         href   = client->get_event_arg( 2 )
                         name   = client->get_event_arg( 3 ) ).

      WHEN cs_event-nav.

        " a header button whose target overview app is on this system - the
        " class travels as the event argument and is resolved here, for the
        " same reason the samples are (see the class documentation)
        TRY.
            DATA(classname) = to_upper( client->get_event_arg( ) ).
            CREATE OBJECT li_app TYPE (classname).
            client->nav_app_call( li_app ).

          CATCH cx_root INTO DATA(error) ##CATCH_ALL.
            " a press that does nothing at all is the worst answer this header
            " can give, and it is what the silent catch here used to produce.
            " Only the running system knows why the overview app of the other
            " repository did not start, so let it say so.
            client->message_box_display( text = |{ classname }: { error->get_text( ) }| type = `error` ).
        ENDTRY.

    ENDCASE.

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(page) = view->ele( n = `View` ns = `mvc`
        )->a( n = `xmlns`        v = `sap.m`
        )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
        )->a( n = `xmlns:core`   v = `sap.ui.core`
        )->a( n = `displayBlock` v = `true`
        )->a( n = `height`       v = `100%`
        )->ele( `Shell`
            )->ele( `Page`
                )->a( n = `class` v = `sapUiContentPadding` ).

    " title and back button come with the custom header (render_header), not
    " with the page - a Page renders either its own header or a custom one
    render_header( page = page title = `abap2UI5 - samples-stack - 00 Overview` ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Every sample of this repository, one package per section - Open starts it ` &&
                                 `in a new browser tab. A row whose Status says so is not on this system: ` &&
                                 `either the package was not installed, or the release cannot activate it. ` &&
                                 `Everything else runs. The RAP sections need data - press Regenerate Demo ` &&
                                 `Data above if their samples look empty.`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBottom` ).

    render_package( page  = page
                    title = `01 - OData`
                    hint  = `bind a table to an OData V2 model - needs an activated OData V2 service`
                    items = client->_bind( t_odata ) ).

    render_package( page  = page
                    title = `02 - Smart Controls`
                    hint  = `sap.ui.comp driven by OData metadata - needs SAPUI5 and an activated Gateway service`
                    items = client->_bind( t_smart ) ).

    render_package( page  = page
                    title = `03 - RAP`
                    hint  = `one EML statement per sample on Z2UI5_R_SMPS_TRV - the business object ships with the package`
                    items = client->_bind( t_rap ) ).

    render_package( page  = page
                    title = `04 - RAP with Draft`
                    hint  = `Z2UI5_R_SMPS_TRD - start at 06, it carries the trick the other three reuse`
                    items = client->_bind( t_draft ) ).

    render_package( page  = page
                    title = `05 - Business Events`
                    hint  = `needs a release that already carries RAP business events - open both samples side by side`
                    items = client->_bind( t_events ) ).

    render_package( page  = page
                    title = `06 - Stateful Sessions / Locks`
                    hint  = `ABAP Standard (on-premise) - keep SM12 open next to the browser and start with 486`
                    items = client->_bind( t_stateful ) ).

    render_package( page  = page
                    title = `07 - AMC/APC`
                    hint  = `on-premise WebSockets - activate the ICF node /sap/bc/apc/sap/z2ui5_apc_smp_2`
                    items = client->_bind( t_websocket ) ).

    render_package( page  = page
                    title = `08 - MIME Play Audio`
                    hint  = `activate the ICF service /SAP/PUBLIC/BC/ABAP/mime_demo`
                    items = client->_bind( t_mime ) ).

    render_package( page  = page
                    title = `09 - Launchpad`
                    hint  = `these four show what the shell adds - start them from a launchpad tile, not from here`
                    items = client->_bind( t_launchpad ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD render_header.

    " ONLY INLINE CONTROLS BELONG INTO A sap.m.Bar. Its content containers
    " became flex boxes only after 1.71: on the oldest release abap2UI5
    " supports, .sapMBarLeft/.sapMBarRight are plain absolutely positioned
    " blocks that lay their children out in normal flow, so a block-level
    " child - a ToolbarSpacer or a ToolbarSeparator, both of which render a
    " <div> - starts a new line, and everything from that line on is cut away
    " by the overflow:hidden the container carries at the bar's height of
    " 3rem. This row used to put a ToolbarSeparator between its groups, which
    " on 1.71 swallowed every icon behind the first one; the gap now rides on
    " the first icon of each group (group_start).
    DATA(bar) = page->ele( `customHeader`
        )->ele( `Bar` ).

    " left: what the stock page header would render on its own
    DATA(left) = bar->ele( `contentLeft` ).

    left->tag( `Button`
        )->a( n = `icon`    v = `sap-icon://nav-back`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `tooltip` v = `Back`
        )->a( n = `visible` b = client->check_app_prev_stack( )
        )->a( n = `press`   v = client->_event_nav_app_leave( ) ).

    left->tag( `Title`
        )->a( n = `text`  v = title
        )->a( n = `level` v = `H2` ).

    DATA(right) = bar->ele( `contentRight` ).

    " this repository's own action first - it fills the tables the RAP samples
    " read, and it is hidden outright when neither RAP package is installed
    right->tag( `Button`
        )->a( n = `text`    v = `Regenerate Demo Data`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `visible` b = demo_data_installed
        )->a( n = `press`   v = client->_event( cs_event-regenerate ) ).

    " then the sample repositories of the abap2UI5 family, one icon each ...
    header_button( toolbar     = right
                   icon        = `sap-icon://lightbulb`
                   name        = `Samples`
                   descr       = `binding, events, popups, tables and much more`
                   class       = cs_overview-samples
                   class_old   = cs_overview-samples_old
                   href        = cs_url-samples
                   group_start = abap_true ).

    header_button( toolbar   = right
                   icon      = `sap-icon://palette`
                   name      = `Control Samples`
                   descr     = `the UI5 Demo Kit, rebuilt with abap2UI5`
                   class     = cs_overview-controls
                   class_old = cs_overview-controls_old
                   href      = cs_url-controls ).

    header_button( toolbar = right
                   icon    = `sap-icon://database`
                   name    = `Stack Samples`
                   descr   = `OData, RAP, WebSockets and the Fiori Launchpad`
                   class   = cs_overview-stack
                   href    = cs_url-stack
                   here    = abap_true ).

    " ... and then, set apart by a wider gap, the two entries that leave the
    " system: the three icons above open an app, these open a site
    header_button( toolbar     = right
                   icon        = `sap-icon://learning-assistant`
                   name        = `Documentation`
                   descr       = `guides, tutorials and the API reference`
                   href        = cs_url-docs
                   group_start = abap_true ).

    " not source-code: in the shared header that icon is reserved for the
    " per-sample source links the overviews render in their lists
    header_button( toolbar = right
                   icon    = `sap-icon://globe`
                   name    = `GitHub`
                   descr   = `the source code of this repository`
                   href    = cs_url-stack ).

  ENDMETHOD.


  METHOD install_display.

    DATA(info) = z2ui5_cl_ui5_view_builder=>factory( ).

    info->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns`      v = `sap.m`
        )->a( n = `xmlns:core` v = `sap.ui.core`

        )->ele( `Popover`
            )->a( n = `title`        v = |{ name } - not installed|
            )->a( n = `placement`    v = `Bottom`
            )->a( n = `contentWidth` v = `26rem`

            )->ele( `VBox`
                )->a( n = `class` v = `sapUiContentPadding`

                )->tag( `Text`
                    )->a( n = `text` v = |This system does not have { name } installed, so there is no app to | &&
                                         |jump to. Install the repository with abapGit, then this icon opens it right here.|
                )->tag( `Link`
                    )->a( n = `text`   v = href
                    )->a( n = `href`   v = href
                    )->a( n = `target` v = `_blank`
                    )->a( n = `class`  v = `sapUiSmallMarginTop` ).

    client->popover_display( xml = info->stringify( ) by_id = anchor ).

  ENDMETHOD.


  METHOD header_button.

    DATA target TYPE string.
    DATA hint   TYPE string.
    DATA color  TYPE string.
    DATA press  TYPE string.

    DATA(tooltip) = |{ name } - { descr }|.

    IF here = abap_true.

      " where you are: the entry stays, so every overview shows the same row,
      " but there is nowhere to go - and no press
      hint  = |{ tooltip } - you are here|.
      color = cs_color-inactive.

    ELSE.

      color = cs_color-active.

      " class_check_exists, not class_check_installed: the header asks whether
      " the sibling repository is ON this system, and instantiating its
      " overview app answers something much bigger - see the method.
      " to_upper: the repository stores class names in upper case, while the
      " constants above follow this repository's lower-case spelling of them
      IF class IS NOT INITIAL AND class_check_exists( to_upper( class ) ) = abap_true.
        target = class.
      ELSEIF class_old IS NOT INITIAL AND class_check_exists( to_upper( class_old ) ) = abap_true.
        target = class_old.
      ENDIF.

      IF target IS NOT INITIAL.
        " installed on this system: jump right into it, the back button returns
        hint  = tooltip.
        press = client->_event( val   = cs_event-nav
                                t_arg = VALUE #( ( target ) ) ).

      ELSEIF class IS INITIAL.
        " no CLASS to look for: the documentation and GitHub entries are no
        " destination inside the system to begin with, they open their site
        hint  = tooltip.
        press = open_url( href ).

      ELSE.
        " a repository that is not on this system is a normal, active entry -
        " the press says what is missing and where to get it (install_display),
        " instead of dropping the user on GitHub without a word
        hint  = |{ tooltip } - not installed on this system|.
        press = client->_event( val   = cs_event-install
                                t_arg = VALUE #( ( class )
                                                 ( href )
                                                 ( name ) ) ).
      ENDIF.

    ENDIF.

    " a core:Icon, not a Button: on 1.71 a Button cannot carry a colour - the
    " coloured sap.m.ButtonType values (Critical, Neutral, ...) are 1.73+ - and
    " the colour is what separates the active entries from the ONE inactive
    " one, the overview you are already in. Everything else is active, whether
    " its repository is on this system or not. The class name doubles as the
    " icon id, so install_display( ) can anchor its popover to the icon pressed
    " the wider begin margin is what sets a new group of the row apart - a
    " margin rather than a separator control, see render_header( )
    DATA(css_class) = COND string( WHEN group_start = abap_true
                                   THEN `sapUiMediumMarginBegin sapUiTinyMarginEnd`
                                   ELSE `sapUiTinyMarginBeginEnd` ).

    toolbar->tag( n = `Icon` ns = `core`
        )->a( n = `src`     v = icon
        )->a( n = `size`    v = `1.125rem`
        )->a( n = `class`   v = css_class
        )->a( n = `tooltip` v = hint ).

    " a( ) writes on the element just added, and an EMPTY attribute would be
    " rendered as one - id="" is not a control id, color="" is not a valid
    " IconColor and press="" is not a handler, so the three optional ones are
    " added only when they carry something. The documentation and GitHub
    " entries have no class, and the entry you are standing on has no press.
    IF class IS NOT INITIAL.
      toolbar->a( n = `id` v = class ).
    ENDIF.

    IF color IS NOT INITIAL.
      toolbar->a( n = `color` v = color ).
    ENDIF.

    IF press IS NOT INITIAL.
      toolbar->a( n = `press` v = press ).
    ENDIF.

  ENDMETHOD.


  METHOD open_url.

    " REDIRECT takes a { URL, NEW_WINDOW } object literal - NEW_WINDOW true is
    " what target="_blank" does on a Link
    result = client->follow_up_action(
                 val   = client->cs_event-urlhelper
                 t_arg = VALUE #( ( `REDIRECT` )
                                  ( |\{ URL: '{ href }', NEW_WINDOW: true \}| ) ) ).

  ENDMETHOD.


  METHOD render_package.

    " collapsible: nine packages are a long page, and most readers came for
    " one of them
    DATA(panel) = page->ele( `Panel`
        )->a( n = `headerText` v = title
        )->a( n = `expandable` v = `true`
        )->a( n = `expanded`   v = `true`
        )->a( n = `width`      v = `auto`
        )->a( n = `class`      v = `sapUiSmallMarginBottom` ).

    panel->tag( `Text`
        )->a( n = `text`  v = hint
        )->a( n = `class` v = `sapUiSmallMarginBottom` ).

    DATA(table) = panel->ele( `Table`
        )->a( n = `items` v = items ).

    table->ele( `columns`
        )->ele( `Column`
            )->a( n = `width` v = `4rem`
            )->tag( `Text`
                )->a( n = `text` v = `#`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Sample`
        )->end(
        )->ele( `Column`
            )->a( n = `demandPopin`    v = `true`
            )->a( n = `minScreenWidth` v = `Tablet`
            )->tag( `Text`
                )->a( n = `text` v = `Shows`
        )->end(
        )->ele( `Column`
            )->a( n = `demandPopin`    v = `true`
            )->a( n = `minScreenWidth` v = `Desktop`
            )->tag( `Text`
                )->a( n = `text` v = `Class`
        )->end(
        )->ele( `Column`
            )->a( n = `width` v = `9rem`
            )->tag( `Text`
                )->a( n = `text` v = `Status`
        )->end(
        )->ele( `Column`
            )->a( n = `width`  v = `7rem`
            )->a( n = `hAlign` v = `End`
            )->tag( `Text`
                )->a( n = `text` v = `Demo` ).

    table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells`
                )->tag( `Text`
                    )->a( n = `text` v = `{NO}`
                )->tag( `Text`
                    )->a( n = `text` v = `{TITLE}`
                )->tag( `Text`
                    )->a( n = `text` v = `{DETAIL}`
                )->tag( `Text`
                    )->a( n = `text` v = `{CLASSNAME}`
                )->tag( `ObjectStatus`
                    )->a( n = `text`  v = `{STATUS}`
                    )->a( n = `state` v = `{STATE}`
                )->tag( `Button`
                    )->a( n = `text` v = `Open`
                    )->a( n = `icon` v = `sap-icon://play`
                    " a sample that is not on this system has no URL worth
                    " opening - the row stays, the button does not work
                    )->a( n = `enabled` v = `{INSTALLED}`
                    " ${URL} is resolved by UI5 against the row the button
                    " sits in, so one wire serves every sample - and
                    " follow_up_action keeps it a frontend action, which is what
                    " lets the browser accept the new tab
                    )->a( n = `press` v = client->follow_up_action(
                                              val   = client->cs_event-open_new_tab
                                              t_arg = VALUE #( ( `${URL}` ) ) ) ).

  ENDMETHOD.


  METHOD sample.

    " the address the browser has to open for that class - same ICF node and
    " same url parameters as the running overview, only app_start exchanged
    DATA(s_config) = client->get( )-s_config.

    result = VALUE #( no        = no
                      title     = title
                      detail    = detail
                      classname = to_upper( classname )
                      installed = class_check_installed( classname )
                      url       = app_get_url( classname = classname
                                               origin    = s_config-origin
                                               pathname  = s_config-pathname
                                               search    = s_config-search
                                               hash      = s_config-hash ) ).

    " an enum typed property rejects the empty string, so the rows that are
    " fine say None rather than nothing
    result-state  = COND #( WHEN result-installed = abap_true THEN `None` ELSE `Warning` ).
    result-status = COND #( WHEN result-installed = abap_true THEN `` ELSE `not on this system` ).

  ENDMETHOD.


  METHOD class_check_installed.

    DATA obj TYPE REF TO object ##NEEDED.

    TRY.
        CREATE OBJECT obj TYPE (val).
        result = abap_true.
      CATCH cx_root ##CATCH_ALL.
        " absent, inactive, or not activatable on this release - for a sample
        " row these are the same answer: it cannot be started
        result = abap_false.
    ENDTRY.

  ENDMETHOD.


  METHOD class_check_exists.

    " Existence, and nothing else - the same question the framework's start
    " page asks (z2ui5_cl_ui5_util_context=>rtti_check_class_exists). The
    " header used class_check_installed( ) for this, which loads the whole
    " class pool of the OTHER repository's overview app together with
    " everything it statically references, and runs its constructor. Every
    " failure in there - a helper class of that repository the release cannot
    " activate, a repository that landed on the system only in part - came back
    " as "not installed on this system", so the icon offered the abapGit link
    " for a repository that is sitting right there and refused to navigate.
    " Whether the app then starts is the navigation's question, and since the
    " silent catch there is gone it says why when it cannot.
    TRY.
        cl_abap_classdescr=>describe_by_name( EXPORTING  p_name         = val
                                              EXCEPTIONS type_not_found = 1 ).
        IF sy-subrc = 0.
          result = abap_true.
        ENDIF.

      CATCH cx_root ##CATCH_ALL.
        result = abap_false.
    ENDTRY.

  ENDMETHOD.


  METHOD data_reset.

    TRY.
        CALL METHOD (classname)=>('DATA_RESET')
          RECEIVING
            result = result.
      CATCH cx_root ##CATCH_ALL.
        CLEAR result.
    ENDTRY.

  ENDMETHOD.


  METHOD model_init.

    demo_data_installed = xsdbool( class_check_installed( cs_class-data_trv ) = abap_true
                                OR class_check_installed( cs_class-data_trd ) = abap_true ).

    t_odata = VALUE #(
      ( sample( no        = `315`
                title     = `Two OData models in one view`
                detail    = `one table bound to each, column headers from the metadata`
                classname = `Z2UI5_CL_SMPS_APP_315` ) ) ).

    t_smart = VALUE #(
      ( sample( no        = `313`
                title     = `SmartFilterBar and SmartTable`
                detail    = `with variant management - UI_PRODUCTLIST`
                classname = `Z2UI5_CL_SMPS_APP_313` ) )
      ( sample( no        = `314`
                title     = `Switch the default model`
                detail    = `device, HTTP and OData model side by side - GWSAMPLE_BASIC`
                classname = `Z2UI5_CL_SMPS_APP_314` ) )
      ( sample( no        = `319`
                title     = `SmartMultiInput to SELECT-OPTIONS`
                detail    = `UI conditions mapped 1:1 onto an ABAP range table`
                classname = `Z2UI5_CL_SMPS_APP_319` ) )
      ( sample( no        = `475`
                title     = `SmartField inside a SmartForm`
                detail    = `needs the GWSAMPLE_BASIC OData service`
                classname = `Z2UI5_CL_SMPS_APP_475` ) )
      ( sample( no        = `476`
                title     = `SmartForm, display/edit toggle`
                detail    = `needs the GWSAMPLE_BASIC OData service`
                classname = `Z2UI5_CL_SMPS_APP_476` ) )
      ( sample( no        = `477`
                title     = `SmartFilterBar driving a SmartTable`
                detail    = `needs the GWSAMPLE_BASIC OData service`
                classname = `Z2UI5_CL_SMPS_APP_477` ) )
      ( sample( no        = `478`
                title     = `Page variant management`
                detail    = `needs the GWSAMPLE_BASIC OData service`
                classname = `Z2UI5_CL_SMPS_APP_478` ) )
      ( sample( no        = `479`
                title     = `SmartChart with NavigationPopover`
                detail    = `an analytical service - you supply the path`
                classname = `Z2UI5_CL_SMPS_APP_479` ) )
      ( sample( no        = `493`
                title     = `Classic FilterBar with variant management`
                detail    = `no service needed - the data is ABAP`
                classname = `Z2UI5_CL_SMPS_APP_493` ) ) ).

    t_rap = VALUE #(
      ( sample( no        = `001`
                title     = `Read a travel`
                detail    = `reads one instance by its key - a missing key comes back in FAILED, not as an exception`
                classname = `Z2UI5_CL_SMPS_APP_001` ) )
      ( sample( no        = `002`
                title     = `Create a travel`
                detail    = `MODIFY ... CREATE, key from MAPPED`
                classname = `Z2UI5_CL_SMPS_APP_002` ) )
      ( sample( no        = `003`
                title     = `Update a travel`
                detail    = `changes single fields of one instance - UPDATE FIELDS names what may be touched`
                classname = `Z2UI5_CL_SMPS_APP_003` ) )
      ( sample( no        = `004`
                title     = `Delete a travel`
                detail    = `deletes one instance - MODIFY ... DELETE FROM`
                classname = `Z2UI5_CL_SMPS_APP_004` ) )
      ( sample( no        = `005`
                title     = `Manage travels - the complete app`
                detail    = `01-04 plus EXECUTE and COMMIT ENTITIES RESPONSE OF`
                classname = `Z2UI5_CL_SMPS_APP_005` ) ) ).

    t_draft = VALUE #(
      ( sample( no        = `006`
                title     = `Which travels have a draft?`
                detail    = `READ ... %is_draft = mk-on`
                classname = `Z2UI5_CL_SMPS_APP_006` ) )
      ( sample( no        = `007`
                title     = `Enter draft mode`
                detail    = `Edit copies the active instance into a new draft, Resume picks up an existing one`
                classname = `Z2UI5_CL_SMPS_APP_007` ) )
      ( sample( no        = `008`
                title     = `Change and save a draft`
                detail    = `UPDATE ... %is_draft = mk-on`
                classname = `Z2UI5_CL_SMPS_APP_008` ) )
      ( sample( no        = `009`
                title     = `Leave draft mode`
                detail    = `EXECUTE Activate / Discard`
                classname = `Z2UI5_CL_SMPS_APP_009` ) )
      ( sample( no        = `010`
                title     = `Manage travels with draft - the complete app`
                detail    = `a whole app, not a snippet - the complete draft lifecycle in one screen`
                classname = `Z2UI5_CL_SMPS_APP_010` ) ) ).

    t_events = VALUE #(
      ( sample( no        = `011`
                title     = `Create tickets through the BO`
                detail    = `every create and update raises an entity event`
                classname = `Z2UI5_CL_SMPS_APP_011` ) )
      ( sample( no        = `012`
                title     = `The event log`
                detail    = `what the handler wrote, newest first`
                classname = `Z2UI5_CL_SMPS_APP_012` ) ) ).

    t_stateful = VALUE #(
      ( sample( no        = `486`
                title     = `The basics - a counter in a static container`
                detail    = `counts up while the session is stateful, starts over once it is not`
                classname = `Z2UI5_CL_SMPS_APP_486` ) )
      ( sample( no        = `485`
                title     = `Set and read an ENQUEUE lock`
                detail    = `ENQUEUE_E_TABLE and ENQUEUE_READ, end and restart the session`
                classname = `Z2UI5_CL_SMPS_APP_485` ) )
      ( sample( no        = `490`
                title     = `One lock per screen`
                detail    = `every Next Lock View takes the next VARKEY, going back releases it`
                classname = `Z2UI5_CL_SMPS_APP_490` ) ) ).

    t_websocket = VALUE #(
      ( sample( no        = `489`
                title     = `A news feed over WebSocket`
                detail    = `connect, publish, list the active connections - no JavaScript`
                classname = `Z2UI5_CL_SMPS_APP_489` ) ) ).

    t_mime = VALUE #(
      ( sample( no        = `487`
                title     = `Play a sound from the MIME repository`
                detail    = `a success and an error tone, addressed by their ICF path`
                classname = `Z2UI5_CL_SMPS_APP_487` ) ) ).

    t_launchpad = VALUE #(
      ( sample( no        = `481`
                title     = `Read the startup parameters`
                detail    = `what the tile passed in - client->get( )-t_comp_params`
                classname = `Z2UI5_CL_SMPS_APP_481` ) )
      ( sample( no        = `482`
                title     = `Set the shell title`
                detail    = `follow_up_action( cs_event-set_title_launchpad )`
                classname = `Z2UI5_CL_SMPS_APP_482` ) )
      ( sample( no        = `483`
                title     = `Cross-app navigation - sender`
                detail    = `hands two values over to another tile`
                classname = `Z2UI5_CL_SMPS_APP_483` ) )
      ( sample( no        = `484`
                title     = `Cross-app navigation - receiver`
                detail    = `reads them back out of its startup parameters`
                classname = `Z2UI5_CL_SMPS_APP_484` ) ) ).

  ENDMETHOD.


  METHOD app_get_url.

    DATA(lt_param) = url_param_get_tab( search ).
    DELETE lt_param WHERE n = `app_start`.
    INSERT VALUE #( n = `app_start` v = to_lower( classname ) ) INTO TABLE lt_param.

    " keep only the launchpad shell part of the hash: the app-owned part
    " (leading `/` standalone, or everything after `&/` inside the FLP)
    " carries THIS app's route/app-state, which the backend prefers over
    " app_start - appending it verbatim would re-open the overview instead of
    " the sample that was asked for
    DATA(lv_hash) = CONV string( hash ).
    IF lv_hash IS NOT INITIAL.
      DATA(lv_content) = lv_hash.
      IF lv_content(1) = `#`.
        lv_content = substring( val = lv_content off = 1 ).
      ENDIF.
      IF lv_content IS INITIAL OR lv_content(1) = `/`.
        " pure app hash (route or app-state) - drop it entirely
        lv_hash = ``.
      ELSE.
        " inside the FLP keep the shell part, cut the app part after `&/`
        DATA(lv_off) = find( val = lv_content sub = `&/` ).
        IF lv_off = 0.
          lv_hash = ``.
        ELSEIF lv_off > 0.
          lv_hash = |#{ lv_content(lv_off) }|.
        ELSE.
          lv_hash = |#{ lv_content }|.
        ENDIF.
      ENDIF.
    ENDIF.

    result = |{ origin }{ pathname }?| && url_param_create_url( lt_param ) && lv_hash.

  ENDMETHOD.


  METHOD url_param_get_tab.

    DATA(lv_search) = replace( val  = val
                               sub  = `%3D`
                               with = `=`
                               occ  = 0 ).

    " RFC 3986 allows lowercase hex digits in percent-encodings, so decode
    " %3d the same way as %3D (%26 contains no letters and needs no twin)
    lv_search = replace( val  = lv_search
                         sub  = `%3d`
                         with = `=`
                         occ  = 0 ).

    lv_search = replace( val  = lv_search
                         sub  = `%26`
                         with = `&`
                         occ  = 0 ).

    lv_search = shift_left( val = lv_search sub = `?` ).

    " prepend & before searching so sap-startup-params is also unwrapped
    " when it is the first/only query parameter (typical FLP target mapping)
    DATA(lv_search2) = substring_after( val = |&{ lv_search }| sub = `&sap-startup-params=` ).
    lv_search = COND #( WHEN lv_search2 IS NOT INITIAL THEN lv_search2 ELSE lv_search ).

    lv_search2 = substring_after( val = lv_search sub = `?` ).
    IF lv_search2 IS NOT INITIAL.
      lv_search = lv_search2.
    ENDIF.

    SPLIT lv_search AT `&` INTO TABLE DATA(lt_param).

    LOOP AT lt_param REFERENCE INTO DATA(lr_param).
      SPLIT lr_param->* AT `=` INTO DATA(lv_name) DATA(lv_value).
      " an empty segment (empty search string, trailing &) would otherwise
      " produce a phantom nameless parameter that url_param_create_url
      " writes back out as a stray `=&`
      IF lv_name IS INITIAL.
        CONTINUE.
      ENDIF.
      " normalize the name so the app_start lookup is case-insensitive on
      " every input shape - the value keeps its original case
      INSERT VALUE #( n = to_lower( condense( lv_name ) ) v = lv_value ) INTO TABLE rt_params.
    ENDLOOP.

  ENDMETHOD.


  METHOD url_param_create_url.

    LOOP AT t_params INTO DATA(ls_param).
      result = |{ result }{ ls_param-n }={ ls_param-v }&|.
    ENDLOOP.
    result = shift_right( val = result sub = `&` ).

  ENDMETHOD.

ENDCLASS.
