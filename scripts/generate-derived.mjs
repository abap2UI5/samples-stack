#!/usr/bin/env node
/*
 * generate-derived — catalogue-derived.json, what the LINTER knows about each
 * sample, beside what catalogue.json says the tree holds.
 *
 * This repository's own facets were never derived: what a sample NEEDS from a
 * system - the release, Cloud or Standard, the technology it demonstrates -
 * is committed fact in catalogue.json, because it is the one thing that
 * decides whether a reader can use a sample at all, and no linter can tell you
 * whether a system has a RAP stack.
 *
 * What no file here could answer is the question the catalogue gets when it is
 * read together with the other two corpora:
 *
 *   "which sample shows sap.m.Table at all?"
 *
 * That is a question about the VIEW, and @abap2ui5/linter answers it by
 * reconstructing the view a builder chain produces:
 *
 *   stats.types            every control the sample BUILDS, with occurrences
 *   `*-too-new` findings   everything above the 1.71 floor, each with `since`
 *
 * The highest of those `since` values IS the sample's minimum UI5 release, and
 * the floor itself when there are none. Worth deriving here even though most
 * samples in this repository are gated by their ABAP release long before their
 * UI5 one: a reader filtering the three corpora at once filters all three the
 * same way, and a sample that silently carried no release would drop out of
 * every filtered list.
 *
 * NOT every sample is view code. Several here are the backend half of a
 * story - a RAP behaviour, an OData service, an APC handler - and the linter
 * finds no chain in them. Those get `noChain: true` rather than an empty
 * control list, because "builds nothing" and "is not a view" are different
 * answers and a consumer must not read the first as the second.
 *
 * WHY IT IS A SECOND FILE. Everything committed-fact about a sample - class,
 * path, package, technology, title, summary, keywords, runsOn, cloud, needs,
 * branch, setup - is in catalogue.json already, and that file is generated
 * offline and dependency-free on purpose. This one carries ONLY the derived
 * facts, keyed by `class`: a consumer joins the two on that key.
 *
 * Which UI5 LIBRARY each control ships in is deliberately not answered here.
 * That is one taxonomy question, and answering it in three sample
 * repositories would be three copies of a prefix table that drift; the
 * consumer that needs it - the playground's catalogue, which has to decide
 * "does this render on the build I carry" - owns the mapping. Identical file
 * shape and identical reasoning in abap2UI5/samples and
 * abap2UI5/samples-controls.
 *
 * The classes are read from `main`, where every one of them is, even though
 * the catalogue points a reader at the generated one-package branch that
 * delivers it.
 *
 * COMMITTED, and read from raw.githubusercontent.com by the playground's
 * deploy, which serves committed files only.
 *
 *   node scripts/generate-derived.mjs          write catalogue-derived.json
 *   node scripts/generate-derived.mjs --check  fail if it is stale (CI)
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { checkAbapSource } from '@abap2ui5/linter';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(HERE, '..');
const OUT = path.join(ROOT, 'catalogue-derived.json');
const CHECK = process.argv.includes('--check');

/** The floor the framework holds every view to. */
const MIN_UI5 = '1.71';

/** The repository a consumer joins this against. */
const REPO = 'abap2UI5/samples-stack';
const REF = 'main';

/** Compare two dotted UI5 versions numerically ("1.9" < "1.71" < "1.120"). */
function cmpVersion(a, b) {
  const pa = String(a).split('.').map(Number);
  const pb = String(b).split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d) return d;
  }
  return 0;
}

/** "1.77.0" / "1.77" -> "1.77" — the minor is what a system is called by. */
const shortVersion = (v) => String(v).split('.').slice(0, 2).join('.');

/* ---------------------------------------------------------------- collect */

/* The catalogue is the list of samples - the same set, in the same order,
 * that a consumer will be joining this onto. Reading the tree independently
 * would be a second definition of "is a sample" for the two files to disagree
 * over. */
const catalogue = JSON.parse(fs.readFileSync(path.join(ROOT, 'catalogue.json'), 'utf8'));

const controlIds = new Map();          // control name -> index in `controls`
const idOf = (name) => {
  if (!controlIds.has(name)) controlIds.set(name, controlIds.size);
  return controlIds.get(name);
};

const samples = [];
let failed = 0;

for (const entry of catalogue.samples) {
  const rel = entry.path;
  const file = path.join(ROOT, rel);
  if (!fs.existsSync(file)) {
    console.error(`generate-derived: ${rel} is in catalogue.json but not on main`);
    process.exit(1);
  }
  const source = fs.readFileSync(file, 'utf8');

  let types = {};
  let tooNew = [];
  let usesBuilder = false;
  let note = null;
  try {
    const r = checkAbapSource(source, { minUi5: MIN_UI5, render: false, file: rel });
    usesBuilder = !!r.usesBuilder;
    types = r.stats?.types || {};
    tooNew = r.findings
      .filter((f) => /-too-new$/.test(f.type) && f.since)
      .map((f) => ({
        type: f.type,
        name: [f.control, f.member, f.value].filter(Boolean).join('.') || f.type,
        since: shortVersion(f.since),
      }));
  } catch (err) {
    failed++;
    note = `linter: ${err.message}`;
  }

  const minUi5 = tooNew.reduce(
    (acc, f) => (cmpVersion(f.since, acc) > 0 ? f.since : acc),
    MIN_UI5,
  );
  const controls = Object.keys(types).sort();

  samples.push({
    /* The key a consumer joins catalogue.json on - the same spelling that
     * file uses. */
    class: entry.class,
    minUi5,
    needs: tooNew.sort((a, b) => cmpVersion(b.since, a.since) || a.name.localeCompare(b.name)),
    controls: controls.map(idOf),
    controlCount: Object.values(types).reduce((a, b) => a + b, 0),
    /* Not view code - the backend half of a story, or a handler. See the
     * header: this is not the same as building no controls. */
    ...(usesBuilder ? {} : { noChain: true }),
    ...(note ? { note } : {}),
  });
}

/* ------------------------------------------------------------------ write */

const controls = [...controlIds.keys()];
const releases = [...new Set(samples.map((s) => s.minUi5))].sort(cmpVersion);

const top = {
  note: 'Generated by scripts/generate-derived.mjs. What the linter knows about each sample; '
    + 'the committed facts are in catalogue.json, joined on `class`. Do not hand-edit.',
  repo: REPO,
  ref: REF,
  catalogue: `https://raw.githubusercontent.com/${REPO}/${REF}/catalogue.json`,
  minUi5: MIN_UI5,
  releases,
  controls,
  counts: {
    samples: samples.length,
    controls: controls.length,
    noChain: samples.filter((s) => s.noChain).length,
  },
};

/* One line per sample, so a sample PR diffs as one changed line. */
const head = JSON.stringify(top, null, 2);
const body = samples
  .sort((a, b) => a.class.localeCompare(b.class))
  .map((s) => `    ${JSON.stringify(s)}`)
  .join(',\n');
const page = `${head.slice(0, -2)},\n  "samples": [\n${body}\n  ]\n}\n`;

if (CHECK) {
  const current = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (current !== page) {
    console.error('catalogue-derived.json is stale — run `npm run derived` and commit the result.');
    process.exit(1);
  }
  console.log(`catalogue-derived.json: current (${samples.length} samples)`);
} else {
  fs.writeFileSync(OUT, page);
  const size = (fs.statSync(OUT).size / 1024).toFixed(0);
  console.log(
    `catalogue-derived.json: ${samples.length} samples, ${controls.length} controls, `
    + `${top.counts.noChain} not view code, releases ${releases[0]}–${releases[releases.length - 1]} (${size} KB)`,
  );
}
if (failed) console.error(`generate-derived: ${failed} sample(s) the linter could not reconstruct — see \`note\``);
