#!/usr/bin/env node
/*
 * generate-screenshots - a thumbnail per sample for the page in web/.
 *
 * The page describes every sample with a title, a sentence and what it needs
 * from the system; what a sample LOOKS like was invisible, and unlike on the
 * sibling pages there is no playground link to click through to - a system is
 * what every sample here needs. The abap2UI5-linter can answer that without a
 * system: its render gate reconstructs the view from the
 * z2ui5_cl_ui5_view_builder calls, seeds it with a model derived from the
 * class's own TYPES/DATA and renders it in a headless browser - and
 * `screenshotFiles` is that same harness kept standing long enough to
 * photograph it. So a thumbnail is the render gate's view of the sample, not
 * a staged picture: the view statically, with mock data, no Gateway, RAP or
 * APC anywhere. What it shows is what the gate checks.
 *
 * GENERATED AT DEPLOY, NEVER COMMITTED - the same decision as web/apps.json,
 * for the same reason: the deploy-web workflow writes web/thumbs/ fresh on
 * every deploy, so the pictures are never staler than the classes, and a
 * sample pull request carries no binary diff. The page treats a missing
 * picture as "no picture" (the <img> removes itself), so this script is
 * allowed to skip what it cannot photograph. Measured over the whole corpus
 * (2026-08): 18 of 31 app views render; the three skip reasons are stable and
 * documented in AGENTS.md §8 - `sap.ui.comp` is SAPUI5-only and not in the
 * harness's OpenUI5 runtime, `z2ui5.cc` custom controls do not load headless,
 * and the mock model seeds an empty ObjectStatus state. Each skipped card
 * simply has no thumbnail. Only when NOTHING could be photographed does the
 * run fail, because that is not a sample problem but a harness one (no
 * browser, broken runtime), and a deploy that silently dropped every picture
 * would look like a design change.
 *
 * Unlike the other scripts here this one needs the devDependencies - the
 * linter and @abap2ui5/render-runtime, the same pair `npm run check:abap2ui5`
 * already uses - plus the playwright chromium the render gate drives.
 *
 *   node scripts/generate-screenshots.mjs               write web/thumbs/
 *   node scripts/generate-screenshots.mjs --limit 5     a quick local smoke
 *   node scripts/generate-screenshots.mjs --out DIR     write elsewhere
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { screenshotFiles } from '@abap2ui5/linter';
import { scanSamples, OVERVIEW_CLASS } from './lib/scan-samples.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const argOut = process.argv.indexOf('--out');
const OUT = argOut === -1
  ? path.join(ROOT, 'web', 'thumbs')
  : path.resolve(process.argv[argOut + 1]);
const argLimit = process.argv.indexOf('--limit');
const LIMIT = argLimit === -1 ? Infinity : Number(process.argv[argLimit + 1]);

/* The card thumbnail's viewport. 4:3 at a laptop-ish width, viewport only
 * (not the full page): the first screen is what a reader recognises a sample
 * by, and a full-page shot of a long table would shrink to an unreadable
 * strip. The CSS crops from the top, so nothing is distorted. */
const SIZE = { width: 800, height: 600 };

/* One browser session per chunk. screenshotFiles renders every file it is
 * given in one session, so bigger chunks amortise the browser start - but a
 * whole corpus in one call holds every PNG in memory at once, and one crash
 * would take all pictures with it. */
const CHUNK = 25;

/* Every app the page shows a card for, the same scan and the same cut the page
 * itself is built from - helpers (behavior pools, demo data, the APC protocol
 * class) have no card and get no picture, and neither does the overview app,
 * which generate-web-index.mjs leaves off the page (it says why). Photographing
 * it would cost a render per deploy for a file nothing loads. */
const apps = scanSamples(ROOT)
  .filter((s) => s.isApp && s.cls !== OVERVIEW_CLASS)
  .slice(0, LIMIT);
fs.mkdirSync(OUT, { recursive: true });

let written = 0;
const skipped = [];
for (let i = 0; i < apps.length; i += CHUNK) {
  const chunk = apps.slice(i, i + CHUNK);
  const byFile = new Map(chunk.map((a) => [a.file, a]));
  const shots = await screenshotFiles([...byFile.keys()], { ...SIZE, fullPage: false });
  for (const shot of shots) {
    /* A class can build several documents - the main view first, then nested
     * views and popup fragments. The thumbnail is the main view; index 0 is
     * what the app opens with. */
    if (shot.index !== 0) continue;
    const app = byFile.get(shot.file);
    if (!shot.png || shot.errors.length) {
      skipped.push(`${app.cls}: ${shot.errors[0] || 'no picture'}`);
      continue;
    }
    /* Named by the class in lower case, which is how the page derives the
     * URL from the catalogue entry (stack.js). */
    fs.writeFileSync(path.join(OUT, `${app.cls}.png`), shot.png);
    written++;
  }
}

for (const line of skipped) console.warn(`no thumbnail for ${line}`);
console.log(`${path.relative(ROOT, OUT)}: ${written} of ${apps.length} samples photographed`
  + (skipped.length ? `, ${skipped.length} skipped (their cards show no picture)` : ''));

if (written === 0) {
  console.error('nothing could be photographed - that is a harness problem (browser, render runtime), not a sample one');
  process.exit(1);
}
