/*
 * The samples-stack catalogue — plain ES2020, no dependencies, no build step.
 *
 * Everything it knows comes from apps.json (scripts/generate-web-index.mjs),
 * regenerated on every Pages deploy. This file only filters and draws.
 *
 * Three decisions worth knowing before changing anything here:
 *
 *   THE SYSTEM FACET is the point of the page. Every sample in this repository
 *   needs something from the system, so "will this run for me" is not a detail
 *   on a card, it is the first question — and it has two halves, the stack
 *   (ABAP Cloud or on-premise) and the release. One select answers both:
 *   picking ABAP Cloud drops the three on-premise packages, picking a Standard
 *   release keeps everything at or below it. The counts are in the labels, so
 *   what an older system costs is visible before the click.
 *
 *   THERE IS NO PLAYGROUND LINK, unlike on the sibling pages. The playground
 *   runs a class with no system behind it, and a system is precisely what
 *   every sample here requires — a Gateway service, a RAP business object, an
 *   APC channel, a launchpad. Each app would open there and fail, so the links
 *   go to the source and to the package README that says how to set it up.
 *
 *   THE TECHNOLOGY FACET IS CHIPS, not a select: nine values, and seeing all
 *   nine at once is half the answer to "what is even in this repository".
 *
 *   THE OVERVIEW APP IS NOT IN apps.json, and nothing here has to know that:
 *   `Z2UI5_CL_SMPS_APP_000` is this same catalogue inside a system, not a
 *   sample of the stack, and generate-web-index.mjs leaves it and its group
 *   out (it says why). So every package here has a branch and a README of its
 *   own, and every app belongs to one — which is what lets this file draw a
 *   card and a package without asking whether it is the special one.
 */

/* ------------------------------------------------------------------ state */

const $ = (id) => document.getElementById(id);

const els = {
  q: $('q'),
  tech: $('tech'),
  system: $('system'),
  results: $('results'),
  count: $('count'),
  total: $('total'),
  pkgcount: $('pkgcount'),
  pkgline: $('pkgline'),
  pkgcards: $('pkgcards'),
  empty: $('empty'),
  reset: $('reset'),
  reset2: $('reset2'),
};

let DATA = null;      // the parsed apps.json
let PKG = new Map();  // directory -> package
let MATCHES = [];

/* --------------------------------------------------------------- helpers */

const esc = (s) => String(s == null ? '' : s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

/** Escaped text with `backticks` turned into code — the only markup the
 *  generated strings carry, because they come out of Markdown tables and
 *  ABAP-Doc prose. */
const md = (s) => esc(s).replace(/`([^`]+)`/g, '<code>$1</code>');

/** Wrap every query token found in `text`. Escapes first, so the marks are the
 *  only markup that reaches the card. */
function highlight(text, tokens) {
  const out = esc(text);
  if (!tokens.length) return out;
  const pattern = tokens
    .map((t) => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
    .sort((a, b) => b.length - a.length)
    .join('|');
  return out.replace(new RegExp(`(${pattern})`, 'gi'), '<mark>$1</mark>');
}

/** The one string a free-text query is matched against. The package title and
 *  what it plays together with are in it on purpose: "websocket" is in no
 *  class of src/07, it is in the package. */
const haystack = (app, pkg) => [
  app.cls,
  app.title,
  app.sub,
  app.summary,
  app.keywords.join(' '),
  pkg.title,
  pkg.topic,
  pkg.needs,
  app.doc.map((b) => b.text || (b.items || []).join(' ')).join(' '),
].join(' ').toLowerCase();

/* ----------------------------------------------------------------- facets */

function buildFacets() {
  els.tech.innerHTML = DATA.packages.map((p) => `
    <button type="button" class="chip" data-tech="${esc(p.dir)}" aria-pressed="false"
            title="${esc(p.topic)}">${esc(p.title)} <span class="n">${p.count}</span></button>`).join('');

  /* One select, both halves of the question. A Standard release keeps every
   * package at or below it — including the on-premise ones, which is the whole
   * difference to the Cloud option. */
  const cloud = DATA.apps.filter((a) => PKG.get(a.pkg).cloud).length;
  const releases = [...new Set(DATA.packages.map((p) => p.releaseNum))].sort((a, b) => a - b);
  const label = (num) => DATA.packages.find((p) => p.releaseNum === num).release;

  els.system.innerHTML = [
    `<option value="">any system — ${DATA.apps.length} samples</option>`,
    `<optgroup label="ABAP Cloud">`,
    `<option value="cloud">ABAP Cloud / BTP — ${cloud} samples</option>`,
    `</optgroup>`,
    `<optgroup label="ABAP Standard (on-premise)">`,
    ...releases.map((num) => {
      const n = DATA.apps.filter((a) => PKG.get(a.pkg).releaseNum <= num).length;
      return `<option value="std:${num}">${esc(label(num))} — ${n} sample${n === 1 ? '' : 's'}</option>`;
    }),
    `</optgroup>`,
  ].join('');
}

/* ----------------------------------------------------------------- filter */

const currentFilters = () => ({
  q: els.q.value.trim().toLowerCase(),
  tech: [...els.tech.querySelectorAll('[aria-pressed="true"]')].map((b) => b.dataset.tech),
  system: els.system.value,
});

function matches(app, f) {
  const pkg = PKG.get(app.pkg);
  if (f.tech.length && !f.tech.includes(app.pkg)) return false;
  if (f.system === 'cloud' && !pkg.cloud) return false;
  if (f.system.startsWith('std:') && pkg.releaseNum > Number(f.system.slice(4))) return false;
  return true;
}

function apply() {
  const f = currentFilters();
  const tokens = f.q ? f.q.split(/\s+/).filter(Boolean) : [];

  MATCHES = DATA.apps.filter((app) => matches(app, f) && tokens.every((t) => app.hay.includes(t)));

  /* A query naming a class, a title or a keyword should put that sample first;
   * otherwise the corpus order (package, then class number) is the stable one,
   * and it is also the reading order. */
  if (tokens.length) {
    const score = (app) => {
      const near = `${app.cls} ${app.title} ${app.sub} ${app.keywords.join(' ')}`.toLowerCase();
      return tokens.reduce((acc, t) => acc + (near.includes(t) ? 1 : 0), 0);
    };
    MATCHES = MATCHES
      .map((app, i) => ({ app, i, s: score(app) }))
      .sort((a, b) => b.s - a.s || a.i - b.i)
      .map((x) => x.app);
  }

  const n = MATCHES.length;
  els.count.textContent = n === DATA.apps.length
    ? `${n} samples`
    : `${n} of ${DATA.apps.length} samples`;

  const dirty = !!(f.q || f.tech.length || f.system);
  els.reset.hidden = !dirty;
  els.empty.hidden = n > 0;

  drawPackageLine(f);
  els.results.innerHTML = MATCHES.map((a) => card(a, tokens)).join('');
  writeUrl(f);
}

/** With exactly one technology picked, say what that package is before the
 *  cards — the description belongs where the reader has just asked for it. */
function drawPackageLine(f) {
  if (f.tech.length !== 1) { els.pkgline.hidden = true; return; }
  const p = PKG.get(f.tech[0]);
  els.pkgline.hidden = false;
  els.pkgline.innerHTML = `
    <b>${esc(p.title)}</b> — ${md(p.topic)}.
    Plays together with ${md(p.needs)}. Runs on ${esc(p.runsOn)}.
    Install it alone from the branch
    <a href="${esc(DATA.tree + p.branch)}" target="_blank" rel="noopener"><code>${esc(p.branch)}</code></a>,
    or read <a href="${esc(DATA.source + p.readme)}" target="_blank" rel="noopener">its README</a>.
    ${p.note ? `<br><em>${md(p.note)}</em>` : ''}`;
}

/* ----------------------------------------------------------------- render */

/** The ABAP-Doc header, block by block — the fullest description a class has
 *  of itself, where it carries one. */
const doc = (blocks) => blocks.map((b) => {
  if (b.type === 'code') return `<pre><code>${esc(b.text)}</code></pre>`;
  if (b.type === 'list') return `<ul>${b.items.map((i) => `<li>${md(i)}</li>`).join('')}</ul>`;
  return `<p>${md(b.text)}</p>`;
}).join('');

function card(app, tokens) {
  const p = PKG.get(app.pkg);
  const start = `?app_start=${app.cls.toLowerCase()}`;

  const badges = [
    `<span class="badge tech">${esc(p.title)}</span>`,
    p.cloud
      ? `<span class="badge cloud" title="Runs on ABAP Cloud and on-premise alike">Cloud + Standard</span>`
      : `<span class="badge std" title="On-premise only — the technology it uses is no released ABAP Cloud API">Standard only</span>`,
    `<span class="badge plain" title="${esc(p.runsOn)}">≥ ${esc(p.release)}</span>`,
  ];

  /* The render gate's photograph of the sample's first screen, written by
   * scripts/generate-screenshots.mjs into thumbs/ on every deploy - generated
   * like apps.json, never committed. Not every sample has one (a view the
   * headless harness cannot render is skipped there - sap.ui.comp and the
   * z2ui5.cc custom controls, mostly), and a local checkout has none until
   * the script has run, so a picture that does not load removes itself: the
   * card is complete without it. */
  const shot = `<img class="shot" loading="lazy" alt="" aria-hidden="true"
      src="thumbs/${esc(app.cls.toLowerCase())}.png" onerror="this.remove()">`;

  return `
    <article class="card">
      ${shot}
      <h2>${highlight(app.title, tokens)}</h2>
      ${app.sub ? `<p class="sub">${highlight(app.sub, tokens)}</p>` : ''}
      <p class="cls">${highlight(app.cls, tokens)}</p>
      ${app.summary ? `<p class="blurb">${highlight(app.summary, tokens)}</p>` : ''}
      <div class="badges">${badges.join('')}</div>
      <dl class="facts">
        <div><dt>Needs</dt><dd>${md(p.needs)}</dd></div>
        <div><dt>Start with</dt><dd class="start"><code>${highlight(start, tokens)}</code>
          <button type="button" class="copy" data-copy="${esc(start)}">copy</button></dd></div>
      </dl>
      ${app.keywords.length ? `<ul class="tags">${app.keywords
        .map((k) => `<li><button type="button" data-tag="${esc(k)}">${esc(k)}</button></li>`).join('')}</ul>` : ''}
      ${app.doc.length ? `<details><summary>What the class documents</summary><div class="doc">${doc(app.doc)}</div></details>` : ''}
      <div class="actions">
        <a class="primary" href="${esc(DATA.source + app.file)}" target="_blank" rel="noopener">Source ↗</a>
        <a href="${esc(DATA.source + p.readme)}" target="_blank" rel="noopener">Setup ↗</a>
        <a href="${esc(DATA.tree + p.branch)}" target="_blank" rel="noopener" title="This package alone, for abapGit">Branch ↗</a>
      </div>
    </article>`;
}

/** The packages as a table of their own, below the results: the same nine
 *  paragraphs the READMEs open with, for somebody who is browsing rather than
 *  searching. The heading filters the list above. */
function drawPackages() {
  els.pkgcards.innerHTML = DATA.packages.map((p) => `
    <article class="pkgcard">
      <h3><button type="button" data-tech="${esc(p.dir)}">${esc(p.title)}</button></h3>
      <p>${md(p.topic)}</p>
      <p><b>Plays together with</b> ${md(p.needs)}</p>
      <p class="meta">
        src/${esc(p.dir)} ·
        ${esc(p.runsOn)} ·
        ${p.count} sample${p.count === 1 ? '' : 's'} ·
        <a href="${esc(DATA.tree + p.branch)}" target="_blank" rel="noopener">${esc(p.branch)}</a>
      </p>
      ${p.note ? `<p class="note">${md(p.note)}</p>` : ''}
    </article>`).join('');
}

/* -------------------------------------------------------------- url state */

function writeUrl(f) {
  const p = new URLSearchParams();
  if (f.q) p.set('q', f.q);
  if (f.tech.length) p.set('tech', f.tech.join(','));
  if (f.system) p.set('system', f.system);
  const query = p.toString();
  history.replaceState(null, '', query ? `?${query}` : location.pathname);
}

function readUrl() {
  const p = new URLSearchParams(location.search);
  els.q.value = p.get('q') || '';
  const tech = (p.get('tech') || '').split(',').filter(Boolean);
  for (const button of els.tech.querySelectorAll('[data-tech]')) {
    button.setAttribute('aria-pressed', String(tech.includes(button.dataset.tech)));
  }
  const system = p.get('system');
  /* Only a value the current index still knows — a link from before a package
   * was added must not leave a dead filter selected. */
  if (system && [...els.system.options].some((o) => o.value === system)) els.system.value = system;
}

function reset() {
  els.q.value = '';
  els.system.value = '';
  for (const button of els.tech.querySelectorAll('[data-tech]')) button.setAttribute('aria-pressed', 'false');
  apply();
  els.q.focus();
}

/** Filter by one technology, from a chip or from a package card below. */
function pickTech(dir, toggle) {
  for (const button of els.tech.querySelectorAll('[data-tech]')) {
    const on = button.dataset.tech === dir;
    if (!toggle && !on) button.setAttribute('aria-pressed', 'false');
    if (on) button.setAttribute('aria-pressed', String(toggle ? button.getAttribute('aria-pressed') !== 'true' : true));
  }
  apply();
}

/* ------------------------------------------------------------------- boot */

async function boot() {
  try {
    const res = await fetch('apps.json');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    DATA = await res.json();
  } catch (err) {
    els.count.textContent = '';
    els.results.innerHTML = `<p class="empty">The catalogue could not be loaded (${esc(err.message)}).
      It is written by the deploy build; on a local checkout run
      <code>node scripts/generate-web-index.mjs</code> first.</p>`;
    return;
  }

  PKG = new Map(DATA.packages.map((p) => [p.dir, p]));
  for (const app of DATA.apps) app.hay = haystack(app, PKG.get(app.pkg));

  els.total.textContent = String(DATA.apps.length);
  els.pkgcount.textContent = String(DATA.packages.length);

  buildFacets();
  drawPackages();
  readUrl();
  apply();

  els.q.addEventListener('input', apply);
  els.system.addEventListener('change', apply);
  els.tech.addEventListener('click', (e) => {
    const chip = e.target.closest('[data-tech]');
    if (chip) pickTech(chip.dataset.tech, true);
  });
  els.pkgcards.addEventListener('click', (e) => {
    const button = e.target.closest('[data-tech]');
    if (!button) return;
    pickTech(button.dataset.tech, false);
    document.getElementById('filters').scrollIntoView({ behavior: 'smooth', block: 'start' });
  });
  els.results.addEventListener('click', (e) => {
    const tag = e.target.closest('[data-tag]');
    if (tag) {
      els.q.value = tag.dataset.tag;
      apply();
      return;
    }
    const copy = e.target.closest('[data-copy]');
    if (copy && navigator.clipboard) {
      navigator.clipboard.writeText(copy.dataset.copy).then(() => {
        copy.textContent = 'copied';
        setTimeout(() => { copy.textContent = 'copy'; }, 1200);
      }, () => { copy.textContent = 'press ⌘C'; });
    }
  });
  els.reset.addEventListener('click', reset);
  els.reset2.addEventListener('click', reset);
  document.getElementById('filters').addEventListener('submit', (e) => e.preventDefault());

  /* `/` focuses the search box, the way a documentation site does. */
  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && !/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement.tagName)) {
      e.preventDefault();
      els.q.focus();
      els.q.select();
    }
  });
}

boot();
