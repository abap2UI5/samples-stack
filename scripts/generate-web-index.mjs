#!/usr/bin/env node
/*
 * generate-web-index — the data behind the page in web/.
 *
 * The three sample repositories each publish the answer to the question their
 * corpus is actually asked. abap2UI5/samples publishes a learning path,
 * because "where do I start" is what a newcomer arrives with.
 * abap2UI5/samples-controls publishes a search box over 430 control ports,
 * because "which one shows a Wizard" is what a control reference is asked.
 *
 * This corpus is asked something else again, and neither page answers it:
 *
 *     "my system is on 7.50 and on-premise — what of this can I even run?"
 *     "is there a sample for WebSockets, and what do I have to set up first?"
 *
 * Both are questions about the SYSTEM, not about the sample: everything here
 * needs something beyond an abap2UI5 installation, and which something is the
 * one fact that decides whether a reader can use a sample at all. So the page
 * is a search over the catalogue with two facets — the system you have, and
 * the technology you came for — and every card says what it needs and what it
 * costs before you click anything.
 *
 * There is no playground link, unlike the other two pages. The playground runs
 * a class in a transpiled ABAP in the browser, with no system behind it — and
 * a system is exactly what every sample here requires. A Gateway service, a
 * RAP business object, an APC channel, a launchpad: none of it exists in that
 * frame, so every one of these apps would open and then fail. A link that
 * cannot work is worse than no link, so the cards link into the SOURCE and
 * into the package README that says how to set the sample up.
 *
 * THE OVERVIEW APP IS NOT ON THIS PAGE. `Z2UI5_CL_SMPS_APP_000` is this same
 * catalogue rendered inside a system, and as a card it answered the page's own
 * question with a contradiction — *needs nothing beyond abap2UI5*, on a page
 * whose premise is that everything here needs something from the system — while
 * taking a technology chip of its own that filtered ten groups down to itself.
 * It is a way to browse the corpus, not something to browse the corpus for, so
 * the page names it in *How to run one* and leaves the cards to the samples.
 * Dropped here rather than in web/stack.js: the page draws what it is given,
 * and SAMPLES.md and catalogue.json still carry the overview app, because a
 * reader of those is inside the repository already.
 *
 * Where every fact comes from — no fact is restated here, all of them are read
 * out of what the repository already keeps:
 *
 *   scripts/lib/scan-samples.mjs   which classes are apps, their title from
 *                                  DESCRIPT, `@summary`, `@keywords` — the
 *                                  same scan behind SAMPLES.md and
 *                                  check-keywords, so the page and the
 *                                  catalogue cannot disagree
 *   scripts/lib/read-packages.mjs  the packages: `.github/packages.json`
 *                                  merged with the root README's table — the
 *                                  same merge behind catalogue.json, for the
 *                                  same no-second-copy reason as the scan
 *   the class's ABAP-Doc header    the long description, where a class has one
 *
 *   node scripts/generate-web-index.mjs           write web/apps.json
 *   node scripts/generate-web-index.mjs --check   validate, write nothing
 *   node scripts/generate-web-index.mjs --out X   write it elsewhere
 *
 * NOT committed — web/apps.json is a build output. deploy-web regenerates it on
 * every deploy, so the page can never be staler than the tree it describes and
 * a sample pull request carries no diff of derived data. `--check` is what CI
 * runs (npm run check:web): it holds everything that can go wrong in a pull
 * request — a package with no README row, a row whose cells cannot be read, an
 * app whose package is unknown — without needing the output.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { scanSamples, sampleTitle, OVERVIEW_CLASS } from './lib/scan-samples.mjs';
import { packages, OVERVIEW_PKG } from './lib/read-packages.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CHECK = process.argv.includes('--check');
const argOut = process.argv.indexOf('--out');
const OUT = argOut === -1
  ? path.join(ROOT, 'web', 'apps.json')
  : path.resolve(process.argv[argOut + 1]);

/* The repository the links point into. The page is built from main, so that is
 * the ref the blob links follow; the branch links point at the generated
 * one-package branches, which is what a reader pulls with abapGit. */
const REPO = 'abap2UI5/samples-stack';
const REF = 'main';
const SOURCE = `https://github.com/${REPO}/blob/${REF}/`;
const TREE = `https://github.com/${REPO}/tree/`;

const die = (message) => {
  console.error(`generate-web-index: ${message}`);
  process.exit(1);
};

/* ------------------------------------------------------- the long description */

/**
 * The class's ABAP-Doc header, as blocks a page can render.
 *
 * Twelve of the app classes carry one and it is the fullest description this
 * repository has of them — the EML statement, what the sample adds over the one
 * before it, which surprise is worth a comment. Where there is none the card
 * stops at `@summary`, which every app has.
 *
 * The `<p class="shorttext synchronized">` line is dropped: that is the
 * DESCRIPT again, which the card already shows as its title.
 *
 * Blocks are what a blank `"!` line separates, and each one is classified by
 * its FIRST line, because that is the only reading that does not confuse a
 * wrapped bullet with a line of ABAP — both are indented by four:
 *
 *   `- …`      a list. The wrapped lines belong to the item above them.
 *   indented   code (the EML statement). Dedented by the block's own margin,
 *              and it keeps its line breaks — that shape IS the statement.
 *   otherwise  prose, joined into one paragraph: the breaks in the source are
 *              the 80-column margin, not the author's.
 *
 * ABAP Doc is HTML, so the source carries `&lt;no&gt;` where the author wrote
 * `<no>`. Unescaped here, once — the page escapes everything it renders.
 */
function abapDoc(source) {
  const lines = [];
  for (const raw of source.split(/\r?\n/)) {
    if (/^\s*$/.test(raw) || /^"(?!!)/.test(raw)) continue;   // blank, or a plain " comment
    if (!raw.startsWith('"!')) break;                          // the CLASS statement — done
    if (/<p class="shorttext/.test(raw)) continue;
    lines.push(raw.slice(2).replace(/^ /, ''));
  }

  const unescape = (s) => s
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');

  /* the blank `"!` lines are the paragraph breaks */
  const groups = [];
  for (const line of lines) {
    if (!line.trim()) { groups.push([]); continue; }
    if (!groups.length) groups.push([]);
    groups[groups.length - 1].push(line);
  }

  return groups.filter((g) => g.length).map((group) => {
    if (/^\s*[-*]\s/.test(group[0])) {
      const items = [];
      for (const line of group) {
        if (/^\s*[-*]\s/.test(line)) items.push(line.replace(/^\s*[-*]\s/, ''));
        else if (items.length) items[items.length - 1] += ` ${line.trim()}`;
      }
      return { type: 'list', items: items.map(unescape) };
    }
    if (/^\s{3,}\S/.test(group[0])) {
      const margin = Math.min(...group.map((l) => l.match(/^ */)[0].length));
      return { type: 'code', text: unescape(group.map((l) => l.slice(margin)).join('\n')) };
    }
    return { type: 'p', text: unescape(group.map((l) => l.trim()).join(' ')) };
  });
}

/* -------------------------------------------------------------------- build */

/* `count` is the page's own derived state — apps per group, for the chips —
 * so it is added here rather than carried by the shared package merge. */
const byDir = new Map(packages(ROOT)
  .filter((p) => p.dir !== OVERVIEW_PKG.dir)
  .map((p) => [p.dir, { ...p, count: 0 }]));
const all = scanSamples(ROOT);
const apps = [];

/* The overview app and its group, left out for the reason at the top of this
 * file. It is the only app of `src/` itself, so dropping the class and dropping
 * the group are the same cut made twice — and it has to happen before the
 * unknown-package check below, which is there to catch an app that landed in a
 * subpackage by accident. */
for (const s of all.filter((x) => x.isApp && x.cls !== OVERVIEW_CLASS)) {
  const pkg = byDir.get(s.pkg);
  /* A subpackage — src/03/01 holds the business object, not an app. If an app
   * ever lands in one, the page would silently lose it, so say so instead. */
  if (!pkg) die(`${s.cls} lives in src/${s.pkg}, which is no package of .github/packages.json`);

  const { title, sub } = sampleTitle(s, s.section);
  pkg.count += 1;
  apps.push({
    cls: s.cls.toUpperCase(),
    file: s.rel,
    pkg: s.pkg,
    title,
    sub,
    summary: s.summary,
    keywords: s.keywords ? s.keywords.split(/\s+/) : [],
    doc: abapDoc(fs.readFileSync(path.join(ROOT, s.rel), 'utf8')),
  });
}

const index = {
  repo: REPO,
  source: SOURCE,
  tree: TREE,
  packages: [...byDir.values()],
  apps,
};

/* The two ways this page fails without failing: an app with nothing to search
 * for, and a package nobody can be told how to set up. Both are gated
 * elsewhere (check-keywords, check-overview) — checked again here because this
 * generator is what turns them into a page, and a card missing its line is the
 * silent kind of broken. */
const mute = apps.filter((a) => !a.summary || !a.keywords.length).map((a) => a.cls);
if (mute.length) die(`${mute.join(', ')} — no @summary or no @keywords, so nobody searching finds them`);
if (!apps.length) die('no apps found under src/ — the scan came back empty');

if (CHECK) {
  const counts = index.packages.map((p) => `${p.title}: ${p.count}`).join(', ');
  console.log(`check-web: ${apps.length} app(s) in ${index.packages.length} group(s) — ${counts}`);
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, `${JSON.stringify(index, null, 1)}\n`);
  console.log(`generate-web-index: wrote ${apps.length} app(s) in ${index.packages.length} group(s) to ${path.relative(ROOT, OUT)}`);
}
