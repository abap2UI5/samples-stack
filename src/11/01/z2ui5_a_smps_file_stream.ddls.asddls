// The file itself, one level below the action parameter
// z2ui5_a_smps_file_upload. The @Semantics.largeObject annotations are what
// a Fiori Elements action dialog reads to render a file picker; EML does not
// need them - an abap2UI5 app fills the three fields like any other.
@EndUserText.label: 'abap2UI5 sample - upload stream'
define root abstract entity z2ui5_a_smps_file_stream
{
  @Semantics.largeObject.mimeType : 'MimeType'
  @Semantics.largeObject.fileName : 'FileName'
  @EndUserText.label              : 'File'
  FileContent : abap.rawstring(0);

  @UI.hidden                      : true
  MimeType    : abap.char(128);

  @UI.hidden                      : true
  FileName    : abap.char(255);
}
