/*
 * read-packages — the package index with its prose, merged and verified.
 *
 * Two generators describe the packages: `generate-web-index.mjs` builds the
 * data behind the page in web/, `generate-catalogue.mjs` writes the committed
 * catalogue.json. Both need the same merge of the same two sources, and two
 * copies of a merge drift exactly the way two copies of the sample scan once
 * did (see scan-samples.mjs) — so it lives here once.
 *
 * The two sources, and no fact is restated here:
 *
 *   .github/packages.json          the package index: directory, branch name,
 *                                  title, the release the package needs. It
 *                                  drives the generated one-package branches,
 *                                  so what it declares is what is checked.
 *   README.md, the package table   what the package plays together with, and
 *                                  the one line describing it. That column is
 *                                  written for a reader and there is nowhere
 *                                  better to keep it; check-overview.mjs
 *                                  already gates that every package has a row
 *                                  carrying the release packages.json declares.
 */
import fs from 'fs';
import path from 'path';

/* The overview app sits in `src/` itself and is in no package, because it
 * ships on EVERY generated branch (AGENTS.md section 3). It is still an app a
 * reader starts, so it gets a group of its own rather than being dropped.
 *
 * The release is not invented: the branch build lints the overview at its
 * branch's own syntax version, and the lowest of those is v740sp08 — so
 * 7.40 SP08 is measured, exactly like the numbers in packages.json. Cloud
 * likewise: the overview resolves every sample by name at runtime and calls no
 * on-premise API, which is what puts it on the cloud-capable branches.
 *
 * The page in web/ is the one consumer that drops this group again — there the
 * overview app is not a sample of the stack but the same catalogue in a system,
 * and generate-web-index.mjs says why. catalogue.json keeps it. */
export const OVERVIEW_PKG = {
  dir: '.',
  branch: 'main',
  title: 'Overview',
  topic: 'the catalogue of this repository, inside your system',
  needs: 'nothing beyond abap2UI5 — it ships on every branch and resolves every sample at runtime',
  runsOn: 'Cloud + Standard ≥ 7.40 SP08',
  readme: 'README.md',
};

const die = (message) => {
  console.error(`read-packages: ${message}`);
  process.exit(1);
};

/**
 * The `What is in here` table of the root README, by package directory.
 *
 * | [`src/01`](src/01) | **[OData](…)** — bind a table … | an activated … | Cloud + … |
 *
 * `topic` is the half of the second cell behind the em dash, `needs` the third
 * cell — the "Plays together with" column, which is the answer to "what do I
 * have to have before this sample does anything".
 */
export function readmeTable(root) {
  const rows = fs.readFileSync(path.join(root, 'README.md'), 'utf8')
    .split('\n')
    .filter((line) => line.startsWith('| [`src/'));

  const table = new Map();
  let previous = '';
  for (const line of rows) {
    const cells = line.split('|').slice(1, -1).map((c) => c.trim());
    const dir = (cells[0].match(/src\/(\S+?)`/) || [])[1];
    if (!dir) die(`cannot read the package directory out of README row:\n    ${line}`);

    const topic = (cells[1].split('—')[1] || '').trim();
    if (!topic) die(`the README row for src/${dir} has no "— what it is" half in its Topic cell`);

    /* `as above` is how the table says "the same as the row before" — a
     * sentence for a reader, and nothing a card can show on its own. */
    const needs = /^as above$/i.test(cells[2]) ? previous : cells[2];
    if (!needs) die(`the README row for src/${dir} has an empty "Plays together with" cell`);
    previous = needs;

    table.set(dir, { topic, needs, runsOn: cells[3] });
  }
  return table;
}

/**
 * The release floor of a `runsOn` string, as a number that sorts.
 *
 *   "Cloud + Standard ≥ 7.40 SP08"  ->  740.08, "7.40 SP08"
 *   "Standard only, ≥ 7.54 (1909)"  ->  754,    "7.54 (1909)"
 *
 * SP as hundredths, so 7.40 SP08 sorts below 7.50 and above a bare 7.40 — the
 * order the page's facet needs, and the only arithmetic on a release number
 * anywhere.
 */
export function release(runsOn) {
  const m = runsOn.match(/≥\s*(\d)\.(\d\d)(?:\s*SP(\d+))?/);
  if (!m) die(`cannot read a release out of "${runsOn}" — expected "≥ 7.40 SP08" or "≥ 7.54"`);
  const platform = (runsOn.match(/\((\d{4})\)/) || [])[1] || '';
  return {
    num: Number(`${m[1]}${m[2]}`) + (m[3] ? Number(m[3]) / 100 : 0),
    label: `${m[1]}.${m[2]}${m[3] ? ` SP${m[3]}` : ''}${platform ? ` (${platform})` : ''}`,
  };
}

/**
 * Every package with its prose, the overview group first — facts only, in
 * `.github/packages.json` order. A consumer that keeps its own derived state
 * (the page counts its apps per group) adds it on its side.
 *
 * @returns {{dir: string, branch: string, title: string, topic: string,
 *            needs: string, runsOn: string, cloud: boolean, release: string,
 *            releaseNum: number, note: string, readme: string}[]}
 */
export function packages(root) {
  const declared = JSON.parse(fs.readFileSync(path.join(root, '.github', 'packages.json'), 'utf8'));
  const table = readmeTable(root);

  const build = (entry, prose) => {
    const { num, label } = release(entry.runsOn);
    return {
      dir: entry.dir,
      branch: entry.branch,
      title: entry.title,
      topic: prose.topic,
      needs: prose.needs,
      runsOn: entry.runsOn,
      /* "Cloud + Standard ≥ x" vs "Standard only, ≥ x" — the one fact that
       * decides whether a BTP tenant can see the sample at all. */
      cloud: /cloud/i.test(entry.runsOn),
      release: label,
      releaseNum: num,
      note: entry.note || '',
      readme: entry.readme || `src/${entry.dir}/README.md`,
    };
  };

  const out = [build(OVERVIEW_PKG, OVERVIEW_PKG)];
  for (const entry of declared) {
    const prose = table.get(entry.dir);
    /* check-overview.mjs fails on this too, and from the other side. Repeated
     * here because a generator cannot describe a package it cannot read. */
    if (!prose) die(`src/${entry.dir} is in .github/packages.json but has no row in the README table`);
    if (prose.runsOn !== entry.runsOn) {
      die(`src/${entry.dir}: README says "${prose.runsOn}", packages.json says "${entry.runsOn}"`);
    }
    out.push(build(entry, prose));
  }
  return out;
}
