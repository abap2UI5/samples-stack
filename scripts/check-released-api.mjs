#!/usr/bin/env node
/*
 * check-released-api — does a cloud-capable package name an API that ABAP
 * Cloud does not release?
 *
 * The Cloud lint of the branch build (create-package-branches.yaml) runs at
 * `"version": "Cloud"` and so judges the LANGUAGE: a read of sy-datum, a
 * statement outside the Cloud scope. It does not judge the API, and could not:
 * `errorNamespace` is `^Z2UI5`, so a class it cannot resolve - cl_http_client,
 * say - is somebody else's and stays silent.
 *
 * The answer is already in the repository. abaplint resolves against the
 * `steampunk-2305-api` dependency, which IS the list of objects SAP released
 * for ABAP Cloud (abapedia's snapshot of release 2305). So this check lints
 * every cloud-capable package once more with `errorNamespace` set to match
 * EVERY name: an object that is neither in the tree, nor in abap2UI5, nor
 * released, is now an error - "Class cl_http_client not found". That is the
 * released-API check, with no allow-list of SAP classes to maintain by hand.
 *
 * "Cloud-capable" is decided exactly as scripts/lib/read-packages.mjs decides
 * it for catalogue.json: /cloud/i on the package's runsOn. The package's
 * `shared` directories come along, and so does the overview app, which ships
 * on every branch. On a generated branch the same script checks what is left.
 *
 * Only four rules run - the ones that resolve names (check_syntax,
 * unknown_types, check_ddic) and cloud_types (object types ABAP Cloud does not
 * have). Everything else is the ordinary lint's business.
 *
 * Function modules come with it: at the Cloud language version check_syntax
 * reports a static `CALL FUNCTION 'NAME'` the snapshot does not release
 * ("Function module ... not found/released") - measured with a probe.
 *
 * EXPECTED below is the honest exception list: code that names an unreleased
 * API ON PURPOSE because the package documents it as not Cloud. Each entry
 * says why. An `open` entry is a finding nobody has fixed yet - it does not
 * fail the run, but it is printed every time, so it cannot go quiet.
 *
 * Needs the network, like `npm run lint`: abaplint clones its dependencies.
 * Usage: node scripts/check-released-api.mjs   (from the repository root)
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const CONFIG = '.abaplint-released-api.json';

const EXPECTED = [
  {
    path: /^src\/10\/01\//,
    why: 'src/10/01 is the Standard half of the LLM transport (cl_http_client on an SM59 destination). '
      + 'src/10/README.md documents it as activating on Standard only; the samples create the transport by name.',
  },
  {
    path: /^src\/10\/03\//,
    why: 'src/10/03 is the ABAP AI SDK transport. The SDK (cl_aic_islm_compl_api_factory) is younger than the '
      + 'steampunk-2305 snapshot and exists only where SAP ships it - src/10/README.md says so.',
  },
  {
    path: /^src\/05\//,
    message: /SYSUUID_X16, lookupDomain/,
    open: true,
    why: 'OPEN: the data elements Z2UI5_E_SMPS_TCK_UUID and Z2UI5_E_SMPS_LOG_UUID take the DOMAIN SYSUUID_X16, '
      + 'which is not in the released list (the released DATA ELEMENT sysuuid_x16 is). Everything else reported '
      + 'for src/05 follows from those two. Needs a check on an ABAP Cloud system and, if confirmed, the two '
      + 'data elements re-exported with the predefined type RAW 16 - not a hand edit of the sidecars.',
  },
];

const RULES = ['check_syntax', 'unknown_types', 'check_ddic', 'cloud_types'];

function parseJsonc(text) {
  let out = '';
  let inString = false;
  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    const next = text[i + 1];
    if (inString) {
      out += c;
      if (c === '\\') { out += next; i += 1; continue; }
      if (c === '"') inString = false;
      continue;
    }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === '/' && next === '/') { while (i < text.length && text[i] !== '\n') i += 1; out += '\n'; continue; }
    if (c === '/' && next === '*') { i += 2; while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) i += 1; i += 1; continue; }
    out += c;
  }
  return JSON.parse(out.replace(/,(\s*[}\]])/g, '$1'));
}

const packages = JSON.parse(fs.readFileSync(path.join(ROOT, '.github/packages.json'), 'utf8'));
const dirs = new Set();
for (const pkg of packages.filter((p) => /cloud/i.test(p.runsOn))) {
  for (const dir of [pkg.dir, ...pkg.shared]) {
    if (fs.existsSync(path.join(ROOT, 'src', dir))) dirs.add(dir);
  }
}
const files = [...[...dirs].sort().map((d) => `/src/${d}/**/*.*`), '/src/package.devc.xml', '/src/z2ui5_cl_smps_app_000.clas.*'];

const base = parseJsonc(fs.readFileSync(path.join(ROOT, 'abaplint.jsonc'), 'utf8'));
const rules = Object.fromEntries(RULES.map((r) => [r, base.rules[r] ?? true]));
const config = {
  global: { ...base.global, files },
  dependencies: base.dependencies,
  syntax: { version: 'Cloud', errorNamespace: '.' },
  rules,
};

fs.writeFileSync(path.join(ROOT, CONFIG), JSON.stringify(config, null, 2));
let issues;
try {
  let out;
  try {
    out = execFileSync(process.execPath, [path.join(ROOT, 'node_modules/@abaplint/cli/abaplint'), CONFIG, '-f', 'json'],
      { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) {
    out = e.stdout || ''; // abaplint exits 1 when it finds anything
    if (!out.includes('[')) {
      console.error(e.stderr || e.message);
      process.exit(2);
    }
  }
  issues = JSON.parse(out.slice(out.indexOf('[')));
} finally {
  fs.rmSync(path.join(ROOT, CONFIG), { force: true });
}

const bad = [];
const open = new Map();
const expected = new Map();
const rel = (file) => (path.isAbsolute(file) ? path.relative(ROOT, file) : file.replace(/^\.\//, ''));
for (const issue of issues) {
  const file = rel(issue.file);
  const hit = EXPECTED.find((e) => e.path.test(file) && (!e.message || e.message.test(issue.description)));
  if (!hit) bad.push(issue);
  else (hit.open ? open : expected).set(hit, ((hit.open ? open : expected).get(hit) || 0) + 1);
}

console.log(`check-released-api: ${[...dirs].sort().map((d) => `src/${d}`).join(', ')} and the overview app, `
  + 'at ABAP Cloud against the released-API snapshot');
for (const [entry, n] of expected) console.log(`  expected (${n} finding(s)): ${entry.why}`);
for (const [entry, n] of open) console.log(`  WARNING (${n} finding(s)): ${entry.why}`);

if (bad.length) {
  for (const i of bad) console.log(`ERROR ${rel(i.file)}:${i.start.row} ${i.description} (${i.key})`);
  console.log(`\n${bad.length} reference(s) to an object ABAP Cloud does not release, in a package whose runsOn says Cloud.`);
  console.log('Either the code moves to a released API, or the package is not cloud-capable and .github/packages.json has to say so.');
  process.exit(1);
}
console.log('every object a cloud-capable package names is released - OK');
