# 12 — RAP Actions & Permissions

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

A business object does more than create, update and delete. It decides what is
allowed right now, offers actions that need input, proposes values for a new
instance, and checks values before they are saved. This package shows all of it
from the consumer's side, with EML, on a small business object that ships with
it: `Z2UI5_R_SMPS_REQ`, a **request** that is created New and ends Approved or
Rejected.

Everything a Fiori Elements app gets from the same behavior definition is there
for an abap2UI5 app too: the rules live in the business object, the app asks
for them and builds its screen from the answer.

## What you need

**Release:** Cloud + Standard ≥ 8.16 (2025). The package is set to the release
that carries all of its features. Instance feature control, actions with
parameters and factory actions are older; the default function
`GetDefaultsForCreate` and `cl_abap_behv_aux` are the young ones. If the
business object does not activate on your system, this package is out of reach,
and nothing else in this repository is affected.

**Branch:** [`12-rap-actions`](https://github.com/abap2UI5/samples-stack/tree/12-rap-actions)
— this package alone, without the other thirteen on your system.

The business object, its projection and its table come with this package
([`src/12/01`](01)). Fill the table with `Z2UI5_CL_SMPS_DATA_REQ` (F9 in ADT),
with *Reset Demo Data* in any of the four samples, or with *Regenerate Demo
Data* in the overview app. An approved request is never deleted: the feature
control of the business object refuses it, and the demo data respects that like
any other caller.

## The business object

| Object | What it is |
|---|---|
| `Z2UI5_T_SMPS_REQ` | the table |
| `Z2UI5_R_SMPS_REQ` | root view entity and behavior definition, managed |
| `Z2UI5_C_SMPS_REQ` | the projection — a second contract that exposes only `update` and `approve` |
| `Z2UI5_A_SMPS_REQ_REJECT`, `_COPY`, `_CREATE` | abstract entities, the parameters of the actions |
| `Z2UI5_CL_SMPS_BP_REQ` | the behavior pool |
| `Z2UI5_CL_SMPS_PERM_REQ` | the one `GET PERMISSIONS` statement of the package, see below |
| `Z2UI5_CL_SMPS_DATA_REQ` | demo data |

What the behavior definition declares, and what the samples use:

| Declaration | What it does |
|---|---|
| `update ( features : instance )`, `delete ( features : instance )`, `action ( features : instance ) approve / reject` | a New request may be changed, approved, rejected and deleted. A decided one may not be changed, and an approved one cannot even be deleted |
| `action reject parameter z2ui5_a_smps_req_reject` | an action that needs input: the reason, stored in `Note` |
| `factory action copyRequest parameter z2ui5_a_smps_req_copy [1]` | creates a new request from an existing one |
| `static factory action createRequest parameter z2ui5_a_smps_req_create [1]` | creates a request from its parameter alone |
| `create { default function GetDefaultsForCreate; }` | proposes the values of a new request |
| `validation validateQuantity on save` + `determine action checkRequest { validation validateQuantity; }` | the quantity must be between 1 and 1000 — checked at the save, or on demand through the determine action |

## The samples

| You want to | Statement | Sample |
|---|---|---|
| ask what is allowed and grey out the rest | `GET PERMISSIONS ONLY INSTANCE FEATURES` | [`017`](z2ui5_cl_smps_app_017.clas.abap) |
| propose, create, copy and reject with parameters | `READ … EXECUTE getdefaultsforcreate`, `EXECUTE createrequest / copyrequest / reject` with `%param` | [`018`](z2ui5_cl_smps_app_018.clas.abap) |
| check a value while the user types, without saving | `UPDATE` + `EXECUTE checkrequest`, then `ROLLBACK ENTITIES` | [`019`](z2ui5_cl_smps_app_019.clas.abap) |
| use the same business object through two contracts | EML on `Z2UI5_C_SMPS_REQ` and on `Z2UI5_R_SMPS_REQ`, `cl_abap_behv_aux` in the handler | [`020`](z2ui5_cl_smps_app_020.clas.abap) |

**Ask, then act — but the business object decides.** `017` greys out what the
feature control would refuse. Its switch *Ignore permissions* enables every
button anyway: press one on a decided request and the business object answers
with `FAILED`. The UI mirrors the rule, it does not enforce it.

**A factory action answers in `MAPPED`.** It has no `RESULT`: the new instance
comes back in `MAPPED`, under the `%cid` the caller sent.

**A default function changes nothing.** It is called with `READ ENTITIES …
EXECUTE`, and its `RESULT` carries a whole instance in `%param` — the proposal.
The create is a second step, sent by the caller.

**A determine action checks without saving.** `019` writes the new value into
the transactional buffer, runs `checkRequest` in the same statement, reads the
messages from `REPORTED` and rolls back. Save runs the validation once more —
that one counts.

## Why `GET PERMISSIONS` sits in a class of its own

abaplint has no grammar for `GET PERMISSIONS` at any language version, so a file
containing it does not parse. `Z2UI5_CL_SMPS_PERM_REQ` holds that one statement
and nothing else, and is listed in `noIssues` in `abaplint.jsonc` — the same way
the RAP event handler of [`05`](https://github.com/abap2UI5/samples-stack/blob/main/src/05/README.md) is. The sample app that calls
it, `Z2UI5_CL_SMPS_APP_017`, stays fully checked.

## Where to go next

- [`03` RAP](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md) — the basic EML statements, one per sample.
- [`11` RAP File Upload](https://github.com/abap2UI5/samples-stack/blob/main/src/11/README.md) — a deep action parameter that carries
  a file.
