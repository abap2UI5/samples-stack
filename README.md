# abap2UI5 — samples-stack — AI / LLM

**One package, nothing else.** This branch is generated from
[`main`](https://github.com/abap2UI5/samples-stack/blob/main/README.md) and carries [`src/10`](src/10) only, so
you can pull the one thing you came for instead of all 10 packages of the
repository — the other 9 bring technology your system may not have, or may
not be able to activate at all.

**Runs on:** Cloud + Standard ≥ 7.40 SP08

The HTTP transport comes once per stack, and each half activates on its own
stack only: src/10/01 (cl_http_client on an SM59 destination) on Standard,
src/10/02 (cl_web_http_client_manager on a BTP destination) on ABAP Cloud,
src/10/03 only where SAP's ABAP AI SDK is installed. An activation error for the
half your system does not have is expected - the samples create the transport by
name and use the one that is there. That is also why this branch is linted at
7.51 although the package runs from 7.40 SP08: everything but src/10/02 parses
at 7.40 SP08, and src/10/02 is ABAP Cloud code whose released enums need 7.51
syntax.

## Setup

1. Install [abap2UI5](https://github.com/abap2UI5/abap2UI5).
2. Pull **this branch** with [abapGit](https://abapgit.org) — pick `10-ai-llm` in
   the branch dropdown.
3. Set up whatever the package builds on: **[src/10/README.md](src/10/README.md)**
   says so in one short section.
4. Start a sample with `?app_start=<class name>`, or start the overview with
   `?app_start=z2ui5_cl_smps_app_000`.

The overview app ships on every branch and lists **all 34 samples** of the
repository, not just this package's. The ones that are not on this branch are
shown with their Open button disabled — so it doubles as the catalogue of what
the other branches hold.

## Generated — do not work here

This branch is rebuilt and force-pushed on every push to `main`. Anything
committed here is gone at the next build, and a pull request against it cannot be
merged anywhere useful.

- **Issues and pull requests go to [`main`](https://github.com/abap2UI5/samples-stack)**, which
  carries all 10 packages and their READMEs.
- Built by [`create-package-branches.yaml`](https://github.com/abap2UI5/samples-stack/blob/main/.github/workflows/create-package-branches.yaml)
  from [`.github/packages.json`](https://github.com/abap2UI5/samples-stack/blob/main/.github/packages.json); abaplint checked
  this tree at `v751` and in the ABAP Cloud language version before it was pushed.

## License

[MIT](LICENSE), same as the repository.
