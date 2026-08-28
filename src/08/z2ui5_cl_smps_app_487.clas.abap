" @keywords mime audio sound play_audio wav follow_up_action
" @summary a success and an error tone, addressed by their ICF path
CLASS z2ui5_cl_smps_app_487 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA magic_key TYPE string.
    DATA: BEGIN OF message,
            text TYPE string VALUE IS INITIAL,
            type TYPE string VALUE `None`,
          END OF message.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS view_display.
    METHODS on_event.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_487 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.

    IF client->check_on_navigated( ).
      view_display( ).
    ENDIF.

    on_event( ).

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:z2ui5`  v = `z2ui5.cc` ).

    SELECT
      SINGLE FROM icfservloc
      FIELDS icfactive
      WHERE icf_name = `MIME_DEMO`
      INTO @DATA(icfactive).

    " Note, these are demo sounds and are part of the abap2UI5 sample repo.
    " They are NOT meant to use in production.
    DATA(vbox) = view->ele( `Page`
        )->a( n = `title` v = `Play success and error sounds`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).

    IF icfactive = abap_false.
      vbox->tag( `MessageStrip`
          )->a( n = `text`    v = `ICF Service '/SAP/PUBLIC/BC/ABAP/mime_demo' is not active. Sounds will not play. Please activate the ICF service first.`
          )->a( n = `type`    v = `Warning`
          )->a( n = `visible` b = abap_true ).
    ENDIF.

    vbox->tag( `MessageStrip`
        )->a( n = `text`    v = client->_bind( message-text )
        )->a( n = `type`    v = client->_bind( message-type )
        )->a( n = `visible` v = `{= !!$` && client->_bind( message-text ) && ` }` ).
    vbox->tag( `Text`
        )->a( n = `text` v = `The magic key is: abap2UI5` ).
    vbox->tag( `Input`
        )->a( n = `id`          v = `inputApp`
        )->a( n = `placeholder` v = `Enter magic key`
        )->a( n = `value`       v = client->_bind( magic_key )
        )->a( n = `submit`      v = client->_event( `enter` ) ).
    vbox->tag( `Button`
        )->a( n = `press` v = client->_event( `enter` )
        )->a( n = `text`  v = `submit`
        )->a( n = `type`  v = `Accept` ).

    view->tag( n = `Focus` ns = `z2ui5`
        )->a( n = `focusId` v = `inputApp` ).
    client->view_display( view->stringify( ) ).

  ENDMETHOD.


  METHOD on_event.

    IF client->get_event( ) = `enter`.

      IF magic_key = `abap2UI5`.
        client->follow_up_action(
            val   = z2ui5_if_client=>cs_event-play_audio
            t_arg = VALUE #( ( `/SAP/PUBLIC/BC/ABAP/mime_demo/z2ui5_smp_success.mp3` ) ) ).
        message-type = `Success`.
        message-text = `Hooray!`.

      ELSE.
        client->follow_up_action(
            val   = z2ui5_if_client=>cs_event-play_audio
            t_arg = VALUE #( ( `/SAP/PUBLIC/BC/ABAP/mime_demo/z2ui5_smp_error.mp3` ) ) ).
        message-type = `Error`.
        message-text = `That wasn't the magic key`.
      ENDIF.
      magic_key = VALUE #( ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
