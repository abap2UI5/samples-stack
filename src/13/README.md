# 13 — Excel & E-Mail

*[← all packages](../../README.md)*

Spreadsheets in, spreadsheets out, and one by mail. The **XCO XLSX library**
reads and writes `.xlsx` files in plain ABAP, and **`cl_bcs_mail_message`**
sends them — both released APIs of ABAP Cloud. abap2UI5 adds the two ends a
user touches: the FileUploader that brings a file into the backend, and the
`download_b64_file` frontend action that hands one to the browser.

## What you need

**Release:** Cloud + Standard ≥ 7.58 (2023). The XCO XLSX library and
`cl_bcs_mail_message` come with ABAP Cloud; on-premise the package needs a
release that carries both. If `xco_cp_xlsx` is not on your system, this package
is out of reach, and nothing else in this repository is affected.

**Branch:** [`13-excel-email`](https://github.com/abap2UI5/samples-stack/tree/13-excel-email)
— this package alone, without the other thirteen on your system.

The mail sample also needs **outbound mail** configured: on ABAP Cloud a
communication arrangement for the scenario `SAP_COM_0548`, on-premise SMTP in
transaction `SCOT`. Without it the send fails, and the sample shows the reason.

The import and the report sample work on the travels of the business object
`Z2UI5_R_SMPS_TRV` of [`03` RAP](../03/README.md). The branch carries `src/03` along for it, so
nothing has to be installed separately.

## The samples

| You want to | Sample |
|---|---|
| read an uploaded `.xlsx` file into an ABAP table | [`021`](z2ui5_cl_smps_app_021.clas.abap) |
| export a table as an `.xlsx` download | [`022`](z2ui5_cl_smps_app_022.clas.abap) |
| send a table as an `.xlsx` mail attachment | [`023`](z2ui5_cl_smps_app_023.clas.abap) |
| import the rows of an `.xlsx` file into a RAP business object | [`028`](z2ui5_cl_smps_app_028.clas.abap) |
| a report with a selection, a total and an `.xlsx` export | [`031`](z2ui5_cl_smps_app_031.clas.abap) |

The XCO calls sit in [`Z2UI5_CL_SMPS_XLSX`](z2ui5_cl_smps_xlsx.clas.abap), which
the three samples share: an `.xlsx` in, a table of strings out, and the way
back.

```abap
" read - the first worksheet, columns A to F
DATA(worksheet) = xco_cp_xlsx=>document->for_file_content( xlsx
    )->read_access( )->get_workbook( )->worksheet->at_position( 1 ).
worksheet->select( pattern )->row_stream(
    )->operation->write_to( REF #( t_rows )
    )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
    )->execute( ).

" write - a new document, one worksheet
DATA(document) = xco_cp_xlsx=>document->empty( )->write_access( ).
document->get_workbook( )->worksheet->at_position( 1
    )->select( pattern )->row_stream(
    )->operation->write_from( REF #( t_rows ) )->execute( ).
DATA(xlsx) = document->get_file_content( ).
```

Every cell travels as a string, so one table type fits every sheet; the app
converts what it needs. Numbers are written with a decimal point and no
thousands separator, the way a spreadsheet reads them back.

## Import into a business object

`Z2UI5_CL_SMPS_APP_028` goes one step further than reading: the rows become
travels. Upload converts every cell into the type of its field and shows the
result, so a wrong date is seen before anything is created. Import sends all
rows in one `MODIFY ENTITIES ... CREATE`, with the Excel row number as `%cid`:

```abap
MODIFY ENTITIES OF z2ui5_r_smps_trv
  ENTITY travel
    CREATE FIELDS ( agencyid customerid begindate enddate bookingfee currencycode description )
    WITH VALUE #( FOR t IN t_travel ( %cid = |ROW_{ t-row }| agencyid = t-agency_id ... ) )
  MAPPED DATA(s_mapped)
  FAILED DATA(s_failed)
  REPORTED DATA(s_reported).
```

The `%cid` is what brings each answer back to its row. A refusal of the CREATE
carries it directly. The validations run at `COMMIT ENTITIES`, and their
answers carry the key instead, which `MAPPED` translates back to the `%cid`.
A COMMIT saves everything or nothing; with *Skip refused rows* on, the app
rolls back and creates the remaining rows in a second attempt.

## Where to go next

- [`11` RAP File Upload](../11/README.md) — a file stored in a business object.
- [`14` Adobe Forms](../14/README.md) — PDF output, one file or a ZIP.
- The ZIP and CSV download without anything from the system:
  `Z2UI5_CL_SMP_APP_542` in [abap2UI5/samples](https://github.com/abap2UI5/samples).
