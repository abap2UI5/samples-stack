# 03 — RAP: consume a business object with EML

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

RAP and abap2UI5 fit together naturally: the business object keeps the business
logic, abap2UI5 builds the UI on top of it — in plain ABAP, with no OData service
and no annotations in between. If you already have RAP BOs, you can put a screen in
front of them today. There is one runnable sample per EML statement, and the
business object to run them against ships with this package, so you can start right
away.

**Two ways in — pick yours:**

- **You know EML and want the snippet** → [Find the snippet](#find-the-snippet).
  Every class carries its statement in the comment at the very top, so you see it
  the moment you open the file.
- **RAP is new to you** → start with [The business object](#the-business-object).
  It is one page, and it makes every message the samples show readable.

The draft enabled half lives next door in [`04` RAP with Draft](https://github.com/abap2UI5/samples-stack/blob/main/src/04/README.md).

## What you need

**Release:** Cloud + Standard ≥ 7.54 (1909) — that is what EML asks for.

**Branch:** [`03-rap`](https://github.com/abap2UI5/samples-stack/tree/03-rap)
— this package alone, without the other eight on your system.

ABAP Platform >= 1909 or a BTP ABAP Environment. The business object
`Z2UI5_R_SMPS_TRV` and its table come with this package ([`src/03/01`](01)), so
nothing else has to be installed.

## Start here

Run [`000 overview`](../z2ui5_cl_smps_app_000.clas.abap) —
`?app_start=z2ui5_cl_smps_app_000`. It lists every sample of this repository, the
RAP ones included, and opens each in a new browser tab, so the overview stays open
and several samples can run side by side. *Regenerate Demo Data* in its header
fills both business objects.

Fill the tables before the first run: execute `Z2UI5_CL_SMPS_DATA_TRV` (and
`Z2UI5_CL_SMPS_DATA_TRD` for the draft package) with F9 in ADT, or press
*Regenerate Demo Data* in the overview — *Generate Demo Data* in a single sample
does the same for its own business object. Both offer `data_generate( )`,
`data_delete( )` and `data_reset( )`.

Demo data is created through the business object, not with an `INSERT` — otherwise
the determinations would not run and the rows would be data the BO could never
produce.

## The business object

`Z2UI5_R_SMPS_TRV` manages a **travel**. It is an ordinary managed RAP BO — small on
purpose, but not so small that consuming it is uninteresting.

| Field | |
|---|---|
| `TravelId` | the readable key, 8 digits. **Assigned by the BO**, never by the caller |
| `AgencyId`, `CustomerId` | mandatory |
| `BeginDate`, `EndDate` | mandatory, and `EndDate` must not be before `BeginDate` |
| `BookingFee`, `CurrencyCode` | what the caller may write |
| `TotalPrice` | **readonly** — the BO derives it |
| `OverallStatus` | **readonly** — `O` open, `A` accepted, `X` rejected |
| `Description` | free text |
| `CreatedBy/At`, `LastChangedBy/At` | **readonly** — filled by the runtime |

What runs, and **when**, is the part worth knowing up front — once it clicks, the
rest of the samples read themselves:

- **Early numbering** hands out `TravelId` while the CREATE is still in the
  transactional buffer. That is why the new key comes back in `MAPPED` under the
  `%cid` you sent, and why you never pass a key on CREATE.
- A **determination** (`setInitialValues`) fills `OverallStatus`, `TotalPrice` and
  the currency right after a create. Those fields are readonly for you precisely
  because the BO owns them.
- Two **validations** (`validateCustomer`, `validateDates`) run **on save**, not at
  the `MODIFY`. A `MODIFY` that answered with an empty `FAILED` can still be refused
  at the `COMMIT` — which is why the samples always evaluate both responses.
- Two **actions** (`acceptTravel`, `rejectTravel`) set `OverallStatus`. An action is
  called with `EXECUTE`.

## Find the snippet

Five samples: four single statements, then one complete app. The numbers are the
reading order.

| You want to | Statement | Sample |
|---|---|---|
| read an instance | `READ ENTITIES` | [`001`](z2ui5_cl_smps_app_001.clas.abap) |
| create one | `MODIFY … CREATE` → `MAPPED` | [`002`](z2ui5_cl_smps_app_002.clas.abap) |
| change fields | `MODIFY … UPDATE FIELDS` | [`003`](z2ui5_cl_smps_app_003.clas.abap) |
| delete one | `MODIFY … DELETE FROM` | [`004`](z2ui5_cl_smps_app_004.clas.abap) |
| show BO messages in the UI | `msg_display( )` | [`context`](../00/00/z2ui5_cl_smps_context.clas.abap) |

**The complete app** shows the next step: everything the single statements teach,
now in one screen with popups, message handling and a refresh — roughly three times
the size, and close to what a real app looks like. Best read once the snippets have
made sense:

| | | |
|---|---|---|
| call a BO action, save and catch what failed | `MODIFY … EXECUTE`, `COMMIT ENTITIES RESPONSE OF` | [`005` manage travels](z2ui5_cl_smps_app_005.clas.abap) |

## The snippets

**Read** — no SELECT, no OData.

```abap
READ ENTITIES OF z2ui5_r_smps_trv
  ENTITY travel
    ALL FIELDS WITH VALUE #( ( travelid = travel_id ) )
  RESULT DATA(t_result)
  FAILED DATA(s_failed).
```

A key that does not exist is not an exception — it lands in `FAILED`, and `RESULT`
simply has one row less. The response is what you check, never `sy-subrc`.

**Create** — the `%cid` is yours; the key the BO assigns comes back under it.

```abap
MODIFY ENTITIES OF z2ui5_r_smps_trv
  ENTITY travel
    CREATE FIELDS ( agencyid customerid begindate enddate )
    WITH VALUE #( ( %cid = `CREATE_1` agencyid = '070001' customerid = '000001' ) )
  MAPPED DATA(s_mapped)
  FAILED DATA(s_failed)
  REPORTED DATA(s_reported).

DATA(new_id) = s_mapped-travel[ %cid = `CREATE_1` ]-travelid.
```

**Update / delete / action** — same shape, only the operation differs.

```abap
UPDATE FIELDS ( description )
  WITH VALUE #( ( travelid = travel_id description = `...` ) )

DELETE FROM VALUE #( ( travelid = travel_id ) )

EXECUTE acceptTravel FROM VALUE #( ( travelid = travel_id ) )
```

**Save** — validations run here, not at the `MODIFY`.

```abap
COMMIT ENTITIES RESPONSE OF z2ui5_r_smps_trv
  FAILED DATA(s_failed)
  REPORTED DATA(s_reported).
```

**Messages** — don't loop over `%msg` yourself. The shared context class of this
package group ships the reader: it recognises a RAP structure by `%MSG`/`%FAIL`,
takes a whole `REPORTED` response or a single entity table, and pulls out the
failure cause, element, action, `%cid` and `%tky` — and shows the result in a
message box.

```abap
z2ui5_cl_smps_context=>msg_display( client = client
                                    val    = s_reported-travel ).
```

Every sample in this package calls it, which is why none of them formats a message
itself.

## Where to go next

- [`04` RAP with Draft](https://github.com/abap2UI5/samples-stack/blob/main/src/04/README.md) — the same BO, draft enabled.
- [`05` Business Events](https://github.com/abap2UI5/samples-stack/blob/main/src/05/README.md) — what happens *after* the save.
