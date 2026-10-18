// The parameter of the static action uploadFile of z2ui5_r_smps_fil. An
// action parameter is a flat structure - a file does not fit into one - so
// the file travels in a second abstract entity, reached through the
// association below. That is what makes the parameter DEEP: the behavior
// definition of this entity says "with hierarchy", the action says
// "deep parameter", and EML hands both levels over in one %param.
@EndUserText.label: 'abap2UI5 sample - upload parameter'
define root abstract entity z2ui5_a_smps_file_upload
{
  // a plain field next to the file - stored with it, shown in the list
  Description       : abap.char(60);

  _StreamProperties : association [1] to z2ui5_a_smps_file_stream on 1 = 1;
}
