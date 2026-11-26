#!/usr/bin/env node
/*
 * check-702 - the 7.02 downport of this repository, the requirement every
 * repository of the abap2UI5 ecosystem has.
 *
 * `abaplint --fix` against .github/abaplint/abap_702.jsonc rewrites every
 * file it downports, so the check never runs on the tree you work in: it
 * copies src/ and the configs into a temporary folder, downports there
 * (npm run downport), lints the result at v702 and throws the copy away. 0
 * issues or exit 1.
 *
 * Not every package has a 7.02 form - RAP and EML, ABAP Push Channels, the
 * ABAP Cloud HTTP client. abap_702.jsonc leaves them out (global.exclude) and
 * says why for each; this script prints the list on every run, so a green run
 * is never taken for the whole repository.
 *
 *   node scripts/check-702.mjs              the check (npm run check:702)
 *   node scripts/check-702.mjs --in-place   the publish-702 workflow, on a
 *        fresh checkout: downport the working tree itself, lint it, and
 *        delete what abap_702.jsonc leaves out - the content of branch 702
 */
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CONFIG = '.github/abaplint/abap_702.jsonc';
const inPlace = process.argv.includes('--in-place');

// the packages left out, from the config itself - one list, one place
const text = readFileSync(path.join(ROOT, CONFIG), 'utf8');
const excludeBlock = text.match(/"exclude"\s*:\s*\[([\s\S]*?)\]/);
const excluded = excludeBlock ? [...excludeBlock[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]) : [];

let dir = ROOT;
if (!inPlace) {
  dir = mkdtempSync(path.join(tmpdir(), 'samples-stack-702-'));
  for (const entry of ['src', '.github/abaplint/abap_702.jsonc', 'package.json']) {
    cpSync(path.join(ROOT, entry), path.join(dir, entry), { recursive: true });
  }
  symlinkSync(path.join(ROOT, 'node_modules'), path.join(dir, 'node_modules'), 'dir');
}

const abaplint = path.join(ROOT, 'node_modules', '.bin', 'abaplint');
const run = (args) => spawnSync(abaplint, args, { cwd: dir, encoding: 'utf8', maxBuffer: 1 << 28 });

let status = 1;
try {
  // --fix iterates the downport rule to a fixpoint; what it cannot lower it
  // leaves as an issue, which the lint below reports
  run(['--fix', CONFIG]);
  // abaplint lowers a failing table expression to RAISE EXCEPTION TYPE
  // cx_sy_itab_line_not_found, which 7.02 does not have
  spawnSync('sh', ['-c', "find src -type f -name '*.abap' -exec sed -i -e 's/ RAISE EXCEPTION TYPE cx_sy_itab_line_not_found/ ASSERT 1 = 0/g' {} +"], { cwd: dir });
  const lint = run([CONFIG]);
  const out = `${lint.stdout}${lint.stderr}`;
  process.stdout.write(out.split('\n').filter((l) => /\[E\]|\[W\]|issue\(s\) found/.test(l)).join('\n') + '\n');
  status = lint.status ?? 1;
  if (status === 0 && inPlace) {
    for (const e of excluded) rmSync(path.join(dir, e.replace(/^\//, '')), { recursive: true, force: true });
  }
} finally {
  if (!inPlace) rmSync(dir, { recursive: true, force: true });
}

console.log(`check-702: not downported (no 7.02 form, see ${CONFIG}): ${excluded.map((e) => e.replace(/^\/|\/$/g, '')).join(', ')}`);
if (status !== 0) {
  console.error('check-702: the downported tree does not lint at v702 - see above');
  process.exit(1);
}
console.log(`check-702: 0 issues${inPlace ? ', the packages above deleted from the tree' : ''}`);
if (inPlace && !existsSync(path.join(dir, 'src'))) process.exit(1);
