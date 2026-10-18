@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'abap2UI5 RAP sample - request'
@Metadata.ignorePropagatedAnnotations: true
define root view entity z2ui5_r_smps_req
  as select from z2ui5_t_smps_req
{
  key request_uuid    as RequestUuid,

      title           as Title,
      quantity        as Quantity,
      priority        as Priority,
      status          as Status,
      note            as Note,
      approved_via    as ApprovedVia,

      @Semantics.user.createdBy: true
      created_by      as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      last_changed_at as LastChangedAt
}
