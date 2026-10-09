#!/usr/bin/env node
/*
 * check-abapdoc — every `"!` block documents the declaration directly below it.
 *
 * An ABAP Doc block attaches to the ONE declaration that follows it. Put it
 * before a chain keyword (`CONSTANTS:`, `DATA:`, `METHODS:`), inside a
 * parameter list, or before a section end, and it attaches to nothing: the
 * text is in the source, it reads like documentation, and it is never shown
 * anywhere. Nothing breaks — which is exactly why it recurs.
 *
 * SLIN/ATC does report it ("ABAP Doc comment is in the wrong position"), but
 * SLIN runs in a real system, after the pull — the worst place to learn it.
 * It found five of them on z2ui5_cl_smps_app_000 that way (2026-08-17): two
 * blocks before `CONSTANTS:` and three comments between the parameters of
 * header_button. abaplint has no rule for the position — its `abapdoc` rule
 * checks that documentation EXISTS, and a block that attaches to nothing is,
 * from that rule's point of view, identical to one that was never written.
 * An upstream rule is proposed (abap2UI5/abap2UI5
 * backlog/items/abaplint-abapdoc-block-placement.md, with a measured probe
 * this detector follows); until it ships, this gate is the check.
 *
 * What is decided, all purely structural:
 *
 *   - a `"!` block whose next statement is a chain keyword documents nothing.
 *     Move it INTO the chain, directly before the member it documents.
 *   - a `"!` block whose next line is `END OF`, `ENDCLASS`, `ENDINTERFACE` or
 *     a section start documents nothing.
 *   - a `"!` block followed by a blank line or a plain `"` comment documents
 *     nothing either: "directly before" means with nothing in between (a Code
 *     Inspector run on a 7.58 system reported exactly that shape, 2026-10-04).
 *   - a `"!` block inside a running statement (the code line above it ends in
 *     neither `.` nor `:` nor `,`) sits in a parameter list. A parameter is
 *     documented from the method's own block: `"! @parameter <name> | <text>`.
 *
 * Only the class-pool main and interface sources are read — ABAP Doc lives in
 * declarations, and the includes (`.locals_imp`, `.testclasses`) have none.
 *
 *   node scripts/check-abapdoc.mjs   (npm run check:abapdoc)
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC = path.join(ROOT, 'src');

const CHAIN_KEYWORD =
  /^\s*(constants|data|types|methods|class-methods|class-data|events)\s*:\s*$/i;
const NOTHING_TO_DOCUMENT =
  /^\s*(end\s+of\b|endclass\b|endinterface\b|(public|protected|private)\s+section\b)/i;

function walk(dir, out = []) {
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    if (fs.statSync(full).isDirectory()) walk(full, out);
    else if (/\.(clas|intf)\.abap$/.test(name)) out.push(full);
  }
  return out;
}

const findings = [];

for (const file of walk(SRC)) {
  const rel = path.relative(ROOT, file);
  const src = fs.readFileSync(file, 'utf8').split('\n');

  src.forEach((line, i) => {
    if (!/^\s*"!/.test(line)) return;
    // only the FIRST line of a doc block speaks for the block
    if (/^\s*"!/.test(src[i - 1] || '')) return;

    // the code line above: skip blanks and comments - plain ones, and a "!
    // block a blank line cut off above this one (reported on its own)
    let p = i - 1;
    while (p >= 0 && (!src[p].trim() || /^\s*"/.test(src[p]))) p -= 1;
    const prev = p >= 0 ? src[p].trim() : '';

    // the line right below the block - "directly before" means NOTHING in
    // between: a blank line or a plain `"` comment detaches the block exactly
    // like a misplaced one (SLIN, measured on a 7.58 system)
    let end = i + 1;
    while (end < src.length && /^\s*"!/.test(src[end])) end += 1;
    const gap = end < src.length && (!src[end].trim() || /^\s*"(?!!)/.test(src[end]));

    // the statement below: skip blanks, plain comments and the rest of the block
    let n = i + 1;
    while (n < src.length && (/^\s*"/.test(src[n]) || !src[n].trim())) n += 1;
    const next = n < src.length ? src[n].trim() : '';

    const at = `${rel}:${i + 1}`;
    if (gap) {
      findings.push(
        `${at} — a blank line or a plain " comment between the "! block and \`${next}\` detaches it; the block has to sit directly on the declaration`
      );
    } else if (prev && !/[.:,]$/.test(prev)) {
      findings.push(
        `${at} — "! inside a parameter list documents nothing; use "! @parameter <name> | <text> in the method's own block`
      );
    } else if (CHAIN_KEYWORD.test(next)) {
      findings.push(
        `${at} — "! before the chain keyword \`${next}\` documents nothing; move it inside the chain, directly before the member`
      );
    } else if (NOTHING_TO_DOCUMENT.test(next)) {
      findings.push(`${at} — "! before \`${next}\` documents nothing`);
    }
  });
}

if (findings.length) {
  console.error('check-abapdoc: an ABAP Doc block that documents nothing\n');
  for (const f of findings) console.error(`  ${f}`);
  console.error(
    `\n${findings.length} finding(s). SLIN reports these as "ABAP Doc comment` +
      ' is in the wrong position" — but only in a real system, after the pull.'
  );
  process.exit(1);
}
console.log('check-abapdoc: every ABAP Doc block documents a declaration.');
