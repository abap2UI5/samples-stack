#!/usr/bin/env node
/*
 * check-page-titles - the page a sample opens with says it is abap2UI5.
 *
 * The rule (AGENTS.md section 6): the title of a sample's main page is a
 * literal that starts with `abap2UI5 - `, followed by the sample's own name.
 *
 *     )->ele( `Page`
 *         )->a( n = `title` v = `abap2UI5 - Smart Controls - SmartTable`
 *
 * Measured on the tree when the gate was written (2026-10): 30 of 33 main
 * pages already opened that way, three did not (`RAP Events Demo - Tickets
 * (abap2UI5)`, `SmartMultiInput - conditions to ABAP SELECT-OPTIONS`) - the
 * same drift abap2UI5/samples had before it gated its titles. What follows the
 * prefix is NOT one rule here and is not judged: the RAP packages number their
 * steps (`EML - 01 Read Travel`), the Smart Controls, Launchpad and AI ones
 * repeat the package (`Smart Controls - SmartChart`), the session samples say
 * `Sample: …`. abap2UI5/samples holds the title to `abap2UI5 - <DESCRIPT>`;
 * that would rewrite every title in this repository, and the overview app
 * shows its own curated title, not the DESCRIPT, so it would not even make the
 * tile and the page agree.
 *
 * What is read: the first `Page` built after each `Shell` - the page the user
 * sees first. A class that builds two main views (Z2UI5_CL_SMPS_APP_490) is
 * held to it for both. A page with `showHeader` false renders no title at all
 * and is skipped: the launchpad samples (Z2UI5_CL_SMPS_APP_481, _482) leave
 * the header to the launchpad shell, whose title is what _482 sets. Dialogs,
 * further pages and form titles are the sample's own business.
 *
 * Who is held to it: every app (a class implementing z2ui5_if_app, the same
 * scan as check-keywords) except the overview app, whose title sits in its
 * custom header. Works on a one-package branch: it scans the tree it runs in.
 *
 *   node scripts/check-page-titles.mjs      (npm run check:titles)
 */
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { scanSamples, OVERVIEW_CLASS } from './lib/scan-samples.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PREFIX = 'abap2UI5 - ';

/* Source without comments: `*` in column 1, `"` outside a literal. */
function stripComments(source) {
  return source.split('\n').map((line) => {
    if (line.startsWith('*')) return '';
    let quote = null;
    for (let i = 0; i < line.length; i += 1) {
      const c = line[i];
      if (quote) {
        if (c === quote) quote = null;
        continue;
      }
      if (c === '"') return line.slice(0, i);
      if (c === '`' || c === "'" || c === '|') quote = c;
    }
    return line;
  }).join('\n');
}

const SHELL = /(?:ele|tag)\(\s*(?:n\s*=\s*)?`Shell`/g;
const PAGE = /(?:ele|tag)\(\s*(?:n\s*=\s*)?`Page`/;
const ATTRIBUTE = /^\)->a\(\s*n\s*=\s*`([^`]*)`\s+([vtb])\s*=\s*(.*)$/;

/**
 * The Page's own attributes: the run of `)->a(` lines right after it (the
 * house chain layout puts one call per line), up to the first other call or
 * the end of the statement.
 */
function pageAttributes(code, from) {
  const attrs = new Map();
  for (const raw of code.slice(from).split('\n').slice(1)) {
    const line = raw.trim();
    const m = ATTRIBUTE.exec(line);
    if (!m) break;
    attrs.set(m[1], { kind: m[2], value: m[3].replace(/\s*\)?\s*\.?$/, '').trim() });
    if (/\)\s*\.$/.test(line)) break;
  }
  return attrs;
}

const problems = [];
let pages = 0;
let headerless = 0;
const apps = scanSamples(ROOT).filter((s) => s.isApp && s.cls !== OVERVIEW_CLASS);

for (const app of apps) {
  const code = stripComments(fs.readFileSync(app.file, 'utf8'));
  const shells = [...code.matchAll(SHELL)];
  if (!shells.length) {
    problems.push(`${app.rel}: no Shell -> Page main view found, so its title cannot be checked`);
    continue;
  }
  for (const shell of shells) {
    const after = shell.index + shell[0].length;
    const m = PAGE.exec(code.slice(after));
    if (!m) {
      problems.push(`${app.rel}: a Shell without a Page after it, so its title cannot be checked`);
      continue;
    }
    const at = after + m.index;
    const line = code.slice(0, at).split('\n').length;
    const attrs = pageAttributes(code, at);
    const header = attrs.get('showHeader');
    if (header && /^(abap_false|`false`|space)$/.test(header.value)) {
      headerless += 1;
      continue;
    }
    pages += 1;
    const title = attrs.get('title');
    const literal = title && /^`([^`]*)`$/.exec(title.value);
    if (!title) {
      problems.push(`${app.rel}:${line}: the main Page carries no title - want \`${PREFIX}…\``);
    } else if (!literal) {
      problems.push(`${app.rel}:${line}: the page title is computed (${title.value}) - want a literal \`${PREFIX}…\``);
    } else if (!literal[1].startsWith(PREFIX) || !literal[1].slice(PREFIX.length).trim()) {
      problems.push(`${app.rel}:${line}: page title \`${literal[1]}\` - want \`${PREFIX}<the sample's name>\``);
    }
  }
}

console.log(`check-page-titles: ${apps.length} app(s), ${pages} main page title(s) read, ${headerless} headerless page(s) skipped`);

if (problems.length) {
  console.error(`\n${problems.length} problem(s):`);
  for (const p of problems) console.error(`  ${p}`);
  console.error(`\nSee AGENTS.md section 6: a sample's main page title starts with \`${PREFIX}\`.`);
  process.exit(1);
}
console.log(`every main page title starts with \`${PREFIX}\` - OK`);
