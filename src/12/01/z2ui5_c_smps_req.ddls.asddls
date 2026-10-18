// The projection of z2ui5_r_smps_req - the second contract on the same
// business object. Its behavior definition exposes less than the business
// object offers, see z2ui5_c_smps_req.bdef.asbdef.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'abap2UI5 RAP sample - request projection'
@Metadata.ignorePropagatedAnnotations: true
define root view entity z2ui5_c_smps_req
  provider contract transactional_query
  as projection on z2ui5_r_smps_req
{
  key RequestUuid,
      Title,
      Quantity,
      Priority,
      Status,
      Note,
      ApprovedVia,
      CreatedBy,
      CreatedAt,
      LastChangedAt
}
