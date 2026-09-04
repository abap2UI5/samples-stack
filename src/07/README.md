# 07 — AMC/APC: WebSockets

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

A news feed pushed from ABAP into every open browser tab, **without a line of
JavaScript**: the abap2UI5 custom control `z2ui5:Websocket` keeps the connection
open, reports every inbound message through its `received` event and a failure
through `error`; publishing goes the other way, from ABAP into the AMC channel.

Push is the one thing a request/response framework cannot do on its own — so
abap2UI5 does not try to. It hands the job to the messaging technology the platform
already provides and stays the UI in front of it.

## What you need

**Release:** Standard only, ≥ 7.50. APC/AMC is on-premise technology and has no
ABAP Cloud counterpart; the 7.50 comes from the ABAP the two classes are written
in, the channels themselves arrived earlier.

**Branch:** [`07-amc-apc`](https://github.com/abap2UI5/samples-stack/tree/07-amc-apc)
— this package alone, without the other eight on your system.

**Setup:** activate the ICF service `/sap/bc/apc/sap/z2ui5_apc_smp_2` in `SICF`. The
app checks this itself and shows a friendly warning strip while the node is still
inactive, so you always know where you stand.

APC/AMC is an on-premise technology. Open a second browser tab and watch the
message arrive in both at once.

## What is in the package

| Object | Role |
|---|---|
| [`489`](z2ui5_cl_smps_app_489.clas.abap) | the app — connect, publish, list the active connections |
| [`489_ws`](z2ui5_cl_smps_app_489_ws.clas.abap) | the APC handler, `CL_APC_WSP_EXT_STATELESS_BASE` |
| `Z2UI5_AMC_SMP_2` | the messaging channel, `/news_feed` |
| `Z2UI5_APC_SMP_2` | the push channel and its ICF node |

Start it with `?app_start=z2ui5_cl_smps_app_489`, or from the overview app
`?app_start=z2ui5_cl_smps_app_000`, which lists every sample of this repository.

## Where to go next

- [`05` Business Events](https://github.com/abap2UI5/samples-stack/blob/main/src/05/README.md) — a business object announcing what
  happened. Combine the two and a RAP event can end up in an open browser tab.
