#!/usr/bin/env node
// Fetches all people + families from Supabase and writes a combined GEDCOM file.
// Usage: node generate-gedcom-backup.js [output-dir]
// Env:   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
'use strict';

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const KEY          = process.env.SUPABASE_SERVICE_ROLE_KEY;
const OUT_DIR      = process.argv[2] || '.';
const PAGE         = 1000;

if (!SUPABASE_URL || !KEY) {
  console.error('ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.');
  process.exit(1);
}

// ── Supabase REST fetch with offset pagination ──────────────────────────────
async function fetchAll(table, params = {}) {
  const rows = [];
  let offset = 0;
  while (true) {
    const qs = new URLSearchParams({ select: '*', ...params, offset, limit: PAGE });
    const url = `${SUPABASE_URL}/rest/v1/${table}?${qs}`;
    const resp = await fetch(url, {
      headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, Accept: 'application/json' }
    });
    if (!resp.ok) {
      const body = await resp.text();
      throw new Error(`Supabase ${table}: HTTP ${resp.status} — ${body}`);
    }
    const batch = await resp.json();
    if (!Array.isArray(batch) || batch.length === 0) break;
    rows.push(...batch);
    process.stderr.write(`  ${table}: ${rows.length}\r`);
    if (batch.length < PAGE) break;
    offset += PAGE;
  }
  console.log(`  ${table}: ${rows.length} rows`);
  return rows;
}

// ── GEDCOM helpers (ported from admin.html) ─────────────────────────────────
function gedcomDate(d) {
  const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
  return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

function gedcomText(val) {
  return String(val || '').replace(/\r?\n/g, ' ').replace(/\s+/g, ' ').trim();
}

function gedcomName(name) {
  const clean = gedcomText(name || 'Unnamed');
  if (clean.includes('/')) return clean;
  const parts = clean.trim().split(/\s+/);
  if (parts.length < 2) return clean;
  const surname = parts.pop();
  return `${parts.join(' ')} /${surname}/`;
}

function gedcomXref(raw, prefix, fallback) {
  const text = String(raw || '').trim().replace(/^@|@$/g, '');
  const value = text || `${prefix}${fallback}`;
  return `@${value.replace(/\s+/g, '_')}@`;
}

function appendNote(lines, note, level = 1) {
  const text = gedcomText(String(note || '').replace(/<br\s*\/?>/gi, '\n'));
  if (!text) return;
  const chunks = text.match(/.{1,220}(?:\s|$)/g) || [text];
  lines.push(`${level} NOTE ${chunks.shift().trim()}`);
  chunks.forEach(chunk => lines.push(`${level + 1} CONC ${chunk.trim()}`));
}

function buildGedcom({ people, families, members, filename }) {
  const personXrefs = {};
  const familyXrefs = {};

  // Use index-based xrefs (raw_gedcom_id already nulled by caller) so ids are
  // unique across all source files in the combined export.
  people.forEach((p, i)  => { personXrefs[p.uid] = gedcomXref(p.raw_gedcom_id, 'I', i + 1); });
  families.forEach((f, i) => { familyXrefs[f.uid] = gedcomXref(f.raw_gedcom_id, 'F', i + 1); });

  const famsByPerson  = {}; // FAMS links
  const famcByPerson  = {}; // FAMC links
  families.forEach(f => {
    const xr = familyXrefs[f.uid];
    if (f.husband_uid && personXrefs[f.husband_uid]) {
      (famsByPerson[f.husband_uid] = famsByPerson[f.husband_uid] || []).push(xr);
    }
    if (f.wife_uid && personXrefs[f.wife_uid]) {
      (famsByPerson[f.wife_uid] = famsByPerson[f.wife_uid] || []).push(xr);
    }
  });
  members.forEach(m => {
    if (!personXrefs[m.person_uid] || !familyXrefs[m.family_uid]) return;
    (famcByPerson[m.person_uid] = famcByPerson[m.person_uid] || []).push(familyXrefs[m.family_uid]);
  });

  const lines = [
    '0 HEAD',
    '1 SOUR APNONKITALASH',
    '2 NAME Apno Ki Talash',
    '1 GEDC',
    '2 VERS 5.5.1',
    '2 FORM LINEAGE-LINKED',
    '1 CHAR UTF-8',
    `1 DATE ${gedcomDate(new Date())}`,
    `1 FILE ${gedcomText(filename)}`,
  ];

  people.forEach(p => {
    const xr = personXrefs[p.uid];
    lines.push(`0 ${xr} INDI`);
    lines.push(`1 NAME ${gedcomName(p.name)}`);
    if (p.sex) lines.push(`1 SEX ${p.sex}`);
    if (p.birth_date || p.birth_place) {
      lines.push('1 BIRT');
      if (p.birth_date)  lines.push(`2 DATE ${gedcomText(p.birth_date)}`);
      if (p.birth_place) lines.push(`2 PLAC ${gedcomText(p.birth_place)}`);
    }
    if (p.death_flag || p.death_date || p.death_place) {
      lines.push('1 DEAT');
      if (p.death_date)  lines.push(`2 DATE ${gedcomText(p.death_date)}`);
      if (p.death_place) lines.push(`2 PLAC ${gedcomText(p.death_place)}`);
    }
    if (p.occupation)      lines.push(`1 OCCU ${gedcomText(p.occupation)}`);
    if (p.root_place)      appendNote(lines, `Root place: ${p.root_place}`);
    if (p.current_place)   appendNote(lines, `Current place: ${p.current_place}`);
    if (p.contact_address) appendNote(lines, `Mobile/contact: ${p.contact_address}`);
    if (p.email)           appendNote(lines, `Email: ${p.email}`);
    if (p.notes)           appendNote(lines, p.notes);
    (famsByPerson[p.uid] || []).forEach(xr => lines.push(`1 FAMS ${xr}`));
    (famcByPerson[p.uid] || []).forEach(xr => lines.push(`1 FAMC ${xr}`));
  });

  const membersByFamily = {};
  members.forEach(m => {
    (membersByFamily[m.family_uid] = membersByFamily[m.family_uid] || []).push(m);
  });

  families.forEach(f => {
    const xr = familyXrefs[f.uid];
    lines.push(`0 ${xr} FAM`);
    if (f.husband_uid && personXrefs[f.husband_uid]) lines.push(`1 HUSB ${personXrefs[f.husband_uid]}`);
    if (f.wife_uid    && personXrefs[f.wife_uid])    lines.push(`1 WIFE ${personXrefs[f.wife_uid]}`);
    (membersByFamily[f.uid] || [])
      .slice()
      .sort((a, b) => (a.birth_order || 999) - (b.birth_order || 999))
      .forEach(m => { if (personXrefs[m.person_uid]) lines.push(`1 CHIL ${personXrefs[m.person_uid]}`); });
    if (f.marr_date || f.marr_place || f.marr_status || f.marr_notes) {
      lines.push('1 MARR');
      if (f.marr_date)  lines.push(`2 DATE ${gedcomText(f.marr_date)}`);
      if (f.marr_place) lines.push(`2 PLAC ${gedcomText(f.marr_place)}`);
      if (f.marr_status && f.marr_status !== 'married') appendNote(lines, `Marriage status: ${f.marr_status}`, 2);
      if (f.marr_notes) appendNote(lines, f.marr_notes, 2);
    }
  });

  lines.push('0 TRLR');
  return lines.join('\n') + '\n';
}

// ── Main ────────────────────────────────────────────────────────────────────
async function main() {
  console.log('Fetching data from Supabase…');

  const [people, families, members] = await Promise.all([
    fetchAll('people',         { order: 'uid' }),
    fetchAll('families',       { order: 'uid' }),
    fetchAll('family_members', { select: 'family_uid,person_uid,role,birth_order', role: 'eq.child', order: 'birth_order' }),
  ]);

  console.log(`Building GEDCOM: ${people.length} people, ${families.length} families, ${members.length} child links…`);

  // Null out raw_gedcom_id so xrefs are index-based and unique across all sources
  const cleanPeople   = people.map(p => ({ ...p, raw_gedcom_id: null }));
  const cleanFamilies = families.map(f => ({ ...f, raw_gedcom_id: null }));

  const today    = new Date().toISOString().slice(0, 10);
  const filename = `akt_combined_${today}.ged`;
  const text     = buildGedcom({ people: cleanPeople, families: cleanFamilies, members, filename });

  const { writeFileSync } = await import('fs');
  const { join }          = await import('path');
  const outPath = join(OUT_DIR, filename);
  writeFileSync(outPath, text, 'utf8');

  const kb = (text.length / 1024).toFixed(1);
  console.log(`Written: ${outPath} (${kb} KB)`);
}

main().catch(err => { console.error(err.message || err); process.exit(1); });
