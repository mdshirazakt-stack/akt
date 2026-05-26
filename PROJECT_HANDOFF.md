# Apnon Ki Talash / Iraqi Biradari Project Handoff

Last updated: 2026-05-26

## Project Overview

This project has been split into two separate repositories and domains.

The split is intentional. The genealogy engine must remain isolated from the public heritage/content website so future CMS/admin work does not risk breaking Shijra functionality.

## Current AKT Status As Of 2026-05-26

Active repo:

```text
/Users/shiraz/apnonkitalash/akt
```

Active domain:

```text
https://apnonkitalash.com/
```

Current git state at handoff:

```text
Branch: main
Working tree before security hardening edit: clean
Pending security hardening changes in this turn: admin.html, SECURITY_REVIEW.md, Supabase SQL hardening files
Latest pushed commit before this hardening edit: 48a948b Add signup drop-off tracking
```

MVP status:

```text
First MVP is mostly complete and usable for authenticated community access, search, profile viewing, corrections, profile claiming, admin review, imports/exports, and native family editing.
```

Recent major AKT work completed:

- Public `index.html` is now the authenticated private archive entry point again. Users must sign in with Supabase Auth before reaching the archive.
- Supabase Auth flow supports Google OAuth and email magic link, with first-time visitor onboarding and consent capture.
- First-time users become `visitor` by default after completing registration/consent; blocking and role changes are handled from `admin.html`.
- Visitor onboarding collects name/mobile, father's name, root place, current place/address, oldest known ancestor, heard-from details, and explicit consent sections.
- Footer links to Terms & Conditions and Privacy Policy are available on public app pages.
- Public nav is horizontal again after a vertical mobile rail experiment looked poor on phones.
- Birth dates after 1990 are hidden only in public display (`index.html`, `archive.html`, `person.html`) while remaining stored/queryable in Supabase and editable by staff.
- Profile claiming is implemented. Logged-in visitors see claim reminders, can claim a profile privately, and admin can apply claim email/mobile to the actual person record.
- Admin Users table is now compact: chevron, name/email, visits, last seen, profile claim, role, and actions stay visible; mobile, family details, heard-from, registration/consent, status, and full claim details fold under the chevron.
- Admin Registered Users table was also compacted with a chevron details row.
- Visitor Activity is session-oriented: one row per visitor session, with a `View Activity` button opening detailed datewise activity for that session. Device/location/timezone are shown once in the popup, not repeated in the table.
- Security hardening now lives in `supabase_security_hardening.sql`. It adds role-aware RLS helper functions and replaces broad public policies with authenticated visitor/staff/admin policies.
- Admin password fallback is now legacy only. Use Google sign-in on `admin.html` with an approved `admin` or `superadmin` visitor record before relying on hardened RLS.
- The older setup SQL files for profile claims, role applications, signup events, activity logs, and staff logs no longer recreate broad public policies; the hardening migration owns those policies.
- Role contribution guidance lives in the `Contribution` tab, and role applications collect requested role, mobile number, profile link, and notes.
- A `User Guide` tab has been added after `Contribution` to explain first visit, profile claiming, searching, corrections, duplicate flags, and how to contact admins.
- `SECURITY_REVIEW.md` now tracks MVP security hardening work, especially RLS policy tightening, admin-only writes, private contact protection, and audit logging.
- Mobile search UX has been redesigned and pushed.
- Mobile filters now open as a compact sheet with collapsed filter sections.
- "Filter" was renamed to "Filter Search Results".
- "Source Files" was renamed to "Source Families".
- Quick filters below the search bar were removed.
- Mobile result cards were simplified to show clickable names, birth place, and source family only.
- Default blank results avoid awkward unnamed/bracket-leading records and generic "1 son / 1 daughter" style records, while those records remain searchable.
- Print tree no longer prints the large search/index result list.
- Admin visitors/activity tracking was enriched with IST timestamps, visit counts, device/timezone, and location hints.
- Admin visitor table got sortable columns and cleaner mobile-unfriendly metadata was removed.
- Visitor Activity is now grouped by browser session where a `session_id` is available; older logs fall back to same-user time-window grouping.
- New activity logs from `index.html`, `archive.html`, and `person.html` include `details.session_id` so `View Activity` can show session movements more cleanly.
- Admin Users profile-claim column now includes a compact link to the claimed profile when a claim exists or has been applied.
- GEDCOM duplicate protection was changed to a filename warning instead of person-level duplicate blocking.
- Profile correction workflow was introduced on `person.html`.
- Admin can review correction requests and apply harmless profile fields.
- Harmless profile edits now also update the source `people` record directly, so future GEDCOM export can pick them up.
- Relationship overlays were useful for exploration, but the project direction has shifted toward native genealogy table edits for real family graph changes.
- A new native family editor page was created at `edit.html`.
- `person.html` now sends `Edit Profile` to `edit.html?uid=<person_uid>`.
- `edit.html` writes directly to `people`, `families`, and `family_members`.
- `edit.html` supports editing person details, marking deceased, adding parents, adding spouse/partner family groups, adding children under a specific spouse group, moving existing children among spouse/family groups, and editing marriage facts/status.
- `edit.html` now uses UUID primary keys for newly created people/families and keeps GEDCOM-style IDs separately, preventing duplicate `people_pkey` issues when adding new spouses/children.
- `edit.html` allows adding a child even when the spouse is unknown; it creates a parent-only family group.
- Supabase key typo in `edit.html` was fixed in commit `a07fc35`.
- Family editor UX was significantly improved after the first MVP:
  - add father/mother/spouse now uses guided modals instead of browser prompts
  - add child first asks son/daughter and filters search results by sex
  - spouse search filters by opposite gender when the focus person's gender is known
  - spouse search supports paged "Load more results"
  - spouse search includes a fuzzy-search toggle, off by default
  - search results show parent names where available
  - search results now show source GEDCOM filename, not raw GEDCOM UUID
  - selected editing card is visually highlighted
  - child handles are hidden by default and appear only during move mode
  - "Move existing child here" now enables board move mode instead of opening search

Profile correction overlay currently supports these harmless fields:

- corrected name
- deceased flag
- date of birth as free text
- date of death as free text
- place of death
- mobile number
- root place
- place of birth
- current location
- birth order (`First`, `2` through `20`, `Last`)

Relationship/family modification requests are collected as review notes only for now:

- parents
- siblings
- spouse
- children

They do not directly modify the family graph yet.

Supabase profile overlay SQL has already been run by Shiraz in the AKT Supabase project. The active schema additions are:

```sql
public.person_profile_overrides
public.correction_requests correction_* columns
```

Profile overlays still exist as audit/review support, but safe approved profile fields now also write into `people`. Relationship graph edits should increasingly move away from overlays and into real `families` / `family_members` records.

## Native Family Editor MVP

New page:

```text
edit.html?uid=<person_uid>
```

Purpose:

```text
Native genealogy editor that writes to source-style tables instead of only showing overlay corrections.
```

Current implementation:

- Loads the selected person as the focus person.
- Shows father and mother from the person's parent `family_members` row.
- Shows spouse/partner groups from `families`.
- Shows children grouped under each spouse/partner family.
- Allows editing a real person row:
  - name
  - gender
  - alive/deceased flag
  - birth date/place
  - death date/place
  - notes
- Allows adding/setting father and mother.
- Allows adding a spouse/partner family group.
- Allows adding/finding a son or daughter under a specific spouse/partner group:
  - first asks whether the child is a son or daughter
  - filters search results by `sex = M` or `sex = F`
  - can create a brand-new child record if no match is found
- Allows moving existing visible child cards among spouse/partner family groups:
  - click `Move existing child here`
  - child handles appear
  - drag a child card into another visible family group
  - click `Done` in the move banner
- Allows editing marriage facts on the real `families` row:
  - `marr_date`
  - `marr_place`
  - `marr_status`
  - `marr_notes` if the new schema column has been applied

Important behavior:

- Browse Tree reads from `families` and `family_members`, so edits made through `edit.html` should appear in Browse Tree after refresh.
- Newly created people inherit a source GEDCOM:
  - children prefer the husband/father's source GEDCOM when the target family has a husband
  - otherwise they fall back to the focus person's `gedcom_id`
  - other newly created people currently fall back to the focus person's `gedcom_id`
- Relationship search results resolve `people.gedcom_id` through `gedcom_uploads.filename`, e.g. `202-Shiraz-familyof-Rasra`, rather than showing raw upload UUIDs.
- Cross-GEDCOM marriages should preserve provenance:
  - each person keeps their own original `gedcom_id`
  - family rows connect them truthfully
  - UI should later show source badges for person source, spouse source, and relationship/family source

Known limitations / next fixes:

- Security hardening is the highest priority before broad public rollout. Start with `SECURITY_REVIEW.md`.
- `edit.html` still has a few prompt/confirm paths, especially deleting empty groups; most core add/search/create flows now use modals.
- Permission gating now allows moderators into profile editing while relationship/family graph operations remain admin-only in the UI guards.
- Relationship overlays still exist and can confuse users if mixed with native edits. Decide whether to hide, migrate, or archive overlay relationship tools.
- Backlog: improve the Raise Correction form before expanding duplicate review:
  - make "Flag duplicate profile" a dedicated section, not just a field inside relationship corrections
  - explain that visitors should paste the other profile link or UID and briefly say why they think it is the same person
  - split correction form areas into chevron-openable sections so users can see all available sections at once without a long intimidating form
- Need a safe way to delete/undo native family edits.
- Need source GEDCOM selector/override when creating brand-new people/families.
- Need better handling for wife with multiple husbands and husband with multiple wives in the visual editor.
- Need GEDCOM export that emits edited `people`, `families`, and `family_members`.
- Drag-and-drop move mode currently moves visible children among visible spouse/family groups for the current focus person. It does not search for children outside the current board.

Schema note:

```text
supabase_family_editor_updates.sql
```

This file adds:

```sql
alter table public.families
  add column if not exists marr_notes text;
```

Run it in the AKT Supabase project if marriage notes should persist from the marriage-details modal.

## Open Item For Tomorrow: GEDCOM Notes

GEDCOM no. 202 was checked at:

```text
/Users/shiraz/Downloads/202-Shiraz-familyof-Rasra.ged
```

Finding:

```text
The file contains 100 NOTE fields.
```

Examples include:

```text
1 NOTE Blue Star Finishers<br>Mobile - 9415051970
1 NOTE Mohammad Shiraz Anwar is a seasoned Product & Program Leadership executive...
2 CONC continuation lines...
```

Current parser status:

- `admin.html` now parses GEDCOM `NOTE`, `CONC`, and `CONT` tags into `people.notes` for future uploads.
- Existing uploaded people rows can show notes after a no-reupload SQL backfill.
- Reuploading GEDCOM 202 is not desired.

Potential no-reupload backfill file provided by Shiraz:

```text
/Users/shiraz/Downloads/import_notes.sql
```

This file was useful because it:

- adds `public.people.notes`
- updates 100 people from GEDCOM 202 using `raw_gedcom_id`

Important safety handling:

A scoped import file has been generated in the repo:

```text
supabase_import_202_notes.sql
```

It scopes every update to the latest uploaded `202-Shiraz-familyof-Rasra.ged`, because `raw_gedcom_id` values such as `@I1@` can exist in multiple GEDCOM uploads.

Recommended next steps for notes:

1. Ask Shiraz to run `supabase_profile_overrides.sql` first if the new note columns are not yet present.
2. Ask Shiraz to run `supabase_import_202_notes.sql` in the AKT Supabase project.
3. Verify a known noted profile such as raw GEDCOM `@I1@` or `@I6@`.
4. Keep source notes in `people.notes`; keep approved community notes in `person_profile_overrides.profile_note`.

## Repository 1: `akt`

Purpose: genealogy engine only.

Local path:

```text
/Users/shiraz/apnonkitalash/akt
```

Domain:

```text
apnonkitalash.com
```

Expected root contents:

```text
CNAME
index.html          public under-development holding page
forum.html          public community forum
archive.html        working genealogy explorer
admin.html
allnames.json
legacy-code/
```

Important notes:

- `index.html` is the public holding page while the site is under development.
- `forum.html` is a public discussion forum using the existing `forum_*` Supabase tables.
- `archive.html` is the Shijra genealogy explorer used for background development.
- `admin.html` is the Shijra admin/import/export utility.
- `allnames.json` must stay beside `archive.html`, because the explorer uses:

```js
fetch('allnames.json')
```

- `CNAME` should contain:

```text
apnonkitalash.com
```

- Do not move Shijra into `/shijra/` anymore.
- Do not add public heritage portal pages to this repo.
- Do not mix Iraqi Biradari CMS/admin content into this repo.

Current Git state/context:

- The repo was restored to genealogy-only.
- Latest local cleanup commit was:

```text
9f2f700 Restore akt as genealogy-only site
```

Check before continuing:

```bash
cd /Users/shiraz/apnonkitalash/akt
git status
```

If needed, push:

```bash
git push
```

## Repository 2: `iraqibiradari-site`

Purpose: public Iraqi Biradari heritage portal.

Local path:

```text
/Users/shiraz/apnonkitalash/iraqibiradari-site
```

Domain:

```text
iraqibiradari.com
```

Expected root contents:

```text
CNAME
index.html
about/
events/
documents/
videos/
contact/
admin/
assets/
```

Important notes:

- `CNAME` should contain:

```text
iraqibiradari.com
```

- All Shijra links in this repo should point to:

```text
https://apnonkitalash.com/
```

- Do not host or duplicate the genealogy engine inside this repo.
- This repo is for content, heritage pages, videos, PDFs, events, announcements, and future admin console.

Current Git state/context:

- The repo was initialized locally.
- Initial commit was:

```text
f8272c1 Initial heritage portal site
```

Check before continuing:

```bash
cd /Users/shiraz/apnonkitalash/iraqibiradari-site
git status
git remote -v
```

If remote is missing, add it after creating the GitHub repo:

```bash
git remote add origin git@github-akt:mdshirazakt-stack/iraqibiradari-site.git
git push -u origin main
```

If remote already exists, push:

```bash
git push -u origin main
```

## Domain / DNS Mapping

Use this final domain ownership:

```text
apnonkitalash.com  -> akt
iraqibiradari.com  -> iraqibiradari-site
```

For GitHub Pages apex domains, recommended DNS records are:

```text
Type: A
Host: @
Value: 185.199.108.153

Type: A
Host: @
Value: 185.199.109.153

Type: A
Host: @
Value: 185.199.110.153

Type: A
Host: @
Value: 185.199.111.153
```

For `www`:

```text
Type: CNAME
Host: www
Value: mdshirazakt-stack.github.io
```

Optional IPv6:

```text
Type: AAAA
Host: @
Value: 2606:50c0:8000::153

Type: AAAA
Host: @
Value: 2606:50c0:8001::153

Type: AAAA
Host: @
Value: 2606:50c0:8002::153

Type: AAAA
Host: @
Value: 2606:50c0:8003::153
```

Remove old/conflicting parking, forwarding, A, AAAA, or CNAME records for `@` and `www`.

## Design Direction For `iraqibiradari-site`

The site should feel like:

- historical archive
- manuscript collection
- cultural registry
- heritage institution

Preferred visual direction:

- deep green
- cream/off-white
- muted gold
- charcoal text
- subtle Islamic/archival influence
- timeless and calm

Avoid:

- startup aesthetic
- flashy gradients
- SaaS dashboard look
- excessive animation
- heavy frameworks

Technology:

```text
Static HTML
TailwindCSS via CDN for now
Vanilla JavaScript
Supabase later for content/admin data
GitHub Pages deployment
```

## Current `iraqibiradari-site` Pages

Created pages:

```text
/
/about/
/events/
/documents/
/videos/
/contact/
```

Future admin path:

```text
/admin/
```

Current public pages are static first-pass pages. They can be refined later.

## Supabase Decision

Do not use the existing Supabase account tied to:

```text
mdshiraz.akt@gmail.com
```

That account/project belongs to `apnonkitalash.com` / Shijra.

Recommended new account/project for Iraqi Biradari:

```text
Email: mdshiraz.ib@gmail.com
Project name: iraqibiradari-site
```

Reason:

- keeps genealogy data isolated
- keeps free-tier limits isolated
- avoids PDF/video storage pressure affecting Shijra
- separates admin credentials/API keys
- makes future maintenance cleaner

## Media Storage Recommendation

Do not store videos directly in Supabase.

Use:

```text
YouTube for videos
Google Drive or Supabase Storage for PDFs initially
Supabase DB only for metadata
```

Supabase should store metadata such as:

```text
title
description
youtube_url
pdf_url
thumbnail_url
event_date
category
priority
created_at
```

## Planned Supabase Tables

### `events`

```text
id
title
description
event_date
venue
banner_image
created_at
```

### `videos`

```text
id
title
youtube_url
description
thumbnail
created_at
```

### `documents`

```text
id
title
description
pdf_url
cover_image
category
created_at
```

### `announcements`

```text
id
title
body
priority
created_at
```

## Admin Console Scope

Build lightweight admin only for:

```text
Events
Videos
PDF documents/books
Announcements
```

Avoid building a full CMS initially.

Admin should support:

- add item
- edit item
- delete item
- list existing items
- simple authentication strategy, likely Supabase auth or password gate

Keep it simple and static-friendly.

## Next Recommended Steps

1. Confirm both repos are clean:

```bash
cd /Users/shiraz/apnonkitalash/akt
git status

cd /Users/shiraz/apnonkitalash/iraqibiradari-site
git status
```

2. Confirm both domains are correctly configured:

```text
apnonkitalash.com opens Shijra
iraqibiradari.com opens heritage portal
Shijra links from iraqibiradari.com open apnonkitalash.com
```

3. Create/use separate Supabase account:

```text
mdshiraz.ib@gmail.com
```

4. Create Supabase project:

```text
iraqibiradari-site
```

5. Create the four tables:

```text
events
videos
documents
announcements
```

6. Get Supabase values:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

7. Build `/admin/index.html` in `iraqibiradari-site`.

8. Connect public pages to Supabase data:

```text
/events/
/documents/
/videos/
homepage announcements/events/docs/videos sections
```

## Guardrails For Future Sessions

- Do not merge the two repos again.
- Do not move Shijra into `/shijra/`.
- Do not put Iraqi Biradari content admin into `akt`.
- Do not use the old Shijra Supabase project for portal data.
- Do not store heavy videos in Supabase.
- Keep `apnonkitalash.com` and `iraqibiradari.com` separate.
- Make small commits after each meaningful step.

## Relationship / Family Editing History

Important context: the project first explored relationship overlays, then moved toward native table edits.

The overlay approach is still present in the codebase, but it is no longer the preferred end-state for real genealogy relationships. The current direction is:

```text
Profile-safe fields -> update `people`
Real relationship/family graph edits -> update `families` and `family_members`
Audit/review/legacy overlay data -> keep for reference or migration
```

Overlay SQL file:

```text
supabase_relationship_mvp.sql
```

Run it in the AKT Supabase project:

```text
https://fusairoeiabmqvsbxhfi.supabase.co
```

Tables added by the SQL:

```text
person_identity_groups
person_identity_members
relationship_overrides
community_family_submissions
community_family_people
community_family_relationships
canonical_family_groups
canonical_family_children
```

Current implementation:

- `person.html` still contains the older edit drawer and overlay functions, but the visible `Edit Profile` entry point now goes to `edit.html?uid=<person_uid>`.
- Relationship additions can still link to an existing person across GEDCOM files or record a new person name through the older overlay path.
- Approved relationship overlays can display on the profile under “Linked Family Records”.
- Reviewed marriage/child groupings using `canonical_family_groups` were added as an interim step.
- This interim layer exposed a limitation: Browse Tree still reads the real `families` / `family_members` graph, so overlays alone do not make the tree truthful.
- The new `edit.html` native editor is intended to replace overlay-based relationship editing for actual family structure updates.
- `edit.html` now has the preferred editing path for real relationships:
  - guided add/search/create modals for parents, spouse/partner, and children
  - son/daughter child selection before child search
  - spouse search constrained to the opposite gender when possible
  - visible-card drag mode for moving children among spouse/family groups
  - source labels resolved from `gedcom_uploads.filename`
- `admin.html` now has a “Family Builder” tab for brand-new family submissions.
- Family Builder can create a family submission, add people, and add relationships within that submitted family.
- Family Builder also includes “Known Duplicate Profiles” to create identity groups and link multiple profile UIDs as the same real person.
- `archive.html` search results now support configurable result columns and preserve query, filters, page, and selected columns while moving between results and profile pages.
- Role/permission enforcement is intentionally deferred, per current plan.

Next relationship work:

- Continue improving `edit.html` as the real family editor.
- Continue replacing remaining prompt/confirm paths with proper UI, especially destructive/delete operations.
- Improve board-level drag/drop affordances and mobile behavior for move mode.
- Add explicit source GEDCOM selector/override when creating brand-new people or families.
- Add admin/moderator permission gating before public exposure.
- Add undo/delete tools for native family edits.
- Decide whether to migrate existing `relationship_overrides` and `canonical_family_groups` into real `people` / `families` / `family_members`.
- Add export logic that can emit GEDCOM from edited native tables plus useful audit/provenance metadata.

## Quick Commands

Start local server for `akt`:

```bash
cd /Users/shiraz/apnonkitalash/akt
python3 -m http.server 8000
```

Open:

```text
http://localhost:8000/
http://localhost:8000/admin.html
```

Start local server for `iraqibiradari-site`:

```bash
cd /Users/shiraz/apnonkitalash/iraqibiradari-site
python3 -m http.server 8001
```

Open:

```text
http://localhost:8001/
http://localhost:8001/about/
http://localhost:8001/events/
http://localhost:8001/documents/
http://localhost:8001/videos/
http://localhost:8001/contact/
http://localhost:8001/admin/
```
