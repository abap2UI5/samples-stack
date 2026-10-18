# 14 — Adobe Forms

*[← all packages](../../README.md)*

The print forms a system already has, rendered to PDF from an abap2UI5 app. An
Adobe Form is rendered by the function module it generates: between
`FP_JOB_OPEN` and `FP_JOB_CLOSE` it hands back the PDF instead of printing it.
The app offers it as a download — one form as a PDF, several at once as one ZIP
file built with `cl_abap_zip`.

## What you need

**Release:** Standard only, ≥ 7.50. The classic Adobe Forms runtime
(`FP_JOB_OPEN`, the generated function module, `FP_JOB_CLOSE`) is not released
for ABAP Cloud, where forms are rendered by the Forms Service by Adobe through
`cl_fp_ads_util` instead.

**Branch:** [`14-adobe-forms`](https://github.com/abap2UI5/samples-stack/tree/14-adobe-forms)
— this package alone, without the other thirteen on your system.

**Adobe Document Services (ADS)** configured for the system — the RFC
destination `ADS` in `SM59` — and an Adobe Form to render. The sample calls the
generated function module with a parameter table carrying only
`/1BCDWB/DOCPARAMS` and `/1BCDWB/FORMOUTPUT`, so it renders forms whose
interface needs no parameters of its own. A form that wants more says so in the
result list.

## The sample

| You want to | Sample |
|---|---|
| render forms to PDF, download one or a ZIP of several | [`024`](z2ui5_cl_smps_app_024.clas.abap) |

```abap
CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
  EXPORTING i_name = form IMPORTING e_funcname = function.

outputparams-getpdf   = abap_true.   " the PDF back, no printer
outputparams-nodialog = abap_true.   " no print dialog
CALL FUNCTION 'FP_JOB_OPEN' CHANGING ie_outputparams = outputparams.

CALL FUNCTION function
  PARAMETER-TABLE t_param            " /1BCDWB/DOCPARAMS, /1BCDWB/FORMOUTPUT
  EXCEPTION-TABLE t_exc.

CALL FUNCTION 'FP_JOB_CLOSE'.        " output-pdf is the file
```

The job is closed in every case — an open one makes the next `FP_JOB_OPEN` of
the session fail.

## Where to go next

- [`13` Excel & E-Mail](../13/README.md) — a file as mail attachment.
- Showing a PDF inside the page: the PDFViewer sample `Z2UI5_CL_SMP_APP_449` in
  [abap2UI5/samples](https://github.com/abap2UI5/samples).
