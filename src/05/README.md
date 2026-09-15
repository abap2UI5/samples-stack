# 05 — Business Events

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

A RAP business object announces what happened, and something else reacts to it.
Packages [`03`](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md) and [`04`](https://github.com/abap2UI5/samples-stack/blob/main/src/04/README.md) end at the save — this
one starts there.

The interesting part for abap2UI5 is the decoupling. The app that creates a ticket
knows nothing about the handler. The handler knows nothing about the UI. Both are
plain ABAP, and both are on screen at the same time: one app triggers the events,
the second shows what arrived. RAP does the wiring in between.

## What you need

**Release:** Cloud + Standard ≥ 7.56 (2021) — the highest floor in this
repository, and the only package whose limit is not EML.

**Branch:** [`05-business-events`](https://github.com/abap2UI5/samples-stack/tree/05-business-events)
— this package alone, without the other eight on your system.

ABAP Platform >= 1909 or a BTP ABAP Environment covers the EML part — but this
package also needs a release that already carries **RAP business events**. They are
a younger RAP feature than EML itself: if `RAISE ENTITY EVENT` does not activate on
your system, this package is simply out of reach for now, and nothing else in this
repository is affected.

The overview app `z2ui5_cl_smps_app_000` lists these two samples like any others and
does not depend on them: it looks every sample up at runtime, so on a release
without business events the two rows are shown with their Open button disabled
instead of taking the overview down.

No service activation, no ICF node. Import, activate, start the app — the ticket
table fills itself as you create tickets.

## The two apps

| Sample | Role |
|---|---|
| [`011`](z2ui5_cl_smps_app_011.clas.abap) | create tickets through the BO — every create and update raises an event |
| [`012`](z2ui5_cl_smps_app_012.clas.abap) | the event log the handler writes, newest first |

Start them with `?app_start=z2ui5_cl_smps_app_011` and
`?app_start=z2ui5_cl_smps_app_012`, or from the overview app
`?app_start=z2ui5_cl_smps_app_000`, whose Open button puts each in its own tab. Open
both in two browser tabs, create a ticket in the first, press refresh in the
second — the log entry the handler wrote is there.

Events are raised in the save sequence and consumed **afterwards**, so the log
entry appears once the transaction is through, not during the roundtrip that
created the ticket. That is what the refresh button is for.

## The two kinds of event

The behavior definition [`z2ui5_r_smps_tck.bdef.asbdef`](01/z2ui5_r_smps_tck.bdef.asbdef)
declares one of each — the distinction is the whole point of the sample:

```abap
" notification event: the key, nothing else
event TicketCreated;

" data event: an enriched payload, typed by an abstract entity
event StatusChanged parameter Z2UI5_R_SMPS_TCK_STAT;
```

A **notification** event says *something happened to this instance* and leaves it to
the consumer to read the current state. A **data** event carries the state along, so
the consumer needs no second read — at the price of shipping data that may already
be stale by the time it is handled. The payload type is an ordinary abstract entity,
[`Z2UI5_R_SMPS_TCK_STAT`](01/z2ui5_r_smps_tck_stat.ddls.asddls).

## Who raises them

The additional save of the behavior pool,
[`Z2UI5_CL_SMPS_BP_TCK`](01/z2ui5_cl_smps_bp_tck.clas.locals_imp.abap) —
`save_modified` sees what the transaction changed and raises accordingly:

```abap
" on create - key only
RAISE ENTITY EVENT z2ui5_r_smps_tck~TicketCreated
  FROM VALUE #( FOR c IN create-ticket ( %key = VALUE #( TicketUUID = c-TicketUUID ) ) ).

" on update - key plus payload in %param
RAISE ENTITY EVENT z2ui5_r_smps_tck~StatusChanged
  FROM VALUE #( FOR t IN lt_current (
                  %key   = VALUE #( TicketUUID = t-TicketUUID )
                  %param = VALUE #( Title = t-Title Status = t-Status … ) ) ).
```

## Who listens

A separate class, [`Z2UI5_CL_SMPS_EVT_TCK`](01/z2ui5_cl_smps_evt_tck.clas.locals_imp.abap),
inheriting from `CL_ABAP_BEHAVIOR_EVENT_HANDLER`. It subscribes per event, receives
the instances as a table, and writes them into the log:

```abap
METHODS on_ticket_created FOR ENTITY EVENT
  ticketcreated FOR z2ui5_r_smps_tck~TicketCreated.

METHODS on_status_changed FOR ENTITY EVENT
  statuschanged FOR z2ui5_r_smps_tck~StatusChanged.
```

Nothing registers this class anywhere — the `FOR ENTITY EVENT` declaration *is* the
subscription. Add a second handler and it runs too; delete this one and the BO
still works. That is the property worth taking away: consumers come and go without
the business object changing a line.

## What is in the package

| Object | Role |
|---|---|
| `Z2UI5_T_SMPS_TCK`, `Z2UI5_D_SMPS_TCK` | the ticket table and its draft table |
| [`Z2UI5_R_SMPS_TCK`](01/z2ui5_r_smps_tck.ddls.asddls) + [`.bdef`](01/z2ui5_r_smps_tck.bdef.asbdef) | the root view entity and the behavior with the two events |
| [`Z2UI5_CL_SMPS_BP_TCK`](01/z2ui5_cl_smps_bp_tck.clas.locals_imp.abap) | behavior pool — determination and the additional save that raises |
| [`Z2UI5_R_SMPS_TCK_STAT`](01/z2ui5_r_smps_tck_stat.ddls.asddls) | the abstract entity typing the data event payload |
| [`Z2UI5_CL_SMPS_EVT_TCK`](01/z2ui5_cl_smps_evt_tck.clas.locals_imp.abap) | the event handler, writes the log |
| `Z2UI5_T_SMPS_LOG` + [`Z2UI5_R_SMPS_LOG`](01/z2ui5_r_smps_log.ddls.asddls) | the log table and its CDS view |
| [`Z2UI5_R_SMPS_TCK_C`](01/z2ui5_r_smps_tck_c.ddls.asddls), `Z2UI5_SD_SMPS_TCK`, `Z2UI5_SB_SMPS_TCK` | projection, service definition and an OData V4 binding |
| [`Z2UI5_CL_SMPS_APP_011`](z2ui5_cl_smps_app_011.clas.abap), [`Z2UI5_CL_SMPS_APP_012`](z2ui5_cl_smps_app_012.clas.abap) | the two abap2UI5 apps |

The projection, service definition and service binding are there on purpose: the
same business object can be published as an OData V4 service and consumed by a
Fiori Elements app, while the abap2UI5 apps sit next to it on the same BO. Use one,
use the other, use both — the business object does not care, and neither does
abap2UI5.

Publishing the binding in ADT regenerates its authorization default values (`SUSH`);
they are not part of the repository, so the first publish creates them fresh.

## One note on the checks

`RAISE ENTITY EVENT` and `FOR ENTITY EVENT` are beyond the abaplint parser, so the
parser errors this package reports are about the linter, not about the code: it
activates fine in an ABAP system.

## Where to go next

- [`07` AMC/APC](https://github.com/abap2UI5/samples-stack/blob/main/src/07/README.md) — the other half of the story: pushing what
  happened into an open browser tab instead of waiting for a refresh.
