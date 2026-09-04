# 01 — OData

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

An OData V2 service you already have, bound directly into an abap2UI5 view.

Smart controls are optional — a plain `sap.m.Table` bound to an OData V2 model
works just as well, and abap2UI5 lets you mix both styles in one app. The UI5
model does the fetching, the paging and the type handling; ABAP contributes the
view and the service path, nothing more.

## What you need

**Release:** Cloud + Standard ≥ 7.40 SP08. The sample is a view and two service
paths, so nothing here reaches past the ABAP the package is written in.

**Branch:** [`01-odata`](https://github.com/abap2UI5/samples-stack/tree/01-odata)
— this package alone, without the other eight on your system.

An activated OData V2 service. The sample points at the services of the SAP flight
reference scenario:

```
/sap/opu/odata/DMO/API_TRAVEL_U_V2/
/sap/opu/odata/DMO/ui_flight_r_v2/
```

Any two OData V2 services of your own system do just as well — swap the paths and
the sample keeps working.

## The sample

| Sample | Shows |
|---|---|
| [`315`](z2ui5_cl_smps_app_315.clas.abap) | two OData models in one view, one table bound to each |

Start it with `?app_start=z2ui5_cl_smps_app_315`, or from the overview app
`?app_start=z2ui5_cl_smps_app_000`, which lists every sample of this repository.

`315` attaches **two** models in one view via `cs_event-set_odata_model`, each under
its own name, and binds one table to each: `{TRAVEL>/Currency}` and
`{FLIGHT>/Airport}`. The column headers come from the metadata
(`{TRAVEL>/#Currency/Currency/@sap:label}`), the cells from the entity.

That is the whole point of the sample: the model name is what keeps the two apart,
so a view can carry as many services as the screen needs — next to each other,
next to abap2UI5's own JSON model.

## Where to go next

- [`02` Smart Controls](https://github.com/abap2UI5/samples-stack/blob/main/src/02/README.md) — the same metadata, this time driving the
  controls themselves.
