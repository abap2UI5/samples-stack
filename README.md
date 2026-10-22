# abap2UI5 — samples-stack — Adobe Forms

**One package, nothing else.** This branch is generated from
[`main`](https://github.com/abap2UI5/samples-stack/blob/main/README.md) and carries [`src/14`](src/14) only, so
you can pull the one thing you came for instead of all 14 packages of the
repository — the other 13 bring technology your system may not have, or may
not be able to activate at all.

**Runs on:** Standard only, ≥ 7.50

Renders through the classic Adobe Forms runtime (FP_JOB_OPEN, the generated
function module, FP_JOB_CLOSE), which is not released for ABAP Cloud. Needs
Adobe Document Services configured.

## Setup

1. Install [abap2UI5](https://github.com/abap2UI5/abap2UI5).
2. Pull **this branch** with [abapGit](https://abapgit.org) — pick `14-adobe-forms` in
   the branch dropdown.
3. Set up whatever the package builds on: **[src/14/README.md](src/14/README.md)**
   says so in one short section.
4. Start a sample with `?app_start=<class name>`, or start the overview with
   `?app_start=z2ui5_cl_smps_app_000`.

The overview app ships on every branch and lists **all 44 samples** of the
repository, not just this package's. The ones that are not on this branch are
shown with their Open button disabled — so it doubles as the catalogue of what
the other branches hold.

## Generated — do not work here

This branch is rebuilt and force-pushed on every push to `main`. Anything
committed here is gone at the next build, and a pull request against it cannot be
merged anywhere useful.

- **Issues and pull requests go to [`main`](https://github.com/abap2UI5/samples-stack)**, which
  carries all 14 packages and their READMEs.
- Built by [`create-package-branches.yaml`](https://github.com/abap2UI5/samples-stack/blob/main/.github/workflows/create-package-branches.yaml)
  from [`.github/packages.json`](https://github.com/abap2UI5/samples-stack/blob/main/.github/packages.json); abaplint checked
  this tree at `v750` before it was pushed.

## License

[MIT](LICENSE), same as the repository.
