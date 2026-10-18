"! <p class="shorttext synchronized">abap2UI5 RAP sample - request permissions</p>
"! Asks the business object z2ui5_r_smps_req which operations its feature
"! control allows per request - the one GET PERMISSIONS statement of package
"! 12, kept in a class of its own because abaplint has no grammar for it (see
"! the noIssues entry in abaplint.jsonc). z2ui5_cl_smps_app_017 calls it.
CLASS z2ui5_cl_smps_perm_req DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES ty_t_uuid TYPE STANDARD TABLE OF z2ui5_t_smps_req-request_uuid WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_s_permission,
        request_uuid TYPE z2ui5_t_smps_req-request_uuid,
        update       TYPE abap_bool,
        delete       TYPE abap_bool,
        approve      TYPE abap_bool,
        reject       TYPE abap_bool,
      END OF ty_s_permission.
    TYPES ty_t_permission TYPE STANDARD TABLE OF ty_s_permission WITH EMPTY KEY.

    "! one row per request the business object knows - a key it does not
    "! know is left out
    CLASS-METHODS get
      IMPORTING
        t_uuid        TYPE ty_t_uuid
      RETURNING
        VALUE(result) TYPE ty_t_permission.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS z2ui5_cl_smps_perm_req IMPLEMENTATION.

  METHOD get.

    IF t_uuid IS INITIAL.
      RETURN.
    ENDIF.

    " ONLY INSTANCE FEATURES restricts the question to feature control - GET
    " PERMISSIONS can also ask for the authorizations, global and per
    " instance. REQUEST names what we want to know; what is not requested
    " comes back initial.
    GET PERMISSIONS ONLY INSTANCE FEATURES OF z2ui5_r_smps_req
      ENTITY request
      FROM VALUE #( FOR uuid IN t_uuid ( requestuuid = uuid ) )
      REQUEST VALUE #( %update         = if_abap_behv=>mk-on
                       %delete         = if_abap_behv=>mk-on
                       %action-approve = if_abap_behv=>mk-on
                       %action-reject  = if_abap_behv=>mk-on )
      RESULT DATA(s_permissions).

    result = VALUE #( FOR s_instance IN s_permissions-instances
                      ( request_uuid = s_instance-requestuuid
                        update       = xsdbool( s_instance-%update = if_abap_behv=>fc-o-enabled )
                        delete       = xsdbool( s_instance-%delete = if_abap_behv=>fc-o-enabled )
                        approve      = xsdbool( s_instance-%action-approve = if_abap_behv=>fc-o-enabled )
                        reject       = xsdbool( s_instance-%action-reject = if_abap_behv=>fc-o-enabled ) ) ).

  ENDMETHOD.

ENDCLASS.
