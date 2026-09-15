# 02 — Smart Controls

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

This is abap2UI5 at its most agnostic: the `sap.ui.comp` library builds its UI from
**OData V2 metadata** — a `SmartTable` asks the service what the columns are, a
`SmartField` asks what the field is. abap2UI5 simply points the default model at
that service and lets the metadata do the rest, so the apps carry almost no data of
their own. If you already run Gateway services, you get variant management, value
help and smart filtering for free.

## What you need

**Release:** Cloud + Standard ≥ 7.40 SP08. The metadata does the work, so the ABAP
side of these nine samples asks for nothing beyond the release the package is
written in — what they need is the service, not the platform.

**Branch:** [`02-smart-controls`](https://github.com/abap2UI5/samples-stack/tree/02-smart-controls)
— this package alone, without the other eight on your system.

- **SAPUI5**, since `sap.ui.comp` is part of the SAPUI5 distribution.
- **An activated OData V2 service.** Most samples point at the Gateway demo service
  `GWSAMPLE_BASIC`, which ships with every on-premise system and only has to be
  activated once in `/IWFND/MAINT_SERVICE`. Where a sample uses a different service,
  it says so at the `switch_default_model_path` — adjust it to your system.

## The samples

| Sample | Shows | Service |
|---|---|---|
| [`313`](z2ui5_cl_smps_app_313.clas.abap) | SmartFilterBar + SmartTable with variant management | `UI_PRODUCTLIST` |
| [`314`](z2ui5_cl_smps_app_314.clas.abap) | switch the default model — device, HTTP and OData model side by side | `GWSAMPLE_BASIC` |
| [`319`](z2ui5_cl_smps_app_319.clas.abap) | SmartMultiInput → an ABAP `SELECT-OPTIONS` range table | `UI_PRODUCTLIST` + value list annotations |
| [`475`](z2ui5_cl_smps_app_475.clas.abap) | SmartField inside a SmartForm | `GWSAMPLE_BASIC` |
| [`476`](z2ui5_cl_smps_app_476.clas.abap) | SmartForm, display/edit toggle | `GWSAMPLE_BASIC` |
| [`477`](z2ui5_cl_smps_app_477.clas.abap) | SmartFilterBar driving a SmartTable | `GWSAMPLE_BASIC` |
| [`478`](z2ui5_cl_smps_app_478.clas.abap) | page variant management | `GWSAMPLE_BASIC` |
| [`479`](z2ui5_cl_smps_app_479.clas.abap) | SmartChart with NavigationPopover | an analytical service — you supply it |
| [`493`](z2ui5_cl_smps_app_493.clas.abap) | classic FilterBar wired to variant management | none — the data is ABAP |

Start any of them with `?app_start=z2ui5_cl_smps_app_<no>`, or from the overview
app `?app_start=z2ui5_cl_smps_app_000`, which lists every sample of this repository.

## Two worth a closer look

`319` is the interesting one if you write classic ABAP: the user gets a full
SELECT-OPTIONS experience in the browser (value help, several conditions,
`contains` / `between` / `greater-than`, include and exclude), and the app maps the
returned conditions 1:1 onto an ABAP range table — `SIGN`/`OPTION`/`LOW`/`HIGH` — and
filters with `... WHERE product_type IN r_product_type`. Both the derived
SELECT-OPTIONS and the matching rows are on screen, so the mapping is visible.

`479` goes one step further: a SmartChart draws from an **analytical** OData V2
service — properties marked `sap:aggregation-role` dimension/measure plus the
`UI.Chart` annotation the layout comes from. Since a standard system ships no such
service, the path in the class is a placeholder — point it at an analytical service
of your own and the chart comes to life.

## Where to go next

- [`01` OData](https://github.com/abap2UI5/samples-stack/blob/main/src/01/README.md) — the same services without smart controls.
- [`03` RAP](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md) — data straight from a business object, no service in
  between.
