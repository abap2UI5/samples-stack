/*
 * scan-samples — the one place that knows what a sample in this repository is.
 *
 * Three things read this: `check-keywords.mjs`, which insists every app says
 * what it is about, `generate-samples-md.mjs`, which writes the catalogue, and
 * `generate-web-index.mjs`, which writes the data behind the page in web/. They
 * have to agree on which classes are apps, where a title comes from and which
 * section a sample belongs to — abap2UI5/samples learned that the hard way and
 * says so in its AGENTS.md: two copies of this drift silently, and then the
 * catalogue and the gate simply disagree about what the repository contains
 * while both keep passing.
 *
 * The rules, and why they are these:
 *
 *   an APP implements z2ui5_if_app. Everything else — behavior pools, demo
 *   data, event consumers, the generated APC protocol class — is a helper,
 *   reached BY a sample rather than looked up, and is exempt from everything
 *   here. Decided from the source rather than from a list somebody maintains,
 *   because a list would need maintaining and would rot.
 *
 *   the SECTION is the CTEXT of the package the class physically lives in,
 *   read from its package.devc.xml. Not a table in a script: the package is
 *   where the author already made that decision.
 *
 *   the TITLE is the class's DESCRIPT, split on the first ` - ` into a header
 *   and a sub, exactly as abap2UI5/samples splits it. A header that only
 *   repeats its section heading is dropped by the generator — the section
 *   already said it.
 */
import fs from 'fs';
import path from 'path';

const unescapeXml = (s) => s
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"').replace(/&apos;/g, "'")
  .replace(/&amp;/g, '&');

const tag = (xml, name) => {
  const m = xml.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`));
  return m ? unescapeXml(m[1]) : '';
};

/** The class DESCRIPT, split the way abap2UI5/samples splits it. */
export function splitDescript(d) {
  const t = d.trim();
  const i = t.indexOf(' - ');
  return i === -1 ? { header: t, sub: '' } : { header: t.slice(0, i), sub: t.slice(i + 3) };
}

/**
 * The title and the line under it, as a catalogue shows them.
 *
 * A DESCRIPT is `Titel - Kurzbeschreibung` and its first half often repeats
 * the package heading — `OData - Two Models in One View` under the heading
 * *OData*. Under that heading the useful title is the second half, and the
 * first is noise the heading already carried.
 *
 * Both catalogues built from this scan need that decision (SAMPLES.md and the
 * page in web/), and two copies of it would drift the way two copies of the
 * scan itself once did. `fromSub` is for a renderer that emphasises a title
 * differently when it is a substitute — SAMPLES.md does.
 *
 * @returns {{title: string, sub: string, fromSub: boolean}}
 */
export function sampleTitle(s, section) {
  return s.header === section && s.sub
    ? { title: s.sub, sub: '', fromSub: true }
    : { title: s.header, sub: s.sub, fromSub: false };
}

function walk(dir, out = []) {
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    if (fs.statSync(full).isDirectory()) walk(full, out);
    else if (full.endsWith('.clas.abap')) out.push(full);
  }
  return out;
}

/** The CTEXT of a package folder, cached — several classes share one. */
function packageText(dir, cache = new Map()) {
  if (cache.has(dir)) return cache.get(dir);
  const devc = path.join(dir, 'package.devc.xml');
  const text = fs.existsSync(devc) ? tag(fs.readFileSync(devc, 'utf8'), 'CTEXT') : '';
  cache.set(dir, text);
  return text;
}

/**
 * Every class under src/, in package order, apps and helpers alike.
 *
 * @returns {{cls: string, file: string, rel: string, isApp: boolean,
 *            descript: string, header: string, sub: string,
 *            keywords: string, section: string, pkg: string}[]}
 */
export function scanSamples(root) {
  const SRC = path.join(root, 'src');
  const cache = new Map();
  const out = [];

  for (const file of walk(SRC)) {
    const cls = path.basename(file, '.clas.abap');
    const source = fs.readFileSync(file, 'utf8');
    const xmlPath = file.replace(/\.clas\.abap$/, '.clas.xml');
    const descript = fs.existsSync(xmlPath)
      ? tag(fs.readFileSync(xmlPath, 'utf8'), 'DESCRIPT')
      : '';

    const dir = path.dirname(file);
    const { header, sub } = splitDescript(descript || cls);

    out.push({
      cls,
      file,
      rel: path.relative(root, file).replace(/\\/g, '/'),
      isApp: /INTERFACES\s+z2ui5_if_app\s*\./i.test(source),
      descript,
      header,
      sub,
      keywords: (source.match(/^" @keywords (.+?)\r?$/m) || [, ''])[1].trim(),
      summary: (source.match(/^" @summary (.+?)\r?$/m) || [, ''])[1].trim(),
      section: packageText(dir, cache),
      // `src/` for the overview app, `01`, `03/01`, … for everything else, so
      // a nested subpackage sorts directly after its parent
      pkg: path.relative(SRC, dir).replace(/\\/g, '/') || '.',
    });
  }

  return out.sort((a, b) => a.pkg.localeCompare(b.pkg) || a.cls.localeCompare(b.cls));
}

/**
 * The overview app — the catalogue of this repository inside a system.
 *
 * An app like any other to abapGit, to the checks and to SAMPLES.md, and the
 * one app the page in web/ leaves out (generate-web-index.mjs says why). The
 * two generators behind that page name it from here rather than each keeping
 * a copy of the string.
 */
export const OVERVIEW_CLASS = 'z2ui5_cl_smps_app_000';

/*
 * The overview app's own catalogue, read back out — for the COMPLETENESS check
 * only, no longer as a source of text.
 *
 * It used to be the source. The overview carried a curated title and detail per
 * sample, better than the DESCRIPTs and disagreeing with them, so rendering the
 * page from it beat rendering from DESCRIPT. It was still one step short of
 * right: a sample's description sat in a DIFFERENT class from the sample. Those
 * strings have since moved onto their classes as `" @summary`, which is where
 * generate-samples-md.mjs reads them now.
 *
 * What stays is the check: every app in the tree has to appear in this
 * catalogue, or it is invisible in the overview app. check-overview.mjs checks
 * the other direction — an entry naming a class that does not exist.
 *
 * Parsed with a regex over ABAP source, which is only tolerable because the
 * shape is regular and because a miss is loud: an entry that stops matching
 * fails the completeness check rather than quietly dropping a row.
 */
const ENTRY = /sample\(\s*no\s*=\s*`([^`]*)`[\s\S]*?title\s*=\s*`([^`]*)`[\s\S]*?detail\s*=\s*`([^`]*)`[\s\S]*?classname\s*=\s*`([^`]*)`/g;

export function scanOverview(root, overviewClass = OVERVIEW_CLASS) {
  const file = path.join(root, 'src', `${overviewClass}.clas.abap`);
  const text = fs.readFileSync(file, 'utf8');
  const byClass = new Map();
  for (const m of text.matchAll(ENTRY)) {
    byClass.set(m[4].toLowerCase(), { no: m[1], title: m[2], detail: m[3] });
  }
  return byClass;
}
