# 08 — MIME Play Audio

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

[`487`](z2ui5_cl_smps_app_487.clas.abap) plays a sound stored in the **MIME
repository**, addressed by its ICF path — a success and an error tone, both shipped
with this package ([`src/08/01`](01)).

A small sample with a general point: anything the system already serves over an ICF
path — a sound, an image, a document — is one URL away from an abap2UI5 view. The
repository stays where it is; the app only points at it.

## What you need

**Release:** Standard only, ≥ 7.50. The MIME repository behind an ICF path is
on-premise: in ABAP Cloud there is neither the repository nor the node to reach it
through.

**Branch:** [`08-mime`](https://github.com/abap2UI5/samples-stack/tree/08-mime)
— this package alone, without the other eight on your system.

**Setup:** activate the ICF service `/SAP/PUBLIC/BC/ABAP/mime_demo` in `SICF`. The
app checks the node and warns if it is inactive.

## The sample

Start it with `?app_start=z2ui5_cl_smps_app_487`, or from the overview app
`?app_start=z2ui5_cl_smps_app_000`, which lists every sample of this repository.
Type the magic key the app tells you and you get the success sound; type anything
else and you get the error one.

## Where to go next

- [`09` Launchpad](https://github.com/abap2UI5/samples-stack/blob/main/src/09/README.md) — one more thing the system already serves: the
  shell the app can run inside.
- [`01` OData](https://github.com/abap2UI5/samples-stack/blob/main/src/01/README.md) — back to the beginning: data from a service instead
  of bytes from the repository.
