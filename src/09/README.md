# 09 — Launchpad

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

An abap2UI5 app does not have to run standalone. Put it behind a tile of the **SAP
Fiori Launchpad** and the shell around it becomes usable: the tile hands over
startup parameters, the shell title can be set from ABAP, and cross-app navigation
reaches the other tiles of the launchpad — your own and SAP's alike.

Nothing about the app changes for that. It stays the same class with the same
`main( )`; the framework recognises the launchpad on its own and tells the app
through `client->get( )-check_launchpad_active`. So one app runs in both worlds, and
the four samples here show what the launchpad adds when it is the one you are in.

## What you need

**Release:** Cloud + Standard ≥ 7.40 SP08. The apps talk to the shell through the
framework, so what decides here is whether you have a launchpad, not which ABAP
release serves it.

**Branch:** [`09-launchpad`](https://github.com/abap2UI5/samples-stack/tree/09-launchpad)
— this package alone, without the other eight on your system.

A **Fiori Launchpad** with a tile pointing at abap2UI5 — an on-premise FLP
(`/ui2/flp`), the launchpad sandbox (`test/flpSandbox`), or a launchpad site on BTP.
The target mapping's URL is the abap2UI5 ICF node plus the app to start:

```
/sap/bc/z2ui5?app_start=z2ui5_cl_smps_app_481
```

The framework detects the launchpad from that context (`scenario=LAUNCHPAD` in the
query, or `/ui2/flp` / `test/flpSandbox` in the path) and sets
`check_launchpad_active`. Every sample here checks the flag and tells you with a
message box when it was started standalone — where it then has no shell to talk to.

## The samples

| Sample | Shows |
|---|---|
| [`481`](z2ui5_cl_smps_app_481.clas.abap) | read the startup parameters the tile passed in — `client->get( )-t_comp_params` |
| [`482`](z2ui5_cl_smps_app_482.clas.abap) | set the shell title from the backend — `follow_up_action( cs_event-set_title_launchpad )` |
| [`483`](z2ui5_cl_smps_app_483.clas.abap) | cross-app navigation, **sender** — hands two values over to another tile |
| [`484`](z2ui5_cl_smps_app_484.clas.abap) | cross-app navigation, **receiver** — reads them back out of its startup parameters |

Start any of them with `?app_start=z2ui5_cl_smps_app_<no>` — from a tile, that is
what the target mapping's URL carries. The overview app
`?app_start=z2ui5_cl_smps_app_000` lists them too, but its Open button starts them
standalone, and standalone is exactly the case where they have no shell to talk to
and say so in a message box.

## The one pair worth configuring

`483` and `484` are two halves of the same story and only work together. The sender
navigates with the frontend event `cs_event-cross_app_nav_to_ext`, naming the target
by its **semantic object and action** — not by a class name and not by a URL:

```abap
press = client->follow_up_action(
    val   = client->cs_event-cross_app_nav_to_ext
    t_arg = VALUE #(
        ( `{ semanticObject: "Z2UI5_CL_LP_SAMPLE_04",  action: "display" }` )
        ( `$` && client->_bind( nav_params ) ) ) ).
```

The second argument is the bound structure, and it is what turns a navigation into a
handover: its components arrive at the receiver as startup parameters, so `484`
finds `PRODUCT` and `QUANTITY` in `t_comp_params` and shows them — exactly the same
table `481` reads, only filled by the sender instead of by a URL.

That indirection is the point. The sender knows a semantic object; the launchpad
decides which app answers to it. Configure two target mappings for the pair:

| Semantic object | Action | Starts |
|---|---|---|
| `Z2UI5_CL_LP_SAMPLE_03` | `display` | `z2ui5_cl_smps_app_483` (sender) |
| `Z2UI5_CL_LP_SAMPLE_04` | `display` | `z2ui5_cl_smps_app_484` (receiver) |

Both literals sit in the classes, so use these two names or change them there. The
*back to the previous app* button in either sample needs no configuration at all —
`cs_event-cross_app_nav_to_prev_app` goes back through the shell's own history.

## Where to go next

- [`01` OData](https://github.com/abap2UI5/samples-stack/blob/main/src/01/README.md) — back to the beginning: the app talking to a
  service instead of to the shell around it.
