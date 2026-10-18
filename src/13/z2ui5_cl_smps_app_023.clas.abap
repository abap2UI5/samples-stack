" @keywords email mail send attachment xlsx excel cl_bcs_mail_message smtp
" @summary A mail with an .xlsx attachment, sent with cl_bcs_mail_message - recipient, subject and text from the screen, the attachment written with the XCO XLSX library
"! <p class="shorttext synchronized">E-Mail - Send a Table as XLSX Attachment</p>
"! cl_bcs_mail_message is the mail API of ABAP Cloud:
"!
"!     DATA(mail) = cl_bcs_mail_message=>create_instance( ).
"!     mail->set_sender( sender ).
"!     mail->add_recipient( recipient ).
"!     mail->set_subject( subject ).
"!     mail->set_main( cl_bcs_mail_textpart=>create_text_plain( text ) ).
"!     mail->add_attachment( cl_bcs_mail_binarypart=>create_instance(
"!         iv_content      = xlsx
"!         iv_content_type = mime_type
"!         iv_filename     = `products.xlsx` ) ).
"!     mail->send( IMPORTING ev_mail_status = DATA(status) ).
"!
"! The mail leaves the system through its outbound mail configuration - on
"! ABAP Cloud a communication arrangement for SAP_COM_0548, on-premise SMTP
"! in transaction SCOT. Without one the send fails, and the app says why.
CLASS z2ui5_cl_smps_app_023 DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA sender    TYPE string.
    DATA recipient TYPE string.
    DATA subject   TYPE string.
    DATA text      TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.

    METHODS mail_send.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_app_023 IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      subject = `Products as XLSX`.
      text    = |Hello,\n\nthe current product list is attached.\n\nSent from an abap2UI5 app.|.
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( `SEND` ).
      mail_send( ).
    ENDIF.

  ENDMETHOD.


  METHOD mail_send.

    IF sender IS INITIAL OR recipient IS INITIAL.
      client->message_box_display( text = `Sender and recipient are both needed` type = `error` ).
      RETURN.
    ENDIF.

    " the attachment - written exactly as z2ui5_cl_smps_app_022 writes it
    DATA(xlsx) = z2ui5_cl_smps_xlsx=>write( VALUE #(
        ( a = `Product` b = `Quantity` c = `Price` d = `Currency` )
        ( a = `Notebook` b = `2` c = `899.00` d = `EUR` )
        ( a = `Docking station` b = `2` c = `189.50` d = `EUR` )
        ( a = `Headset` b = `5` c = `79.90` d = `EUR` ) ) ).

    TRY.
        DATA(mail) = cl_bcs_mail_message=>create_instance( ).
        mail->set_sender( CONV #( sender ) ).
        mail->add_recipient( CONV #( recipient ) ).
        mail->set_subject( CONV #( subject ) ).
        mail->set_main( cl_bcs_mail_textpart=>create_text_plain( text ) ).
        mail->add_attachment( cl_bcs_mail_binarypart=>create_instance(
                                  iv_content      = xlsx
                                  iv_content_type = CONV #( z2ui5_cl_smps_xlsx=>mime_type )
                                  iv_filename     = `products.xlsx` ) ).

        " the send hands the mail to the outbound queue - the status says
        " whether it left already or is still waiting there
        mail->send( IMPORTING ev_mail_status = DATA(status) ).

        client->message_box_display( text = |Mail handed over to the mail system, status { status }| type = `success` ).

      CATCH cx_bcs_mail INTO DATA(error).
        " an invalid address, or no outbound mail configured on this system
        client->message_box_display( text = error->get_text( ) type = `error` ).
    ENDTRY.

  ENDMETHOD.


  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form` ).
    DATA(page) = view->ele( `Shell`
        )->ele( `Page`
            )->a( n = `title`          v = `abap2UI5 - E-Mail - 23 Send a Table as XLSX Attachment`
            )->a( n = `showNavButton`  b = client->check_app_prev_stack( )
            )->a( n = `navButtonPress` v = client->_event_nav_app_leave( ) ).

    page->tag( `MessageStrip`
        )->a( n = `text`     v = `Sends a mail with the product list as .xlsx attachment through cl_bcs_mail_message. The ` &&
                                 `system needs outbound mail configured - a communication arrangement for SAP_COM_0548 ` &&
                                 `on ABAP Cloud, SMTP in SCOT on-premise.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` b = abap_true
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    page->ele( n = `SimpleForm` ns = `form`
        )->a( n = `title`    v = `cl_bcs_mail_message`
        )->a( n = `editable` b = abap_true
        )->ele( n = `content` ns = `form`
            )->tag( `Label`
                )->a( n = `text` v = `From`
            )->tag( `Input`
                )->a( n = `value`       v = client->_bind( sender )
                )->a( n = `type`        v = `Email`
                )->a( n = `placeholder` v = `a sender address your mail configuration allows`
            )->tag( `Label`
                )->a( n = `text` v = `To`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( recipient )
                )->a( n = `type`  v = `Email`
            )->tag( `Label`
                )->a( n = `text` v = `Subject`
            )->tag( `Input`
                )->a( n = `value` v = client->_bind( subject )
            )->tag( `Label`
                )->a( n = `text` v = `Text`
            )->tag( `TextArea`
                )->a( n = `value` v = client->_bind( text )
                )->a( n = `rows`  v = `6`
            )->tag( `Label`
                )->a( n = `text` v = `Attachment`
            )->tag( `Text`
                )->a( n = `text` v = `products.xlsx - four products, written with XCO` ).

    page->ele( `footer`
        )->ele( `OverflowToolbar`
            )->tag( `ToolbarSpacer`
            )->tag( `Button`
                )->a( n = `press` v = client->_event( `SEND` )
                )->a( n = `text`  v = `Send`
                )->a( n = `icon`  v = `sap-icon://email`
                )->a( n = `type`  v = `Emphasized` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
