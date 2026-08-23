# `web/` — the page on GitHub Pages

**<https://abap2ui5.github.io/samples-stack/>** — every sample of this
repository, searchable by the technology it plays with and by the release your
system actually runs. Published by the
[`deploy-web`](../.github/workflows/deploy-web.yaml) workflow, which needs
*Settings → Pages → Source = GitHub Actions*.

```
web/index.html   the page — one file, no framework
web/stack.css    one stylesheet, light and dark off one set of custom properties
web/stack.js     filtering and drawing — plain ES2020, no dependencies
web/favicon.ico  the abap2UI5 logo in the tab (see below)
web/apps.json    generated, NOT committed (see below)
web/thumbs/      generated, NOT committed — one thumbnail per sample (see below)
```

## What it answers

It is the fourth view of the same catalogue, and the four are generated from
one scan (`scripts/lib/scan-samples.mjs`) so they cannot disagree:

| Where | For whom |
|---|---|
| `Z2UI5_CL_SMPS_APP_000`, the overview app | somebody who has this repository in a system |
| [`SAMPLES.md`](../SAMPLES.md) | somebody reading the repository on GitHub |
| the package READMEs | somebody who has already picked a technology |
| this page | somebody who has installed nothing and is asking whether their system can run any of it |

**The overview app is the one view that is not itself a card here.** It is this
same catalogue rendered inside a system, so as a card it said *needs nothing
beyond abap2UI5* on a page whose whole premise is that every sample needs
something from the system, and it took a technology chip of its own that
filtered the corpus down to one entry — itself. `generate-web-index.mjs` drops
the class and its group before the page ever sees them, and *How to run one*
names it in prose instead, where a way of browsing belongs. It stays in
[`SAMPLES.md`](../SAMPLES.md) and in
[`catalogue.json`](../catalogue.json), whose readers are inside the repository
already.

That last question is what makes this page different from the two next door.
[samples](https://abap2ui5.github.io/samples/) publishes a learning path,
because *"where do I start"* is what a newcomer arrives with;
[samples-controls](https://abap2ui5.github.io/samples-controls/) publishes a
search over 430 control ports, because *"which one shows a Wizard"* is what a
control reference is asked. Here everything needs something **from the system**,
so the two questions are:

> *"my system is 7.50 and on-premise — what of this can I even run?"*
> *"is there a sample for WebSockets, and what do I have to set up first?"*

Both are answered by facts the repository already keeps. `.github/packages.json`
declares each package's release and the branch it ships on; the README's package
table says what it plays together with; the classes carry `@summary`,
`@keywords` and — twelve of them — an ABAP-Doc header, which is the fullest
description this repository has of a sample and goes on the card behind *What
the class documents*.

The **Your system** facet is one select for both halves of the release
question: ABAP Cloud drops the three on-premise packages, a Standard release
keeps every package at or below it. The counts are in the labels, so what an
older system costs is visible before the click. Filters live in the URL, so a
search is linkable.

## The icon in the tab

`favicon.ico` is the abap2UI5 logo — the same mark
[the documentation](https://abap2ui5.github.io/docs/) puts in the tab, so the
four pages of the project read as one project in a row of browser tabs rather
than as three anonymous ones beside it.

It is the artwork of `docs/public/favicon.ico` in
[abap2UI5/docs](https://github.com/abap2UI5/docs), rescaled: that file is one
256 px frame stored uncompressed, 265 KB, which is twenty times this whole page
for something a browser draws at 16 px. This one carries 16/32/48/64/128 px as
PNG frames in ~16 KB, so every size the browser asks for is a frame that was
drawn for it and none of them is squashed — the source is 256 × 251, not
square, so a single frame is what a browser distorts. Identical in all three
sample repositories.

## The bar at the top is shared, and so is the strip at the bottom

Three repositories publish three pages that answer three different questions,
and until now only one of them said so. Two blocks fix that, and both are
**identical in all three repositories**:

| | |
|---|---|
| `<nav class="family">` | above the masthead: *Learn · Controls · Stack*, the current one marked with `aria-current`, and the playground and the documentation set apart on the right as the tools they are |
| `<section class="three">` | before the footer: one card per page with the question it answers, because the end of a page is where a reader who is done with it arrives |

They carry verbs rather than repository names — `samples-controls` tells a
newcomer nothing, *Controls / every UI5 control, searchable* tells them
everything — and the repository name lives in the `title` attribute and the
footer instead. There is no numbering: *step 3 of 3* used to be on the
samples-stack page and claimed an order that does not hold, since Controls is
a reference you come back to rather than a step you finish.

Three repositories cannot share a file at run time without one page fetching
something from another host, which is exactly what these pages avoid, so the
blocks are **copied**. That is already the practice here — the design tokens
in this stylesheet are a declared copy — and `npm run check:family-nav` is what
keeps the copies honest: it fails when a subtitle is reworded on one page only,
when the *you are here* marker is left on whichever page was copied from, when
a sibling drops out of the footer, or when anything links
`…/samples-controls/search/` again, which has been a 404 since that catalogue
moved to the root of its site.

The styles sit at the end of the stylesheet between the same markers and read
three tokens the page sets in `:root` — `--family-width`, `--family-gutter` and
`--family-bleed`. Those three are the *only* thing the copies are allowed to
differ in, because the three pages are built around containers of different
widths.

## There is no playground link

The other two pages open a class in the
[playground](https://abap2ui5.github.io/playground/) — the ABAP in an editor
with the app running beside it, no system anywhere. That is exactly what cannot
work here: a Gateway service, a RAP business object, an APC channel, a launchpad
is what every sample in this repository needs, and none of it exists in that
frame. Every app would open and then fail.

So the cards link where a link can help: **Source** (one class, the whole
sample), **Setup** (the package README's *What you need* section) and **Branch**
(the generated one-package branch, which is what you give abapGit if you only
want this package on your system).

## `apps.json` is not committed

It is derived from the tree, so committing it would put a diff of derived data
on every sample pull request while adding a gate that can only restate what the
generator already says. `deploy-web` regenerates it on every deploy instead, so
it is never staler than the site serving it.

```bash
npm run web:index      # node scripts/generate-web-index.mjs
npm run check:web      # what CI runs: validate, write nothing
```

`npm run check:web` is part of `npm run check` and has its own workflow. It
holds what a pull request can break without touching this folder: a package
with no README row, a row whose cells no longer parse, an app in a directory
that is no package of `.github/packages.json`.

## `thumbs/` is not committed either

One thumbnail per sample, photographed by `npm run screenshots`
(`scripts/generate-screenshots.mjs`): the abap2UI5-linter's render harness —
the same headless reconstruction `npm run check:abap2ui5`'s render gate
clears — renders each class's main view with mock data and no system behind
it, and the deploy writes the pictures fresh on every run. It needs the
devDependencies and a playwright chromium, which is why `deploy-web` runs
`npm ci` where the catalogue alone would not need it.

Not every card has a picture, by design: a view the harness cannot render is
reported and skipped — the `sap.ui.comp` smart controls (SAPUI5-only, not in
the harness's OpenUI5 runtime) and the `z2ui5.cc` custom controls, mostly —
and the `<img>` removes itself when its file is missing, so a card without a
thumbnail is complete, not broken. AGENTS.md §8 carries the measured count.
The script photographs exactly what the page draws a card for, so it skips the
overview app too — a picture no card loads is a render per deploy for nothing.

## Running it locally

Nothing to build:

```bash
npm run web:index
npm run screenshots                            # optional: writes web/thumbs/
python3 -m http.server 8099 --directory web    # any static server will do
```

`file://` does not work — the page `fetch`es `apps.json`. The thumbnails are
optional because the page is complete without them. Every outgoing link is
absolute (GitHub), so they work from a local server exactly as in production.
