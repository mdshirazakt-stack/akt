# IB Forest & Tribal Pages — Project Handoff
*Last updated: May 2026*

---

## 1. Project Overview

Two interconnected web applications for the IB Forest tribal family tree (~20,000+ people across 170+ GEDCOM files):

| App | URL | Purpose |
|---|---|---|
| **Tribal Pages** (admin/upload) | `apnonkitalash.com` | Upload & manage GEDCOM files, view people index |
| **IB Forest Browse** | `mdshiraz.com/ibforest/` | Public-facing family browse, search, tree view |
| **IB Forest Admin** | Private | Analytics, visitor management for browse app |

---

## 2. Architecture

### Two separate Supabase projects

| Project | Used by | URL |
|---|---|---|
| **Tribal Pages DB** | `index_tribal.html`, `admin.html` | `fusairoeiabmqvsbxhfi.supabase.co` |
| **IB Forest Browse DB** | `index.html` (browse), `analytics.html`, `admin.html` (browse) | `phhzdexhazfltugsilfq.supabase.co` |

### Files in this project

| File | Role |
|---|---|
| `index_tribal.html` | Tribal Pages browse app — search, index, all names, person detail |
| `admin.html` (Tribal Pages) | GEDCOM upload, bulk upload, all names export, uploads history |
| `index.html` | IB Forest public browse app — login, search, tree, relationships |
| `analytics.html` | IB Forest analytics dashboard |
| `admin.html` (IB Forest) | IB Forest visitor management — block/unblock, view visits |
| `allnames.json` | Static generated index of all 20k+ people — deploy alongside `index_tribal.html` |

---

## 3. Tribal Pages DB Schema

```sql
-- Core tables (fusairoeiabmqvsbxhfi.supabase.co)

people          -- uid (text PK), name, given_name, surname, sex,
                --   birth_date, birth_place, death_flag, death_date,
                --   death_place, occupation, marr_status,
                --   gedcom_id (FK → gedcom_uploads), raw_gedcom_id

families        -- uid (text PK), husband_uid (FK → people),
                --   wife_uid (FK → people), marr_date, marr_place,
                --   marr_status, gedcom_id (FK → gedcom_uploads)

family_members  -- family_uid (FK → families), person_uid (FK → people),
                --   role ('child'), birth_order
                --   UNIQUE (family_uid, person_uid)  ← critical constraint

gedcom_uploads  -- id (uuid PK), filename, people_count, families_count,
                --   uploaded_at

visitors        -- name_entered, visit_count, first_seen, last_seen,
                --   is_blocked, block_reason

admin_config    -- key/value store (admin_password = 'ibforest2024')
```

### Key constraint (must exist)
```sql
ALTER TABLE public.family_members
  ADD CONSTRAINT family_members_family_uid_person_uid_key
  UNIQUE (family_uid, person_uid);
```
Without this, re-uploading the same GEDCOM creates duplicate children rows.

---

## 4. IB Forest Browse DB Schema

```sql
-- Tables (phhzdexhazfltugsilfq.supabase.co)

visitors        -- id, name (text), password_used, visit_count,
                --   last_seen (timestamptz), created_at,
                --   blocked (boolean)
                --   NOTE: uses 'name' not 'name_entered'
                --   NOTE: uses 'last_seen' not 'last_visit'

passwords       -- label (person name), password (generated word-word-number)

analytics       -- session_id, event_type, event_data (jsonb),
                --   visitor_name, created_at

access_requests -- name, message, status, created_at

family_updates  -- name, message, status, created_at
```

---

## 5. GEDCOM Upload — Critical Technical Notes

### Two GEDCOM formats in use

| Source App | Files | `_UID` tags | Line endings | Xref format |
|---|---|---|---|---|
| **MyFamilyTree** (Chronoplex) | All 170+ except Shiraz | ✅ People have UUIDs | CRLF + BOM | `@I0@`, `@F0@`... |
| **TribalPages** | `01-Shiraz-familyof-Rasra.ged` | ❌ None | Unix LF | `@I1861@`, `@F1@`... |

### UID collision fix (critical)
All MyFamilyTree files use simple numeric family xrefs starting from `@F0@`. Without namespacing, every file's `F0`, `F1`... rows overwrite each other in the database.

**Fix implemented:** At push time, xref-based uids (matching `/^[A-Z]\d+$/`) are prefixed with the first 8 chars of the upload UUID:
- `F1` from upload `e8085a44-...` → stored as `e8085a44_F1`
- `F1` from upload `a3b4c5d6-...` → stored as `a3b4c5d6_F1`
- UUID-style uids from `_UID` tags are left unchanged

### Parser fix (critical)
The uid fallback (converting `@I6@` → `I6`) **must run before** `rawToUid` is built. If `rawToUid` is built first, all child/spouse references resolve to `@I6@` (with `@` signs) which doesn't match the stored uid `I6`.

Correct order in `parseGedcomSync` and `parseGedcom`:
1. Parse all lines
2. Apply uid fallback for people and families
3. Build `rawToUid` lookup
4. Resolve family members using `rawToUid`

### Re-uploading a GEDCOM
To safely re-upload without corrupting other GEDCOMs:
```sql
-- Find the UUID first
SELECT id, filename, uploaded_at FROM gedcom_uploads ORDER BY uploaded_at DESC;

-- Then delete only that upload's data
DELETE FROM public.family_members
  WHERE family_uid IN (SELECT uid FROM public.families WHERE gedcom_id = 'YOUR-UUID');
DELETE FROM public.families WHERE gedcom_id = 'YOUR-UUID';
DELETE FROM public.people WHERE gedcom_id = 'YOUR-UUID';
DELETE FROM public.gedcom_uploads WHERE id = 'YOUR-UUID';
```

---

## 6. What Was Built / Fixed This Session

### Tribal Pages (`index_tribal.html` + `admin.html`)

| Feature | Status |
|---|---|
| GEDCOM parser — zero `_UID` support (Shiraz GEDCOM) | ✅ Done |
| UID collision fix across 170+ GEDCOMs | ✅ Done |
| rawToUid ordering bug fix | ✅ Done |
| Multiple marriages per person (Kulsum, Kabir Ahmad, Sanaullah) | ✅ Done |
| Children grouped per marriage in person detail | ✅ Done |
| Index tab — per-GEDCOM paginated fetch (bypasses 1000-row cap) | ✅ Done |
| All Names tab — A–Z book index, 20k+ names | ✅ Done |
| All Names — 3-tier loading (static JSON → localStorage → live) | ✅ Done |
| All Names — person detail popup with Prev/Next navigation | ✅ Done |
| All Names — Back to Top button | ✅ Done |
| Bulk upload limit raised to 500 files | ✅ Done |
| Pre-upload GEDCOM validator (warns on bad lines, unresolved xrefs) | ✅ Done |
| Export `allnames.json` button — auto-triggers after upload | ✅ Done |
| Given Name shown for all people (fallback to name) | ✅ Done |
| Beige/warm colour theme (replacing green) | ✅ Done |

### IB Forest Browse (`index.html`, `analytics.html`, `admin.html`)

| Feature | Status |
|---|---|
| Login — case-insensitive name lookup (ilike) | ✅ Done |
| Login — visit count correctly increments (fetch-then-patch) | ✅ Done |
| Login — `last_seen` / `created_at` column names fixed | ✅ Done |
| Login — name gate (fuzzy match against TRIBE data, blocks `nqqqq`-style) | ✅ Done |
| Login — blocked user rejection with WhatsApp link | ✅ Done |
| Login — `tree_print` event logged on PDF download | ✅ Done |
| Admin — Block/Unblock visitors | ✅ Done |
| Admin — Delete visitor record | ✅ Done |
| Admin — Sortable columns (Name, Visits, First/Last visit, Status) | ✅ Done |
| Admin — IST timestamps throughout | ✅ Done |
| Admin — `adminLogin` JS syntax/order bug fixed | ✅ Done |
| Analytics — Recent activity shows full 24h window (not just 30) | ✅ Done |
| Analytics — Full IST timestamps with relative time | ✅ Done |
| Analytics — Tree views, prints, ancestor queries, tab navigation panels | ✅ Done |

---

## 7. Pending / Next Steps

### Tribal Pages

- [ ] **Tribal Pages Phase 3 — Person edit form**
  - Edit name, DOB, death, occupation, contact, sex
  - Duplicate name warning (same first+last → show existing person's details, don't block)

- [ ] **Phase 4 — Link existing people**
  - Add spouse/parent/child from existing people
  - Searchable dropdown with M/F filter
  - Confirmation dialog before committing
  - Non-destructive: only inserts new relationship row, never modifies existing

- [ ] **Phase 5 — Names & search**
  - Improved search with phonetic/fuzzy matching
  - Handle variant spellings (Maqbool / Maqbul / Makbool)

- [ ] **Phase 7 — Ancestors/descendants tree**

- [ ] **Phase 8 — Printable/PDF**
  - "House of [Village]" PDF sections
  - Villages: Rasra, Lar, Nawanagar, Bahorwan, Pindi, Ratsar, Chitbadagaaon

- [ ] **Phase 9 — Tree view**

- [ ] **Phase 10 — Kin/reports/media**

- [ ] **root_village schema**
  ```sql
  ALTER TABLE people ADD COLUMN IF NOT EXISTS root_village text;
  CREATE TABLE villages (name text PRIMARY KEY);
  INSERT INTO villages VALUES ('Rasra'),('Lar'),('Nawanagar'),
    ('Bahorwan'),('Pindi'),('Ratsar'),('Chitbadagaaon');
  ```

- [ ] **All Names popup — clicking spouse/parent/child inside popup**
  Should open that person in the same popup (currently navigates away)

- [ ] **`allnames.json` deployment workflow**
  After every bulk GEDCOM upload: download `allnames.json` → deploy alongside `index_tribal.html`

### IB Forest Browse

- [ ] **Birth order fix** — `_BORD` tag per individual in GEDCOM not yet parsed in browse app
  - `sortChildren()` needs to read `_BORD` from tribe_data.js and sort by it
  - Investigated up to checking whether `_BORD` is present for I219, I220, I221 — **pick up here**

- [ ] **tree.html cleanup** — deleted, all references consolidated to `index.html` ✅ already done

---

## 8. Deployment Checklist

### After any GEDCOM upload (Tribal Pages)
1. Go to admin → Uploads tab → click **⬇ Export allnames.json** (auto-triggered after bulk upload)
2. Download `allnames.json` 
3. Deploy `allnames.json` alongside `index_tribal.html`

### File deployment map
```
apnonkitalash.com/
├── index_tribal.html     ← Tribal Pages browse app
├── admin.html            ← GEDCOM upload + management
└── allnames.json         ← Generated static name index (regenerate after uploads)

mdshiraz.com/ibforest/
├── index.html            ← IB Forest public browse
├── analytics.html        ← Analytics dashboard
├── admin.html            ← Visitor management
└── tribe_data.js         ← GEDCOM data (generated by build_db.py from ibforest.ged)
```

---

## 9. Key Design Decisions

| Decision | Rationale |
|---|---|
| Static files only, no server | Simplest deployment, no backend maintenance |
| Two separate Supabase projects | IB Forest and Tribal Pages serve different audiences with different data |
| GEDCOM as exchange format | TribalPages is the canonical editor; IB Forest consumes exports |
| Uid namespacing with upload prefix | Prevents xref collisions when 170+ GEDCOMs share `@F0@`, `@F1@`... |
| `ilike` for visitor name lookup | Case-insensitive matching prevents duplicate visitor rows |
| localStorage + static JSON for All Names | Avoids 20k Supabase row fetches on every page load |
| Fuzzy name gate (not hard approval list) | Keeps portal open to family members without manual pre-approval, blocks gibberish |
| Children grouped per marriage | Correctly represents polygamous/remarried ancestors (Kulsum, Kabir Ahmad) |

---

## 10. Contacts & Access

| Resource | Detail |
|---|---|
| Shiraz WhatsApp | +91 98185 55830 |
| Tribal Pages Supabase | `fusairoeiabmqvsbxhfi.supabase.co` |
| IB Forest Supabase | `phhzdexhazfltugsilfq.supabase.co` |
| Admin password | `ibforest2024` |
| IB Forest browse | `mdshiraz.com/ibforest/` |
| Tribal Pages | `apnonkitalash.com` |
