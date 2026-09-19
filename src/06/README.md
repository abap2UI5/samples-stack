# 06 — Stateful Sessions / Locks

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

By default abap2UI5 is stateless: every roundtrip is a fresh request and the app
state travels in the payload. When a scenario calls for more,
`client->set_session_stateful( )` switches it over — the session sticks to one work
process, and classic ABAP techniques such as an **ABAP lock** survive between two
clicks.

Stateless by default, stateful where it pays off, decided per app. Both modes are
in the framework; nothing has to be configured up front.

## What you need

**Release:** Standard only, ≥ 7.40 SP08. Not ABAP Cloud: neither the two `ENQUEUE`
function modules nor a stateful ICF session is a released cloud API — this package
is on-premise by design, not by omission.

**Branch:** [`06-stateful-locks`](https://github.com/abap2UI5/samples-stack/tree/06-stateful-locks)
— this package alone, without the other eight on your system.

ABAP Standard (on-premise). The locks go through the function modules
`ENQUEUE_E_TABLE` and `ENQUEUE_READ`, which are available there — `485`'s own page
title points this out.

The lock table `Z2UI5_T_SMPS_01` comes with this package
([`src/06/01`](01)); after the import it only has to be activated, it is never
filled with data. Keep `SM12` open next to the browser and you can watch the entries
appear live.

## The samples

| Sample | Shows |
|---|---|
| [`486`](z2ui5_cl_smps_app_486.clas.abap) | the basics — a counter in a static container. It keeps counting up while the session is stateful and starts over once you switch it off |
| [`485`](z2ui5_cl_smps_app_485.clas.abap) | set an `ENQUEUE` lock, read it back with `ENQUEUE_READ`, end and restart the session |
| [`490`](z2ui5_cl_smps_app_490.clas.abap) | one lock per screen — every *Next Lock View* navigates into a new app instance that takes the next `VARKEY`, going back releases it |

Start any of them with `?app_start=z2ui5_cl_smps_app_<no>`, or from the overview
app `?app_start=z2ui5_cl_smps_app_000`, which lists every sample of this repository.
Begin with `486`: it makes the mode switch visible in one number before any lock is
involved.

## Where to go next

- [`07` AMC/APC](https://github.com/abap2UI5/samples-stack/blob/main/src/07/README.md) — the other on-premise package, and the one that
  keeps a connection open rather than a session.
