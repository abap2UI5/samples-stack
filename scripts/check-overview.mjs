#!/usr/bin/env node
// Keeps the overview app and the repository in sync.
//
// z2ui5_cl_smps_app_000 references every sample BY NAME and resolves it at
// runtime, so that it survives a package the system cannot activate and a
// checkout that carries only part of this repository (see the class
// documentation). The price is that the compiler no longer notices a renamed
// or a newly added sample - this check is what notices instead.
//
// Five directions:
//   1. every sample class in the tree is listed in the overview  (always)
//   2. every class the overview names exists in the tree         (full tree only)
//   3. every package of .github/packages.json is in the README
//      table with the release it declares                        (full tree only)
//   4. every object the overview references STATICALLY survives on
//      every generated package branch                            (full tree only)
//   5. the README's "Which package do I need?" table routes to
//      every package exactly once                                (full tree only)
//
// (3) is the second index this repository keeps by hand: packages.json drives
// the generated per-package branches and the release each one is checked at,
// the README table tells the reader the same thing in prose. They drift apart
// silently, so they are compared here.
//
// (5) is the third: the decision table phrases each package from the reader's
// goal, which no generator can write, so it is prose kept by hand. A package
// added without a row is a package nobody is routed to, and a row pointing at
// a directory that is gone routes to nothing - both are the same silent drift
// as (3), so they are gated the same way.
//
// (4) is the rule the class documentation states and nothing enforced: the
// overview ships on every branch, but a branch carries only its own package
// plus whatever it names in "shared", so a static reference into any other
// package leaves that branch with an overview that does not activate. It
// happened - z2ui5_cl_smps_context=>app_get_url( ) took seven of the nine
// branches down for a day, and the nine-job branch matrix was the first thing
// to say so. This check says it in a second, before the matrix ever starts.
//
// (2), (3) and (4) are skipped when a package directory is missing: a checkout
// with a single package is a supported case - it is what the generated branches
// are - and there the overview lists classes that are legitimately absent. At
// runtime they simply show up as "not on this system".

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, basename } from 'node:path';

const SRC = 'src';
const OVERVIEW = join(SRC, 'z2ui5_cl_smps_app_000.clas.abap');
const packages = JSON.parse(readFileSync(join('.github', 'packages.json'), 'utf8'));
const PACKAGES = packages.map((entry) => entry.dir);

const walk = (dir) =>
  readdirSync(dir).flatMap((entry) => {
    const path = join(dir, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });

const files = walk(SRC);

// a sample is an ABAP class implementing z2ui5_if_app - which leaves out
// z2ui5_cl_smps_app_489_ws, the APC handler behind sample 489, and the
// overview itself
const samples = files
  .filter((path) => /^z2ui5_cl_smps_app_.*\.clas\.abap$/.test(basename(path)))
  .filter((path) => basename(path) !== basename(OVERVIEW))
  .filter((path) => /INTERFACES\s+z2ui5_if_app\s*\./i.test(readFileSync(path, 'utf8')))
  .map((path) => basename(path).replace('.clas.abap', '').toUpperCase());

// every Z2UI5_CL_SMPS_* class name the overview carries as a string literal:
// the samples in model_init and the two demo data classes in cs_class
const overview = readFileSync(OVERVIEW, 'utf8');
const listed = [...overview.matchAll(/`(Z2UI5_C[LX]_SMPS_[A-Z0-9_]+)`/g)].map((match) => match[1]);

const known = new Set(
  files
    .filter((path) => path.endsWith('.clas.abap'))
    .map((path) => basename(path).replace('.clas.abap', '').toUpperCase()),
);

const complete = PACKAGES.every((pkg) => files.some((path) => path.startsWith(join(SRC, pkg))));

const errors = [];

for (const name of samples) {
  if (!listed.includes(name)) {
    errors.push(`${name} is a sample of this repository but is not listed in ${OVERVIEW}`);
  }
}

for (const name of new Set(listed)) {
  if (complete && !known.has(name)) {
    errors.push(`${OVERVIEW} names ${name}, but no such class exists - renamed or mistyped?`);
  }
}

if (complete) {
  // the overview with its comments and its string literals taken out. What is
  // left is ABAP the compiler resolves, so a Z2UI5_*_SMPS_* name in there is
  // a STATIC reference - the by-name lookups all sit inside backticks and are
  // gone by now. Template literals keep their embedded { ... } expressions,
  // which are code as well; only their literal text is dropped.
  const code = overview
    .replace(/`[^`\n]*`/g, '``')
    .replace(/'[^'\n]*'/g, "''")
    .replace(/\|[^|{}\n]*\|/g, '||')
    .split('\n')
    .map((line) => (line.trimStart().startsWith('*') ? '' : line.replace(/".*$/, '')))
    .join('\n');

  // where each object of the tree lives, as the top level entry under src/
  // that build-package-branch.mjs keeps or deletes as a whole. Every object
  // type counts, not classes alone: a TYPE REF TO an interface, a TYPE of a
  // table, data element or CDS entity of another package takes the branch's
  // overview down exactly like a class reference does. The object name is the
  // file name up to its first dot (abapGit's naming), the MIME and namespace
  // files under src/ never carry a Z2UI5_..._SMPS_ name and drop out below.
  const home = new Map(
    files
      .filter((path) => !basename(path).startsWith('package.'))
      .map((path) => [basename(path).split('.')[0].toLowerCase(), path.split(/[\\/]/)[1]]),
  );

  // what every branch keeps out of src/ on top of its own package - the same
  // list build-package-branch.mjs applies, and the reason the overview itself
  // is not reported here
  const always = /^(package\.devc\.xml|z2ui5_cl_smps_app_000\.clas\..*)$/;

  // ABAP is case-insensitive, so the scan is too: Z2UI5_CL_SMPS_X=>y( ) is
  // the same static reference as z2ui5_cl_smps_x=>y( ). Classes, exception
  // classes, interfaces, tables, data elements and CDS entities - every
  // Z2UI5_<type>_SMPS_ object type the naming rule hands out.
  const staticRefs = [...code.matchAll(/\bz2ui5_[a-z]{1,2}_smps_[a-z0-9_]+/gi)].map((m) => m[0].toLowerCase());
  for (const name of new Set(staticRefs)) {
    const dir = home.get(name);
    if (dir === undefined || always.test(dir)) continue;

    const orphans = packages
      .filter((entry) => entry.dir !== dir && !entry.shared.includes(dir))
      .map((entry) => entry.branch);

    if (orphans.length > 0) {
      errors.push(
        `${OVERVIEW} references ${name.toUpperCase()} statically, but src/${dir} is not on ` +
          `${orphans.length} of the ${packages.length} generated branches (${orphans.join(', ')}) - ` +
          `use the framework instead, or add "${dir}" to their "shared" in .github/packages.json`,
      );
    }
  }

  const readme = readFileSync('README.md', 'utf8');
  const rows = readme.split('\n').filter((line) => line.startsWith('| [`src/'));

  for (const entry of packages) {
    const row = rows.find((line) => line.startsWith(`| [\`src/${entry.dir}\`]`));
    if (!row) {
      errors.push(`README.md has no table row for src/${entry.dir}`);
    } else if (!row.includes(entry.runsOn)) {
      errors.push(
        `README.md row for src/${entry.dir} does not carry the release ` +
          `.github/packages.json declares ("${entry.runsOn}")`,
      );
    }
  }

  // the decision table - "You want to ... -> package". Its rows start with the
  // reader's goal, not with the directory, so they are found by the link they
  // carry rather than by the row shape the package table above is found by
  const aid = readme.split(/\n## /).find((section) => section.startsWith('Which package do I need'));
  if (aid === undefined) {
    errors.push('README.md has no "Which package do I need?" section');
  } else {
    for (const entry of packages) {
      const links = (aid.match(new RegExp(`\\[\`src/${entry.dir}\`\\]`, 'g')) ?? []).length;
      if (links !== 1) {
        errors.push(
          `the "Which package do I need?" table must route to src/${entry.dir} exactly once, ` +
            `but points at it ${links} time(s)`,
        );
      }
    }
  }
}

if (errors.length > 0) {
  console.error('check-overview failed:\n');
  for (const error of errors) console.error(`  - ${error}`);
  console.error(`\n${samples.length} sample(s) in the tree, ${new Set(listed).size} class(es) listed.`);
  process.exit(1);
}

console.log(
  `check-overview: ${samples.length} sample(s) listed in the overview` +
    (complete ? ', every referenced class exists' : ', partial checkout - existence not checked'),
);
