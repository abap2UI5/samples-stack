// The parameter of the static factory action createRequest of
// z2ui5_r_smps_req - everything a new request is created from.
@EndUserText.label: 'abap2UI5 sample - create parameter'
define abstract entity z2ui5_a_smps_req_create
{
  Title    : abap.char(60);
  Quantity : abap.int4;
  Priority : abap.char(1);
}
