# 04 — RAP with Draft

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

`Z2UI5_R_SMPS_TRD` is the business object of [`03` RAP](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md) **with
draft**. Everything you read there still applies — this package adds the one
mechanism that makes drafts work, and four samples that use it.

Draft handling is often assumed to come only with Fiori Elements. It does not: the
draft actions are ordinary BO actions, and EML reaches them like any other. The
whole lifecycle fits in a handful of statements.

## What you need

**Release:** Cloud + Standard ≥ 7.54 (1909), the same as
[`03`](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md) — draft handling adds nothing on top of EML.

**Branch:** [`04-rap-draft`](https://github.com/abap2UI5/samples-stack/tree/04-rap-draft)
— this package alone, without the other eight on your system.

ABAP Platform >= 1909 or a BTP ABAP Environment. The draft enabled business object
and its two tables come with this package ([`src/04/01`](01)).

Fill the table with `Z2UI5_CL_SMPS_DATA_TRD` (F9 in ADT) or press *Regenerate Demo
Data* in the overview app `?app_start=z2ui5_cl_smps_app_000`.

## What changes with draft

- The key is a `TravelUuid`, and the draft and the active instance **share it** —
  `%is_draft` is the only thing separating them. That single fact is what all four
  samples are built on.
- `TravelId` is only handed out when a draft is **activated**, so a discarded draft
  does not burn a number.

Both business objects are independent of each other; you can look at either one
first.

## Find the snippet

| You want to | Statement | Sample |
|---|---|---|
| see which instances have a draft | `READ … %is_draft = mk-on` | [`006`](z2ui5_cl_smps_app_006.clas.abap) |
| enter draft mode | `EXECUTE Edit` / `Resume` | [`007`](z2ui5_cl_smps_app_007.clas.abap) |
| change a draft | `UPDATE … %is_draft = mk-on` | [`008`](z2ui5_cl_smps_app_008.clas.abap) |
| leave draft mode | `EXECUTE Activate` / `Discard` | [`009`](z2ui5_cl_smps_app_009.clas.abap) |

Start at `06` — it carries the one trick the other three reuse.

**The complete app** puts all four together in one screen with popups, message
handling and a refresh — roughly three times the size, and close to what a real app
looks like:

| | | |
|---|---|---|
| the whole draft lifecycle | everything from 006–009 | [`010` manage travels with draft](z2ui5_cl_smps_app_010.clas.abap) |

## The snippets

**Which instances have a draft** — a draft shares the key of its active instance,
so `%is_draft` is the only thing separating them. Everything that comes back in
`RESULT` has a draft, the rest lands in `FAILED`.

```abap
READ ENTITIES OF z2ui5_r_smps_trd
  ENTITY travel
    FIELDS ( travelid ) WITH VALUE #( FOR s_row IN t_result
                                      ( %tky = VALUE #( traveluuid = s_row-traveluuid
                                                        %is_draft  = if_abap_behv=>mk-on ) ) )
  RESULT DATA(t_drafts)
  FAILED DATA(s_failed).
```

**The draft actions** — a draft action needs the key and nothing else: which of the
two instances it works on is part of the action, not of the call. `%is_draft` is not
even a component of the action import type.

```abap
EXECUTE Edit     FROM VALUE #( ( %key-traveluuid = uuid ) )   " active -> new draft
EXECUTE Resume   FROM VALUE #( ( %key-traveluuid = uuid ) )   " draft  -> continue it
EXECUTE Activate FROM VALUE #( ( %key-traveluuid = uuid ) )   " draft  -> active, validations run
EXECUTE Discard  FROM VALUE #( ( %key-traveluuid = uuid ) )   " draft  -> gone, active untouched
```

`Activate` is where the validations run, so it is the call whose `FAILED` and
`REPORTED` you always evaluate — same as the `COMMIT` in [`03`](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md).

## Where to go next

- [`03` RAP](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md) — the statements without draft, plus the message
  handling every sample here reuses.
- [`05` Business Events](https://github.com/abap2UI5/samples-stack/blob/main/src/05/README.md) — react to what the BO did.
