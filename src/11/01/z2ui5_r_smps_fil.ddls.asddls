@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'abap2UI5 RAP sample - uploaded file'
@Metadata.ignorePropagatedAnnotations: true
define root view entity z2ui5_r_smps_fil
  as select from z2ui5_t_smps_fil
{
  key file_uuid       as FileUuid,

      file_name       as FileName,
      @Semantics.mimeType: true
      mime_type       as MimeType,
      description     as Description,
      file_size       as FileSize,

      @Semantics.largeObject: { mimeType: 'MimeType',
                                fileName: 'FileName',
                                contentDispositionPreference: #ATTACHMENT }
      content         as Content,

      @Semantics.user.createdBy: true
      created_by      as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      last_changed_at as LastChangedAt
}
