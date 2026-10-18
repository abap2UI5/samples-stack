// The parameter of the action reject of z2ui5_r_smps_req: why the request
// was rejected. It is stored in the field Note of the request.
@EndUserText.label: 'abap2UI5 sample - reject parameter'
define abstract entity z2ui5_a_smps_req_reject
{
  Reason : abap.char(255);
}
