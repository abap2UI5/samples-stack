#!/usr/bin/env node
// Reduces a checkout of this repository to ONE package, so that it can be
// force-pushed as that package's branch. See create-package-branches.yaml.
//
// Why: abapGit imports a whole repository, there is no sparse checkout. This
// repository spans ten packages with different floors - three of them are
// on-premise only, three need 1909 or newer - so a system that only wants
// src/01 today has to take src/06, src/07 and src/08 with it and gets
// activation errors for technology it never asked for. One branch per package
// makes the abapGit branch dropdown the place where you pick your feature.
//
// Usage: node scripts/build-package-branch.mjs <branch>
//
// DESTRUCTIVE - it rewrites the working tree in place. Run it on a throwaway
// CI checkout, never on a tree you still want.

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { basename, join } from 'node:path';

const REPO = 'abap2UI5/samples-stack';
const MAIN = `https://github.com/${REPO}/blob/main`;
const SRC = 'src';

// what every branch keeps out of src/, on top of its own package: the root
// package.devc.xml (abapGit needs the parent package) and the overview app,
// which is the entry point on every branch - it lists every sample of the
// repository and marks the ones this checkout does not carry as "not on this
// system"
const SRC_ALWAYS = /^(package\.devc\.xml|z2ui5_cl_smps_app_000\.clas\..*)$/;

const branch = process.argv[2];
if (!branch) {
  console.error('usage: build-package-branch.mjs <branch>');
  process.exit(2);
}

const packages = JSON.parse(readFileSync('.github/packages.json', 'utf8'));
const pkg = packages.find((entry) => entry.branch === branch);
if (!pkg) {
  console.error(`unknown branch "${branch}" - known: ${packages.map((p) => p.branch).join(', ')}`);
  process.exit(2);
}

const keep = new Set([pkg.dir, ...pkg.shared]);

// counted here, on the full tree, before step 1 takes the other packages out -
// the README below states it, and a number written by hand drifts the moment a
// sample is added. Same definition as check-overview.mjs: a class implementing
// z2ui5_if_app, which leaves out the APC handler and the overview itself
const walk = (dir) =>
  readdirSync(dir).flatMap((entry) => {
    const path = join(dir, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });

const samples = walk(SRC)
  .filter((path) => /^z2ui5_cl_smps_app_.*\.clas\.abap$/.test(basename(path)))
  .filter((path) => basename(path) !== 'z2ui5_cl_smps_app_000.clas.abap')
  .filter((path) => /INTERFACES\s+z2ui5_if_app\s*\./i.test(readFileSync(path, 'utf8'))).length;

// 1. everything in src/ that is not this package, its shared dependencies or
//    one of the always-kept root entries
for (const entry of readdirSync(SRC)) {
  if (keep.has(entry) || SRC_ALWAYS.test(entry)) continue;
  rmSync(join(SRC, entry), { recursive: true, force: true });
}

// 1b. SAMPLES.md and catalogue.json, regenerated for what is left. Copied
//     over from main they list every package and link to classes and READMEs
//     this branch does not carry. The generators stay the one source: they
//     scan the tree they run in, which is now this package alone. Before step
//     5, because the catalogue reads the package table of the root README,
//     which that step replaces. catalogue-derived.json is left as it is - it
//     is keyed by class, links nowhere, and needs a linter pass to rebuild.
for (const generator of ['generate-samples-md.mjs', 'generate-catalogue.mjs']) {
  execFileSync(process.execPath, [join('scripts', generator)], { stdio: 'inherit' });
}

// 2. the workflows. A generated branch runs no CI of its own: pushes made with
//    GITHUB_TOKEN do not trigger workflow runs anyway, and the branch is
//    already verified by the job that builds it. `scripts/` and
//    .github/packages.json stay, so `npm run check:overview` still works on a
//    branch.
rmSync(join('.github', 'workflows'), { recursive: true, force: true });

// 3. abaplint checks the branch at the release the package actually needs
//    rather than at the v757 of the full tree. That is what verifies the
//    "Runs on" column, and it is also what catches a package that has quietly
//    grown a dependency on one of the others.
const lint = readFileSync('abaplint.jsonc', 'utf8').split('\n');
const version = lint.findIndex((line) => /"version"\s*:/.test(line));
if (version < 0) throw new Error('no "version" key in abaplint.jsonc');
let first = version;
while (first > 0 && lint[first - 1].trim().startsWith('//')) first -= 1;
const indent = lint[version].match(/^\s*/)[0];
lint.splice(
  first,
  version - first + 1,
  `${indent}// GENERATED - the branch "${branch}" carries src/${pkg.dir} alone, so it is`,
  `${indent}// checked at the release that package needs, not at the v757 of the`,
  `${indent}// full tree on main. See .github/packages.json.`,
  `${indent}"version": "${pkg.syntax}",`,
);
writeFileSync('abaplint.jsonc', lint.join('\n'));

// 4. the package README stays where it is, so its links into its own package
//    keep working - but everything pointing at another package has to leave
//    the branch, because that package is not here any more
const readme = join(SRC, pkg.dir, 'README.md');
writeFileSync(
  readme,
  readFileSync(readme, 'utf8')
    .replaceAll('](../../README.md)', `](${MAIN}/README.md)`)
    .replace(/\]\(\.\.\/(\d\d)\/README\.md\)/g, `](${MAIN}/src/$1/README.md)`),
);

// 5. a root README that says what this branch is, before anyone wonders why
//    the other packages are missing
const wrap = (text) =>
  text.split(' ').reduce((lines, word) => {
    const last = lines[lines.length - 1];
    if (last.length + word.length + 1 > 80) lines.push(word);
    else lines[lines.length - 1] = last === '' ? word : `${last} ${word}`;
    return lines;
  }, ['']).join('\n');

writeFileSync(
  'README.md',
  `# abap2UI5 — samples-stack — ${pkg.title}

**One package, nothing else.** This branch is generated from
[\`main\`](${MAIN}/README.md) and carries [\`src/${pkg.dir}\`](src/${pkg.dir}) only, so
you can pull the one thing you came for instead of all ${packages.length} packages of the
repository — the other ${packages.length - 1} bring technology your system may not have, or may
not be able to activate at all.

**Runs on:** ${pkg.runsOn}
${pkg.note ? `\n${wrap(pkg.note)}\n` : ''}
## Setup

1. Install [abap2UI5](https://github.com/abap2UI5/abap2UI5).
2. Pull **this branch** with [abapGit](https://abapgit.org) — pick \`${branch}\` in
   the branch dropdown.
3. Set up whatever the package builds on: **[src/${pkg.dir}/README.md](src/${pkg.dir}/README.md)**
   says so in one short section.
4. Start a sample with \`?app_start=<class name>\`, or start the overview with
   \`?app_start=z2ui5_cl_smps_app_000\`.

The overview app ships on every branch and lists **all ${samples} samples** of the
repository, not just this package's. The ones that are not on this branch are
shown with their Open button disabled — so it doubles as the catalogue of what
the other branches hold.

## Generated — do not work here

This branch is rebuilt and force-pushed on every push to \`main\`. Anything
committed here is gone at the next build, and a pull request against it cannot be
merged anywhere useful.

- **Issues and pull requests go to [\`main\`](https://github.com/${REPO})**, which
  carries all ${packages.length} packages and their READMEs.
- Built by [\`create-package-branches.yaml\`](${MAIN}/.github/workflows/create-package-branches.yaml)
  from [\`.github/packages.json\`](${MAIN}/.github/packages.json); abaplint checked
  this tree at \`${pkg.syntax}\` before it was pushed.

## License

[MIT](LICENSE), same as the repository.
`,
);

console.log(`build-package-branch: ${branch} <- src/${pkg.dir}` +
  `${pkg.shared.length > 0 ? ` (+ src/${pkg.shared.join(', src/')})` : ''}, abaplint at ${pkg.syntax}`);
