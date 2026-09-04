# AGENTS.md — abap2UI5/samples-stack

The guide for this repository. Read it before changing anything under `src/`.

This file is deliberately short. The ABAP style, the view-builder chain layout
and the app conventions are **shared with `abap2UI5/samples`** and documented
there once — [`samples/AGENTS.md`](https://github.com/abap2UI5/samples/blob/main/AGENTS.md),
sections 7 (naming and style) and 11 (app structure). What follows is only what
is different or true here alone.

## 1. What this repository is, and is not

The third step of the learning ladder: `samples` (fundamentals) →
`samples-controls` (the UI5 control set) → **`samples-stack`** (abap2UI5
together with the rest of your stack).

The line is not a topic, it is a requirement: **everything here needs something
from the system beyond an abap2UI5 installation** — a Gateway service, a RAP
business object, an APC channel, an ICF node, SAPUI5's `sap.ui.comp`. That is
what keeps `samples` install-and-run and ABAP-Cloud-clean, and it is why a
sample that runs standalone belongs there, not here.

Two consequences worth stating:

- **No 7.02 downport.** EML sets the floor at 1909, so this repository is not
  downported the way the others are. `abaplint.jsonc` checks `main` at v757.
- **Objects other than classes.** Packages bring their own tables, data
  elements, CDS entities, behavior definitions and service bindings. They are
  part of the sample, not scaffolding around it.

## 2. The package scheme

One directory per technology under `src/`, `src/00` for what several of them
share, and the overview app `z2ui5_cl_smps_app_000` in the root.

`.github/packages.json` is the index: directory, branch name, title, the
release the package needs, its abaplint syntax version, and the `shared`
directories it takes with it. Adding a package means adding an entry there —
the branch build, the abaplint version and the README table all read it.

Naming, enforced by `object_naming`:

```
Z2UI5_CL_SMPS_<object>   classes, including behavior pools   (max 25 chars)
Z2UI5_T_SMPS_<object>    persistent tables                   (max 16 chars)
Z2UI5_D_SMPS_<object>    draft tables                        (max 16 chars)
Z2UI5_R_SMPS_<object>    CDS root view entities + behavior definitions
```

The 25-character cap is not ABAP's 30: `build_rename` swaps the 5-character
`z2ui5` namespace for one up to 9 long, which costs 4. Tables are capped at 16
because that is the DDIC limit — a 17-character table does not activate.

### Sample numbers are per repository — the prefix is what qualifies them

`Z2UI5_CL_SMPS_APP_<no>` is the name; `<no>` alone is not. **Numbers are handed
out inside this repository only**, and the three sample repositories reuse each
other's freely — `493` is `Z2UI5_CL_SMPS_APP_493`, the classic FilterBar with
variant management, here, and `Z2UI5_CL_SMP_APP_493`, Hello World, in
[samples](https://github.com/abap2UI5/samples). So are `489` and `490`. There is
no global number space and there was never going to be one: each repository
numbers from its own sequence, and coordinating three of them would buy nothing
the prefix does not already give.

What follows, in prose anywhere — this file, the READMEs, a commit message, a
comment: **name a sample by its class, never by its number alone.**
`Z2UI5_CL_SMPS_APP_319` and "app 319" read the same to somebody who already
knows which repository they are in, and only the first one still reads correctly
to everybody else. A package README's sample table is exempt: there the number
is a link to the class file, which is the qualification.

## 3. The generated one-package branches

abapGit imports a whole repository; there is no sparse checkout. Nine packages
with different floors would mean a system that wants OData also takes APC and
gets activation errors for technology it never asked for. So every package is
force-pushed to its own branch by `create-package-branches.yaml`, and the
abapGit branch dropdown becomes the place you pick your feature.

What that costs you when you edit:

- **Work on `main`.** A generated branch is rebuilt and force-pushed on every
  push to `main`; anything committed there is gone at the next build.
- **The overview app ships on every branch** and lists every sample of the
  repository, marking the ones this checkout does not carry as unavailable. So
  it must not reference anything a branch might not have. It references samples
  BY NAME and resolves them at runtime for exactly that reason — and it carries
  its own url helper rather than calling one, because `src/00` travels only
  with the two packages that name it in `shared`. `check:overview` fails on a
  static `Z2UI5_CL_SMPS_*` reference that would not survive every branch.
- Each branch is linted at **its own** release before it is pushed, which is
  what makes the "Runs on" column in the README true rather than aspirational.

## 4. Build & verify

```sh
npm ci
npm run check        # abaplint + abap2UI5-linter + overview + keywords + abapdoc + SAMPLES.md + catalogue.json + app-rules
```

Individually: `npm run lint` (abaplint), `npm run check:abap2ui5` (the app
class and the view it builds, including a headless render of every view),
`npm run check:overview` (the five consistency directions between the overview
app, the tree, `packages.json` and the two README tables — the package table
and the *Which package do I need?* decision table).

`npm run fmt:chains` applies the house chain layout. It rewrites whitespace
between chain segments only — but it needs the ABAP to be *balanced* to know
where a statement ends, so run `npm run lint` first if a chain is mid-edit.

**Every script lives in `scripts/`**, plain node with no dependencies, and every
one of them is run from the repository root. There is no second place: the
scripts sat in `.github/scripts/` and in `scripts/` at the same time until
2026-08-18, split by nothing but which two had been copied in from
`abap2UI5/samples` — so "where does a new check go" had no answer, and the two
halves could not share `lib/`. `scripts/` is what both sibling repositories use.

`.github/` keeps what GitHub reads: the workflows, the badges, and
`packages.json`, which is a workflow input.

**Every check has a workflow, and every workflow is in `npm run check`.** A
check only `npm run check` runs cannot make a pull request red, which is the
same as not having it — `check:abapdoc` was in that state for its whole life.

## 5. Conventions that are checked here

**The rule block below the marker in `abaplint.jsonc` is a CHECKED COPY of the
shared app rule set, and its source is
[abap2UI5/abap2UI5](https://github.com/abap2UI5/abap2UI5)
`.github/abaplint/app-rules.json`** — the repository where the rest of "how to
write an abap2UI5 app" already lives (the `build-an-app` and
`view-chain-layout` skills, `docs/agents/building-apps.md`, `abap-check`,
`ui5-check`), because a shared thing needs one owner. **Change it THERE first,
then copy it here**; this one, [samples](https://github.com/abap2UI5/samples)
and [samples-controls](https://github.com/abap2UI5/samples-controls) are
consumers of that file, not peers of each other. abaplint has no `extends`, so
the checked copy is the mechanism, and the block carries a header saying so.

**The gate is `scripts/check-app-rules.mjs`** — `npm run check:app-rules`, the
last step of `npm run check`, and the `check-app-rules` workflow on every pull
request and push to `main`. It compares PARSED SETTINGS against the source,
preferring an `abap2UI5` checkout next to this one and otherwise fetching it,
and it is the one check here that needs the network: an unreachable source
SAYS SO and passes, rather than turning this repository red because github.com
is. It replaced a three-way peer comparison, which had no answer to which of
three peers is right, went red in the *other* repositories when one drifted,
and compared rule NAMES only — so flipping a rule to `false` to get a pull
request through, the exact drift it existed to catch, read to it as no change
at all. abap2UI5 checks the same thing from its side (`shared-file-gate.mjs`).

Only `global`, `dependencies` and `syntax` are per repository (this one runs
at `v757` against the full steampunk API, and silences the RAP event handler
abaplint cannot parse) — plus exactly **one** rule: `object_naming`, which
carries the `SMPS` token and is the only rule `check-app-rules` excludes from
the comparison. It sits last in the file behind a marker that says so;
everything above that marker must match the source.

All 188 rules abaplint ships are named: 171 on, 17 off, each with its reason
in a comment. **A rule is never left out of the file** — when an upgrade adds
one, add the key to `app-rules.json` and copy the block into all three
consumers: on if all three corpora pass, off with the reason if they do not.

RAP is what makes this corpus different from the other two, and the shared
block carries **scoped excludes** for it rather than turning rules off for
everybody. Each pattern matches nothing under the other two `src/` trees:

- `keyword_case` excludes `z2ui5_cl_smps_*` — CDS entities, actions and fields
  are CamelCase by definition (`Ticket`, `TravelUuid`, `Activate`), and the
  rule reads every one as a violation (31 findings, all correct ABAP).
- `unused_variables` / `unused_methods` exclude the `bp_` behavior pools: a
  handler's parameters are fixed by its signature, the runtime is what calls
  it, and abaplint has no grammar for `RAISE ENTITY EVENT`.
- `local_class_naming` excludes them too — `lhc_<entity>` is the name RAP
  mandates. `check_abstract` likewise: a behavior pool is `ABSTRACT FINAL` by
  definition.
- `select_single_full_key` excludes them: their `SELECT SINGLE` is an
  aggregate (`MAX( travel_id )`), which returns exactly one row by definition.
- `unused_ddic` excludes the persistent and draft tables — they are referenced
  from the CDS and behavior definitions, which abaplint does not trace into.
- `fully_type_constants` excludes `Z2UI5_CL_SMPS_APP_007` and `_010`: `TYPE
  RESPONSE FOR FAILED / REPORTED EARLY` is fully typed RAP syntax abaplint
  reads as implicit.
- `max_one_statement` excludes `Z2UI5_CL_SMPS_APP_319` — its operator mapping is
  a table written as a `CASE`, one `WHEN` per line, and splitting it loses the
  shape.
- `check_syntax` / `superclass_final` exclude `Z2UI5_CL_SMPS_APP_489`: ABAP Push
  Channels are on-premise only and absent from the steampunk dependency.
- `cds_naming` takes the `Z2UI5_` namespace instead of SAP's per-category
  `ZI_` / `ZC_` / `ZR_` prefixes — the root view entities here are
  `Z2UI5_R_SMPS_<object>`.
- `smim_consistency` is off outright: the two `.mp3` SMIM objects in `08/01`
  have a parent MIME folder that lives on the system, not in the repository.

Everything else applies, including `commented_code`, `unused_variables`,
`whitespace_end` and `7bit_ascii`. An EML result clause you do not read
(`MAPPED`/`REPORTED`/`FAILED`) is an unused variable — leave the clause out.
Local type names follow `^TY_` like the other two repositories (`ty_s_` for a
structure, `ty_t_` for its table) — the looser `t_` this repository used is
gone.

> **Write a configured rule's flags out in full.** abaplint replaces the whole
> options object, so a partial one silently turns every flag it omits *off* —
> `"check_subrc": { "selectTable": false }` disables the rule entirely instead
> of narrowing it.

## 6. Documentation that travels with a sample

- Every package has a `README.md` with a **What you need** paragraph: release,
  branch, and the setup step (create the service binding, activate the ICF
  node, publish the OData service). A reader must not have to guess.
- Every app class carries an ABAP-Doc header (`"!`) saying what it demonstrates
  and what it needs. `src/03` and `src/04` are the reference for how much: the
  EML statement in the header, and comments where `%cid`, rollback semantics or
  "validations run at COMMIT" would otherwise surprise a reader.
- The class description in `.clas.xml` (`<DESCRIPT>`) is what the overview app
  shows. Keep it in Title Case and specific.
- **Every app carries three lines about itself, and they are the only place
  each fact lives** — checked by `npm run check:keywords`:

  ```abap
  " @keywords stateful session basics state roundtrip set_session_stateful
  " @summary a counter in a static container - counts up while the session is stateful, starts over once it is not
  CLASS z2ui5_cl_smps_app_486 DEFINITION PUBLIC.
  ```
  with `DESCRIPT` = `Stateful Sessions - Basics`.

  | | what it carries | limit |
  |---|---|---|
  | `DESCRIPT` | `Titel - Kurzbeschreibung` | **60 characters**, hard |
  | `" @summary` | the sentence a catalogue puts under the title | none |
  | `" @keywords` | what somebody would type who does not know it exists | none |

  `@summary` exists because of that 60-character cap: of the 31 curated
  descriptions this repository already had, only **13 fit in 60** and the
  longest was **114**. Without it a catalogue row is a title and nothing else.

  A plain `"` comment and not `"!`, because an unknown `"! @tag` is reported by
  the extended check (SLIN/ATC). Lowercase, space separated, four to eight
  terms. The convention is [abap2UI5/samples](https://github.com/abap2UI5/samples)'
  (its AGENTS.md §4), unchanged on purpose so one reader can read both
  repositories.

  Put in what a newcomer would **type** and the class name cannot hold:
  synonyms (`flp` for launchpad, `eml` for the RAP entity API), the controls
  the sample actually builds (`smartfilterbar`, `feedlistitem`) and the
  abap2UI5 API it demonstrates (`set_session_stateful`, `nav_app_call`). Leave
  out the scaffolding — `check_on_init`, `view_display` and `_bind` run through
  nearly every app here and therefore separate none of them.

  Why it is gated: nothing about a missing line is broken. The app compiles,
  runs, and appears in the overview. The only symptom is that nobody looking
  for it arrives — the overview's search box, `Ctrl+F` over a catalogue, and an
  agent asking "is there already a sample for WebSockets" all come up empty in
  the same silent way. This repository ran that way for its whole life.

  A class that does **not** implement `z2ui5_if_app` is a helper — a behavior
  pool, demo data, an event consumer, the generated APC protocol class — and is
  exempt, because a helper is reached *by* a sample rather than looked up. That
  is decided from the source, not from a list somebody has to maintain.

  `" @docs` (the link back to a documentation chapter) is **not** added here by
  hand: the pairing is declared on the documentation side, in the page's
  `samples:` frontmatter, and generated back.
- **[`SAMPLES.md`](SAMPLES.md) is the catalogue as a page** — generated by
  `npm run samples:md`, checked by `npm run check:samples-md`, **not** edited by
  hand. The overview app answers "what is in here" once abap2UI5, a service
  binding and the packages are on a system; before that it answers nothing, and
  this page does.

  **Its source is the class**, all three levels of it: title and short
  description from `DESCRIPT`, the line under them from `@summary`, the small
  type from `@keywords`. It read the overview app's catalogue for one commit,
  which was better than DESCRIPT alone and still one step short: a sample'''s
  description sat in a DIFFERENT class from the sample.

  The old note, kept because the numbers are the argument for `@summary`:
  Both exist and they disagree — `Z2UI5_CL_SMPS_APP_315`'s DESCRIPT reads
  *"Model - Use OData models"* while the overview says *"Two OData models in one view"* with *"one
  table bound to each, column headers from the metadata"* under it. The second
  is the curated text, the first is a 60-character abapGit short text written
  for ADT's object list. Rendering the page from DESCRIPT would have produced a
  **third** description of every sample, disagreeing with the app this page
  claims to be a reading copy of.

  So: title and detail come from `z2ui5_cl_smps_app_000`, the search terms from
  the class's `@keywords`, the link from the file path. One place per fact.

  Two checks close the loop in both directions. `check-overview` refuses a
  catalogue entry naming a class that does not exist; `check:samples-md`
  refuses an app that exists and is in no entry — the case that leaves a
  working sample invisible in the app *and* on the page.

  **The row format is byte-for-byte abap2UI5/samples'**, on purpose: `mcp-server`'s
  `examples` tool and `docs`' `link-samples.mjs` already parse those rows with a
  regex. Neither reads this repository yet, and the identical shape is what
  makes that a configuration change over there rather than a second parser.
  Changing the shape is not a cosmetic decision — a row that stops matching is
  a row that silently is not there.
- **[`catalogue.json`](catalogue.json) is the catalogue as data** — generated
  by `npm run catalogue`, checked by `npm run check:catalogue`, **not** edited
  by hand. SAMPLES.md is the reading copy for a person; this is the same
  catalogue for a program: one entry per sample with class, path, package,
  technology, `@summary`, `@keywords`, and the package's *Runs on* and *Plays
  together with* facts repeated on the entry — so "which sample shows X with
  RAP, and what does my system need for it" is answered from one committed
  file, one `raw.githubusercontent.com` fetch away, without running anything.
  It introduces no source of truth: everything in it comes out of the same
  scan behind SAMPLES.md (`scripts/lib/scan-samples.mjs`) and the same package
  merge behind it (`scripts/lib/read-packages.mjs`). Committed because its
  reader runs no generator — which is exactly why the freshness check exists —
  and dependency-free, which is why the linter-derived facts live beside it in
  `catalogue-derived.json` rather than in it (§8).

## 7. When you add a sample

1. Pick the package by what the sample **needs from the system**. If the answer
   is "nothing but abap2UI5", it belongs in `abap2UI5/samples`.
2. Name it `Z2UI5_CL_SMPS_APP_<no>`, following the numbers already in the
   package.
3. Add it to the overview app's catalogue in `z2ui5_cl_smps_app_000` — by name,
   never with a static reference.
4. Give it a `" @keywords` line as its first line (§6) — what somebody would
   type who does not know your sample exists.
5. Say what it needs in the package README if it needs anything new.
6. `npm run samples:md`, `npm run catalogue` and `npm run derived`, and commit
   `SAMPLES.md`, `catalogue.json` and `catalogue-derived.json` with it (§6, §8).
7. `npm run check`.

## 8. The catalogue — published from the playground

**<https://abap2ui5.github.io/playground/samples/>** — every sample of this
repository, of `abap2UI5/samples` and of `abap2UI5/samples-controls`,
searchable, for somebody who has installed nothing yet and is asking whether
their system can run any of it.

This repository published its own page for that until 2026-09-03 (`web/`, three
hand-written files plus a generated `apps.json` and thumbnails, `check-web`,
`deploy-web`, `check-family-nav`). All of it is gone. Three pages that each had
to explain that the other two existed were the reason for the shared family-nav
block, its three copies and the check policing them; one page needs none of it.

What this repository owes the new one is **data**, in two committed files:

| | |
|---|---|
| [`catalogue.json`](catalogue.json) | what the tree holds — class, path, package, technology, title, `@summary`, `@keywords`, and the three facts that are this corpus' whole point: `runsOn`, `cloud`, `needs` (§6) |
| [`catalogue-derived.json`](catalogue-derived.json) | what the LINTER knows — every control a sample BUILDS, and the minimum UI5 release that implies |

The second is not for this corpus' own facets. What a sample needs from a
system is committed fact and no linter can derive it — no pass tells you
whether a system has a RAP stack. It is there so that a reader filtering all
three corpora at once can ask *"which sample shows `sap.m.Table`"* of this one
too, and so that a sample here does not silently drop out of a release-filtered
list. `scripts/generate-derived.mjs` gets both out of an `@abap2UI5/linter`
pass over the classes on `main` — `stats.types` and the `*-too-new` findings.

- **Not every sample here is view code.** Several are the backend half of a
  story — a RAP behaviour, an OData service, an APC handler — and the linter
  finds no chain in them. Those carry `noChain: true` rather than an empty
  control list: *builds nothing* and *is not a view* are different answers, and
  a consumer must not read the first as the second.
- **Two files rather than more columns.** Everything committed-fact is in
  `catalogue.json` already, and that file is offline and dependency-free on
  purpose (§6). The derived half needs the linter, so it lives beside it, keyed
  by `class` for a consumer to join on. One scan, one tree, so the two cannot
  disagree about which samples exist.
- **The UI5 library a control ships in is in neither.** That is one taxonomy
  question, and three sample repositories each answering it would be three
  prefix tables that drift; the playground's catalogue owns the mapping, beside
  the library list it decides "runs here" against. Identical file shape and
  identical reasoning in the two sibling repositories.
- **`check-catalogue` is the gate** (its own workflow, and part of `npm run
  check`): both generators with `--check`. It absorbed what `check-web` really
  asserted — a package with no README row, a row whose cells no longer parse,
  an app in a directory that is no package, a sample with no `@summary` or
  `@keywords` — because all four were already in `generate-catalogue.mjs`
  (`scripts/lib/read-packages.mjs` does the first three). Removing the page
  therefore lost no assertion.
- **The overview app stays out of the catalogue page** for the reason it was
  always out: `Z2UI5_CL_SMPS_APP_000` is this same catalogue inside a system,
  and as a card it contradicts a list built around what a sample needs — *needs
  nothing beyond abap2UI5* — plus a technology chip that filters ten groups
  down to itself. `SAMPLES.md` and both JSON files keep it; their reader is in
  the repository already.
- **Thumbnails** were photographed on every deploy by
  `scripts/generate-screenshots.mjs`, with the abap2UI5-linter's render
  harness. The script went with the page and the playground's deploy takes them
  now, from the same harness against the same `main`, so what a card shows is
  still what the render gate checks. Expect gaps, and expect the same ones:
  re-measured over this corpus (2026-09, `screenshotFiles( )` over `src` at the
  pinned runtime) **19 of the 32 app classes photograph, 24 of the 37 documents
  they build**, and the 13 that do not are the same three stable categories the
  first measurement (2026-08, 18 of 31) found — `sap.ui.comp` controls
  (SAPUI5-only, absent from the harness's OpenUI5 runtime: 7 of the 9 Smart
  Controls samples — SmartFilterBar, SmartForm, SmartVariantManagement,
  SmartChart), `z2ui5.cc` custom controls that do not load headless (the
  WebSocket, MIME-audio and Smart Multi Input samples), and three RAP samples
  whose `ObjectStatus` gets an empty `state` from the mock model. The count
  moved because the corpus grew, not the failure set: it is the same thirteen
  classes. A card
  without a picture is normal here, not broken, and a change to the harness
  rather than to those classes is what would fix it.

## Metadata: what goes on the class, and what goes beside it

Shared across `abap2UI5/samples`, `abap2UI5/samples-controls` and
`abap2UI5/samples-stack`. Decided once, so nobody has to decide it again per
repository.

**A class says what it IS. A sidecar records what HAPPENED to it.**

| | where | why |
|---|---|---|
| `DESCRIPT` — `Titel - Kurzbeschreibung` | `.clas.xml` | 60 characters, hard. What ADT's object list shows |
| `" @summary` — one sentence | first lines of `.clas.abap` | no limit. The line a catalogue puts under the title |
| `" @keywords` — search terms | first lines of `.clas.abap` | what somebody would type who does not know the sample exists |
| upstream sample, port batch, audit findings, verification date, deviations | a sidecar (`meta/<class>.json`) | not properties of the class; written by machinery; long-form; changes on a different schedule |

### Why the first three are not in a sidecar

**A sidecar does not travel.** abapGit pulls `src/`; a `meta/` folder never
reaches the SAP system. Three places that costs:

1. **In the system it is simply absent** — which is why an overview app that
   needs the data has to have it *baked in* by a generator.
2. **A search engine drops somebody into the `.clas.abap` on GitHub** and the
   code is all they get. This is the same argument `@docs` is a full URL for.
3. **An AI reading the class file gets no metadata** unless its tooling happens
   to know about `meta/`.

A `"` comment costs the ABAP nothing — it is not `"!`, so SLIN/ATC does not
report an unknown tag — and it cannot desync from the class, because it is in
the class.

### Why the rest is not on the class

A deviation note with three paragraphs and a verification date is not a
property of the class; it is a log entry about a process, usually written by a
test run rather than by an author. Putting it in a `"` comment would bloat the
source and would still be worse structured than JSON. That belongs beside the
class, and the sidecar is right for it.

### The test, when a new field turns up

Ask: *would this still be true if nobody ever ran a check again?* If yes it
describes the sample and belongs on the class. If it only became true because
somebody did something, it belongs in the sidecar.
