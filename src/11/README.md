# 11 — RAP File Upload

*[← all packages](../../README.md)*

A file goes into a RAP business object as an **action parameter**. The static
action `uploadFile` of `Z2UI5_R_SMPS_FIL` takes a *deep parameter*: next to a
description, it carries the file content, its MIME type and its name, one level
down through an association. The business object decides what to store and what
to refuse. The app only picks the file and calls the action.

Fiori Elements reads this action from the OData metadata and renders a file
picker into the action dialog, because the stream entity carries
`@Semantics.largeObject`. abap2UI5 skips that layer. The `z2ui5:FileUploader`
custom control reads the file in the browser, the roundtrip brings it to the
backend as base64, and the app hands it to the action with EML like any other
value. The business object is the same one a Fiori Elements app would use.

## What you need

**Release:** Cloud + Standard ≥ 8.16 (2025). A deep action parameter whose
abstract entity carries a `@Semantics.largeObject` stream is younger than EML.
The ABAP of this package parses at 7.57; the feature arrived with ABAP Platform
2025 and the matching BTP ABAP Environment and S/4HANA Cloud releases. If the
action `uploadFile` does not activate on your system, this package is out of
reach, and nothing else in this repository is affected.

**Branch:** [`11-rap-file-upload`](https://github.com/abap2UI5/samples-stack/tree/11-rap-file-upload)
— this package alone, without the other ten on your system.

The business object and its table come with this package ([`src/11/01`](01)).
There is no demo data: the first file you upload is the first row.

## The business object

| Object | What it is |
|---|---|
| `Z2UI5_T_SMPS_FIL` | the table. One row per file, the content in a `RAWSTRING` column |
| `Z2UI5_R_SMPS_FIL` | the root view entity, `Content` annotated as `@Semantics.largeObject` |
| `Z2UI5_R_SMPS_FIL` (BDEF) | managed. `create` is **internal**, so the action is the only way in. `delete` is public |
| `Z2UI5_A_SMPS_FILE_UPLOAD` | abstract entity, the action parameter: `Description` and the association `_StreamProperties` |
| `Z2UI5_A_SMPS_FILE_STREAM` | abstract entity, the file: `FileContent` (`rawstring`), `MimeType`, `FileName` |
| the two abstract BDEFs | `with hierarchy`. They make the association part of the parameter. Without them `deep parameter` does not activate |
| `Z2UI5_CL_SMPS_BP_FIL` | the behavior pool. `uploadFile` creates the instance `IN LOCAL MODE` and refuses an empty file with a message |

The action in the behavior definition:

```abap
static action uploadFile deep parameter z2ui5_a_smps_file_upload result [1] $self;
```

## The sample

| You want to | Statement | Sample |
|---|---|---|
| upload a file, list, download and delete it | `MODIFY … EXECUTE uploadFile` with a deep `%param` | [`016`](z2ui5_cl_smps_app_016.clas.abap) |

```abap
MODIFY ENTITIES OF z2ui5_r_smps_fil
  ENTITY file
    EXECUTE uploadfile
    FROM VALUE #( ( %cid   = `UPLOAD_1`
                    %param = VALUE #( description       = description
                                      _streamproperties = VALUE #( filecontent = content
                                                                   mimetype    = mime_type
                                                                   filename    = file_name ) ) ) )
  FAILED DATA(s_failed)
  REPORTED DATA(s_reported).

COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_fil
  FAILED DATA(s_failed_commit)
  REPORTED DATA(s_reported_commit).
```

`content` is an `xstring`. The app gets it from the data URL the FileUploader
delivers (`data:<mime>;base64,<payload>`) with
`cl_web_http_utility=>decode_x_base64( )`. The way back is the same in
reverse: `READ ENTITIES` with the content, encoded to base64 again, and the
`download_b64_file` frontend action saves it in the browser.

## How big can a file be?

The limit is the same as for Fiori Elements. It comes from the transport, and
the transport works the same way in both cases:

- **abap2UI5:** the file travels base64-encoded inside the JSON of the
  roundtrip, about a third larger than the file itself.
- **Fiori Elements:** an action parameter travels in the JSON body of the
  OData V4 request, and OData's JSON format writes binary values
  (`Edm.Binary`, which a `rawstring` becomes) as base64 too. Same overhead,
  same single request.

In both cases the whole file sits in the memory of one work process, decoded
once and copied into the business object. Large files hit the request size
limits of the ICF and Gateway and the memory quota of the session long before
anything in this sample does. Uploading a stream property on its own with
`PUT …/$value` sends raw bytes and skips the base64 step, but it is a different
technique, and it still is one request holding the whole file. For really
large files neither path is right: they belong in a document or object store
(DMS, SAP Document Management service, an object store on BTP), with the
business object keeping only a reference.

## Where to go next

- [`03` RAP](../03/README.md) — the EML statements one by one, on a business
  object without files.
- The upload without RAP: `Z2UI5_CL_SMP_APP_074` (FileUploader) and
  `Z2UI5_CL_SMP_APP_517` (UploadSet, several files, drag and drop) in
  [abap2UI5/samples](https://github.com/abap2UI5/samples).
