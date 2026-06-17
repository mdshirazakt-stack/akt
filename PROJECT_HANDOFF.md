# Apnon Ki Talash / Iraqi Biradari Project Handoff

Last updated: 2026-06-18

## Project Overview

This project has been split into two separate repositories and domains.

The split is intentional. The genealogy engine must remain isolated from the public heritage/content website so future CMS/admin work does not risk breaking Shijra functionality.

## Current AKT Status As Of 2026-06-04

Active repo:

```text
/Users/shiraz/apnonkitalash/akt
```

Active domain:

```text
https://apnonkitalash.com/
```

Current git state:

```text
Branch: main
Working tree: clean
Latest commit: 38854b0 Add post-approval onboarding guide interstitial
```

Database:

```text
Supabase project: fusairoeiabmqvsbxhfi.supabase.co
Total DB size: 65 MB / 500 MB free limit (13% used)
activity_logs: 15 MB (largest single table — see Backlog for cleanup plan)
people table: 8 MB
People in DB: ~23,909
Families in DB: ~9,384
GEDCOM files: 207
Registered users: 127
Approved users: ~92
Egress this month: 0.969 GB / 5 GB free limit (19% used)
MAU: 153 / 50,000 free limit
```

---

## Role Architecture

```text
visitor   → read archive, raise corrections, claim profile
moderator → visitor + admin panel (corrections, suggestions, forum)
admin     → moderator + edit profiles/families via edit.html and person.html
superadmin → admin + full admin panel (GEDCOM imports/exports, users, ads, payments, site stats)
```

**Admin panel (admin.html) is superadmin-only.** Admins were removed from the admin panel link and blocked by redirect to prevent accidental GEDCOM import/delete/export. Admins do their work via:
- `person.html` — edit profile details, raise corrections
- `edit.html` — edit family relationships, add/remove family members

---

## Key Pages

```text
index.html           — main archive (search, browse tree, index, user guide, contributions)
person.html          — individual profile view + edit/correction tools
edit.html            — native family tree editor (admin+)
admin.html           — operations panel (superadmin only)
onboarding-guide.html — post-approval first-login guide (EN + हिन्दी, 6 acknowledgements)
advertise.html       — ad policy, pricing, interest form (public)
terms.html           — terms & conditions, privacy policy (public)
trouble.html         — login troubleshooting, WhatsApp community links (public)
```

---

## Recent Major Work Completed (Since Last Handoff)

### Security
- **RLS emergency fix** (`supabase_rls_fix.sql`) — all tables were open to unauthenticated anon requests. Fixed with `akt_is_visitor()`, `akt_is_staff()`, `akt_is_admin()` helper functions that bypass the broken `akt_has_role()`.
- **robots.txt** — blocks all search engine crawlers (Disallow: /)
- **noindex meta tags** — added to all 10 HTML pages
- **Admin panel locked** — only superadmin can access admin.html; admin role redirected back to index.html
- **Tab-focus reload fix** — Supabase `TOKEN_REFRESHED` and `SIGNED_IN` events no longer re-initialise the app when already running; prevents page reloads on browser tab switch

### Community Badges & Roles
- `is_contributor boolean` and `community_role text` columns added to `people`
- Badges shown on person profiles and search results
- Admin can assign badges from admin.html Badges tab
- Badge filter in search drawer + badge keyword detection in search bar

### Profile Attach (Duplicate Linking)
- `person_identity_groups` and `person_identity_members` tables
- Admin can link duplicate profiles from person.html
- "Also recorded as:" shown on profile and on partner's marriage section
- Fixed: URL pasting (full profile URLs now parsed), success message persists after re-render, form hidden for non-admins

### Corrections & Notifications
- **In-app notification system** (`user_notifications` table) — when admin marks a correction completed, user sees a green banner on next login
- Admin can send follow-up queries to users; users can reply inline from the banner
- Notification delivery status (shown_at, acknowledged_at, reply_message, replied_at) visible in Corrections accordion
- **Revoke Claim** — deletes profile claim, resets `visitor_form_completed` so user re-does sign-up flow

### Divorce & Custody
- `custody_parent` column on `family_members` (father/mother/shared)
- edit.html shows custody dropdown per child when family is divorced/separated
- person.html shows `w/Father` / `w/Mother` / `Shared` badge next to children
- Browse Tree shows amber border + "Divorced" label between divorced couple boxes

### Print Tree (Paid Feature)
- `print_payments` table — UPI QR payment (9818555830@ptsbi, dynamic price)
- `print_price` stored in `admin_config` (changeable from admin Ads tab)
- `print_monetization` global toggle (enable/disable via admin)
- Per-user `print_free` flag for exemptions
- Print analytics: total clicks, paid prints, conversion rate in admin
- Admin → Print Payments tab: verify/reject UTR payments, mobile/email shown

### Advertising System
- `ads`, `ad_impressions`, `ad_inquiries` tables
- Ad popup shown once per unique user after login; 24-hour re-show for non-dismissed
- Billing metric: **shown impressions** (not dismissed — user sees ad regardless of × click)
- Admin Ads tab: impression log with user names + mobile, collapsible per-user interaction log
- advertise.html — public page with policy, pricing (₹250/shown impression), inquiry form
- "✨ Advertise with Us" shimmer button in search panel

### Index Tab Enhancements
- GEDCOM search filters by filename (not people names inside)
- Admin can **inline rename** GEDCOM files directly from Index tab
- Admin can **inline rename person names** directly from Index list (✏ button per row, full-width input, Enter to save)
- Split-pane quick view: clicking a name in Index opens person detail panel beside the list with Prev/Next navigation

### Site Stats (admin.html)
- Grouped: Members / Visits / Archive
- Members: Total Registered, Total Approved, Total Blocked, New Approved Today
- Visits: Unique Today, Unique Yesterday, Unique Last 7 Days (all from activity_logs — accurate)
- Archive: People, Families, GEDCOM files, People/Families across uploads, Repeated filenames

### Other
- **User Guide** updated: mobile number privacy, DOB privacy, how to print family tree (step-by-step with 6-generation limit explained)
- **Divorced marker** in Browse Tree / Print Tree: amber border + "Divorced" text between couple boxes
- **favicon.ico** generated (16/32/48px) from logo
- **trouble.html** — login FAQ page with two WhatsApp community group links and tag instructions
- **WhatsApp community button** in search panel (shimmer animation)
- `allnames.json` kept up to date alongside `people` table

---

## Session Update — Spouse-Handling Revamp Completion & Browse Tree Fixes (2026-06-06 → 2026-06-08)

This session finished the multi-part "spouse-handling revamp" plan from the prior session and fixed several display bugs reported directly by the user while reviewing the live tree. All changes are pushed to `main` (commits below, newest first):

```text
bf0bf40  Simplify divorced-couple indicator in Browse Tree (was too showy)
db67a6f  Fix: ancestor-row couples in Browse Tree always showed as married
97b638d  Sort spouse/marriage family groups chronologically (fixes 2nd-before-1st order)
e593206  Add Spouse/Family Audit panel — sitewide scan for ambiguous family records
f8775ea  Add "link existing spouse into existing family" flow to conflict dialog
131a823  Add explicit marriage ordering ("1st wife"/"2nd marriage" labels)
```

### 1. "Link existing spouse into existing family" flow (`f8775ea`)
Completes the conflict-dialog flow in `edit.html`. When an admin tries to add a spouse relationship that looks like it duplicates an existing family group (e.g. the new spouse should actually be the *missing* husband/wife slot of a family that already has children recorded), the conflict dialog now offers a **"Link into existing family"** action (`conflictLinkFamily()`).

- Fills the empty `husband_uid`/`wife_uid` slot on the existing `families` row directly (`UPDATE families SET husband_uid|wife_uid = focusUid WHERE uid = familyUid`) instead of creating a duplicate family group.
- Shows a confirmation dialog naming the shared children so the admin can verify it's genuinely the same family before proceeding.
- Logs the action via `logTreeChange('tree_spouse_family_linked', ...)` with `profile_uid`, `related_uid`, `family_uid`, `relation`.
- Reuses `_conflictLinkable` / `_conflictOnProceed` state set up by the existing conflict-detection code; `closeConflictModal()` now also resets `_conflictLinkable = null`.

This was the final piece of the original 6-scenario spouse-handling plan (the others — explicit marriage ordering, stop auto-importing spouse's children, dedupe divorced label — landed in earlier commits `131a823`, `a538a09`, `e0dd36c`).

### 2. Spouse / Family Audit admin panel (`e593206`)
New **read-only** superadmin-only tab in `admin.html` ("Spouse/Family Audit", `data-min-role="superadmin"`, `id="badge-familyaudit"`) that scans the whole archive for the kinds of ambiguous family records the spouse-handling work was designed to fix. Three categories surfaced:

1. **Ambiguous marriage order** — a person has 2+ family groups with no `marr_date` and no `husband_marriage_seq`/`wife_marriage_seq` set, so the UI can't determine 1st vs 2nd marriage.
2. **Multi-family children** — a child appears as a `family_members` row (`role='child'`) under 2+ different family groups (possible duplicate/misattributed record).
3. **Spouse-unknown families with children** — a family group has `husband_uid` or `wife_uid` null but already has children recorded (candidate for the new "link into existing family" flow above).

Implementation notes:
- New helper `_auditFetchAll(table, select, orderCols, extra)` does paginated `.range()` fetches. **Critically, it requires an `orderCols` argument and always calls `.order()`** — PostgREST/Postgres gives no ordering guarantee across separate `.range()` page queries without explicit `ORDER BY`, which would otherwise silently skip or duplicate rows and corrupt the audit counts. (Caught and fixed during self-review, before committing.) Called as `_auditFetchAll('families', '...', ['uid'])`, `_auditFetchAll('family_members', 'family_uid,person_uid', ['family_uid','person_uid'], q => q.eq('role','child'))`, `_auditFetchAll('people', 'uid,name,sex', ['uid'])`.
- `_auditPersonLink(p)` builds escaped links to `person.html`/`edit.html` for each flagged person.
- `loadFamilyAudit()` is the loader/renderer — pure `.select()`, no writes.
- Wired into `switchTab()`: `if (name === 'familyaudit') loadFamilyAudit();`

### 3. Chronological marriage ordering fix (`97b638d`)
**Bug reported by user:** "sometimes marriage2 is listed before marriage 1" when marriage dates are missing or out of order.

Added `dateSortKey(str)` (loose GEDCOM-date parser — pulls year/month/day out of free-text strings like "ABT 1980" or "12 JUN 1985") and `compareFamiliesForPerson(a, b, personUid)` (3-tier comparator: explicit `husband_marriage_seq`/`wife_marriage_seq` first, then parsed `marr_date`, then stable `uid` tiebreak) to `edit.html`, `person.html`, and `index.html` (identical copies, placed after `marriageOrdinalFor()`). All three files now sort `spouseFamilies` with this comparator before rendering, so marriage order is deterministic even with incomplete/missing dates.

### 4. Browse Tree: divorced ancestor couples showing as married (`db67a6f`)
**Bug reported by user (with screenshot):** drawing a lineage from the children of a divorced ancestor couple still showed them connected by the married-rings (⚭) glyph instead of the divorced glyph.

Root cause: the ancestor-row call site to `famCard()` in `index.html`'s `loadTree()` omitted the 6th argument (`marrStatus`), so the function always fell through to the "married" branch for ancestor rows (the other two `famCard()` call sites passed it correctly). Fixed: `famCard(father, 'tree-box-anc', mother, null, 0, fam.marr_status || '')`.

### 5. Simplified divorced-couple indicator styling (`bf0bf40`)
**User feedback:** "amber divorced banner is very show-off, can this be reduced a bit more simpler and indicative."

Reduced the divorced-couple display in `famCard()` from a 3-signal indicator (amber "DIVORCED" banner + 2px amber border + glyph) down to a single glyph — ⚮ (U+26AE) with `title="Divorced"` tooltip — matching the existing married-couple convention which uses a single ⚭ (U+26AD) glyph. No banner, no border.

### Data-cleanup guidance given (no code change)
User asked how to retroactively show a divorce between "Tauseef" and "Affaf Zia" (who have since remarried with different spouses and different children, no children together). Guidance given: there's no "remove child from family" button in `edit.html` (only drag-and-drop move + delete-person). The correct mechanism is to open the editor focused on the person whose two family groups both list the misattributed child, then **drag the child from the wrong family box into the correct one** — `moveChildToFamily()` deletes the child's `family_members` rows across *all* of that focus person's families and re-inserts into the target family, cleanly resolving the misattribution in one operation. Then set `marr_status = 'divorced'` (with a sensible `marr_date`/notes) on the Tauseef↔Affaf family group via the Marriage Details editor.

### ⚠️ Pending migration — must be run in Supabase SQL editor
`supabase_marriage_sequence.sql` (in repo root) has **NOT yet been run**. It adds the two nullable columns the marriage-ordering UI (`131a823`, `97b638d`) and the audit panel (`e593206`) read/write:

```sql
ALTER TABLE public.families
  ADD COLUMN IF NOT EXISTS husband_marriage_seq smallint
  CHECK (husband_marriage_seq IS NULL OR husband_marriage_seq > 0);

ALTER TABLE public.families
  ADD COLUMN IF NOT EXISTS wife_marriage_seq smallint
  CHECK (wife_marriage_seq IS NULL OR wife_marriage_seq > 0);
```

Both columns are nullable — the UI degrades gracefully (falls back to `marr_date` sort, then stable `uid` order) when they're absent, so this is not urgent, but the explicit "1st wife"/"2nd marriage" labels and the audit panel's "ambiguous marriage order" category will be more useful once it's run. User said they'd batch this with other pending SQL ("I will run all sql together").

---

## Session Update — Activity History, Community Status, Sibling Workflow & Duplicate-Family Fixes (2026-06-14 → 2026-06-16)

Commits this range (newest first):

```text
(uncommitted) Guard createSpouseFamilyWith() against duplicate family groups — reviewed PASS, ready to push
1fa9eb8  Replace birth place with native/current place in new-person dialog
c203c5a  Add Community Status flag for people joined by marriage
e0207fe  Make source-of-info optional and limit Activity History for visitors
73c2ca5  Add profile activity history with mandatory source-of-info tracking
f75978a  Fix double-submit race on person creation and spouse-merge false positive
```

### 1. Profile Activity History + Source-of-Info tracking (`73c2ca5`, `e0207fe`)
New `profile_change_log` table (`supabase_profile_change_log.sql`), dual-written from `logTreeChange()` for every tree edit (profile saves, parent/spouse/child changes, family group creation/deletion, spouse-children import, person creation).

- `edit.html` — optional "Source of info" field on the main profile form (`edit-source-of-info`) and inside the relationship modal (`relationship-source-of-info`, used for father/mother/spouse/child flows). Captured into `relationshipContext.sourceOfInfo` before the modal closes and passed through to `setParent()`, `createSpouseFamilyWith()`, `moveChildToFamily()`, `createAndAttachPerson()`.
- `person.html` — new **"Activity History"** section at the bottom of every profile:
  - **Moderators/admins** see the full change log (summary, date, actor, source — or "not recorded").
  - **Regular visitors** see only the profile's creation entry (timestamp, admin name, info source).
- Note: the field ended up **optional**, not mandatory as originally scoped — `e0207fe` relaxed the original requirement and restricted the full Activity History list to staff.

### 2. Double-submit / spouse-merge fixes (`f75978a`)
- `edit.html`: "Add new ___" submit buttons are now disabled on click (re-enabled only on error) to stop double-clicks creating near-duplicate person records.
- `person.html`: fixed a false-positive in the spouse-name matching heuristic that could merge two distinct spouse records.

### 3. Community Status / "Joined by Marriage" note (`c203c5a`)
New `people.joined_by_marriage boolean default false` column (`supabase_joined_by_marriage.sql`, applied). Admin-only "Community status" dropdown in `edit.html`'s main profile form. When set, `person.html` shows a muted note at the bottom of the profile:

> Not a birth member of the Iraqi Biradari. Connected through marriage.

Designed to be subtle/non-stigmatizing — no badge on search results, just a quiet footer note on the person's own profile.

### 4. Native/Current place + multi-sibling "Next" (`1fa9eb8`)
The "Add person" dialog in `edit.html` (used for father/mother/spouse/child) now asks for **Native place** (`root_place`) and **Current place** (`current_place`) instead of a single "Birth place".

For **child** relationships only, a new "Save & add another sibling" button keeps the dialog open after saving: the form resets (name/sex/living/birth date) but **keeps the Native/Current place values**, so an admin entering several siblings at once doesn't have to retype the family's places each time. "Cancel" works at any point in the next-next sequence.

### 5. Duplicate family-groups: diagnosis, cleanup, and safeguard (2026-06-16)
**Reported:** two identical "Family N" cards on a profile — same couple (Mohammad Mazharul Haque & Suraiya), same 3 children listed under both.

**Root cause:** `createSpouseFamilyWith()` always inserted a *new* `families` row for a husband/wife pair, with no check for an existing row for that same pair. Combined with `importSpouseExistingChildren()`'s additive-only upsert (copies a spouse's children from their *other* family rows into the new one, without removing them from the original), using "⬇ Import \<spouse\>'s children" on the new duplicate row copied the same children into both rows.

**Cleanup:** added `supabase_fix_duplicate_families.sql` — a one-time diagnostic/cleanup script:
- Step 1 finds all `husband_uid`/`wife_uid` pairs with >1 `families` row.
- Step 2 shows each duplicate row's details + linked children, to identify which to keep.
- Step 3 deletes the duplicate row's `family_members` + the row itself.

User ran it: **2 duplicate pairs found**. The Mohammad/Suraiya pair was cleaned up. The second pair is being **intentionally left in place** for now — user has a separate fix planned for it later.

**Code safeguard (reviewed PASS, not yet committed/pushed):** `createSpouseFamilyWith()` in `edit.html` now computes the husband/wife pair *before* creating a family row, checks `spouseFamilies` for an existing row with that exact pair, and if found, blocks creation and tells the admin which existing "Family N" card to use instead (via "Import children").

**Outstanding:** push this fix; revisit the second duplicate-family pair when the user is ready.

### Also landed since last handoff (2026-06-10 → 2026-06-12, see `git log` for detail)
- `38c2ec5` — Grant admin role access to Family Builder panel
- `e80ebfe` — Fix claim-status regression for visitors blocked after approval
- `1723a31` — Don't show claim deadline/overdue badges for unapproved visitors
- `80506c9` — Grant admin role access to Users, Visitor activity, Export GEDCOM and Site Stats panels
- `26bfb34` — Fix Tree Views stat capped at 1000 by Supabase row-return limit
- `024d2b4` — Add Total Profile Claimed card to Site Stats
- `e35351f` — Fix fuzzy search dropping nickname matches

---

## Session Update — Onboarding Guide Interstitial & trouble.html (2026-06-18)

Commits:

```text
38854b0  Add post-approval onboarding guide interstitial
b5a69a4  trouble.html: reorder issue cards and add email mention
7445fd1  trouble.html: add pending/blocked login status messages
```

### 1. Post-approval onboarding guide interstitial (`38854b0`)

New `onboarding-guide.html` — a blocking first-login guide shown **once per approved user** before they can access the archive. The flow intercepts inside `auth-flow.js` at both `enterVisitor()` call sites (post-login and post-onboarding-form paths).

**How it works:**
- On login, if user is approved + onboarding complete, `redirectForGuideIfNeeded(visitor)` queries `visitor_onboarding_acknowledgements` for that visitor's id.
- If no row exists → redirect to `onboarding-guide.html`.
- `onboarding-guide.html` verifies the session, visitor approval, and existing ack row on load. Redirects to `index.html` if any check fails (wrong session, not approved, already done).
- Page shows 6 content sections (English + हिन्दी tabs). Each section ends with an "I understand" checkbox. The shared acknowledgement state (`const acks = new Array(6).fill(false)`) is synced across both language tabs.
- Submit button is disabled until all 6 are checked. On submit, inserts a row into `visitor_onboarding_acknowledgements` with `visitor_id` and `language_viewed` ('en' or 'hi'), then redirects to `index.html`.
- On subsequent logins the ack row already exists → guide is skipped transparently.

**One-time enforcement:** `visitor_id` is the primary key on `visitor_onboarding_acknowledgements` — a duplicate INSERT is handled gracefully (redirects to index.html anyway).

**Admin Users tab:** `loadVisitors()` now fetches `visitor_onboarding_acknowledgements` as a 4th parallel query. New "Guide" column shows ✅ + date (with language tooltip) or ⏳ Pending. Expand panel shows full IST timestamp + language.

**SQL applied:** `supabase_onboarding_guide.sql` — `visitor_onboarding_acknowledgements` table with:
- Self-insert policy (email fallback, `akt_is_admin()` not needed)
- Self-read policy (email fallback)
- Admin-read policy (`akt_is_admin()`)
- PK on `visitor_id`, index on same column

**Retroactive users:** existing approved users who never saw the guide will be intercepted on their next login — no migration needed.

**Content (6 sections, both languages):**
1. Your Journey After Approval — 7-step flowchart from approval to permanent account link
2. Scenario 1: Profile Already Exists — how to find and claim; emphasis that clicking the button is required
3. Scenario 2: Profile Doesn't Exist — family lineage verification process; accuracy over speed
4. The 72-Hour Time Window — consequences of not claiming in time
5. Claim Only Your Own Profile — do not claim father's/mother's/grandparents' profiles
6. Profile Integrity Checks — automated checks; wrong claims cause temporary restriction

### 2. trouble.html improvements (`b5a69a4`, `7445fd1`)

- Added two new issue cards for auth-flow.js-generated blocking messages: `⏳ Pending Admin Review` (green) and `⏰ Profile not claimed within 72 hours` (amber) — explains what each status means and what to expect.
- Added "or email" to the Pending Admin Review bullet: "Contacted directly via WhatsApp or email for additional information."
- Reordered cards to match likely frequency: ⏳ green → ⏰ amber → 🔄 blue → 🚫 red → ❌ purple.

---

## SQL Files — All Run Status

All SQL files are confirmed run in Supabase **except**:

```text
supabase_profile_overrides.sql  — NOT run (person_profile_overrides table missing)
                                   Needed for "Apply Safe Fields" in Corrections tab.
                                   Skip if corrections overlay feature not needed.

supabase_marriage_sequence.sql  — NOT run (husband_marriage_seq / wife_marriage_seq
                                   columns missing on `families`)
                                   Adds explicit "1st/2nd marriage" ordering support.
                                   UI degrades gracefully without it (falls back to
                                   marr_date, then uid) — not urgent, but run when
                                   batching other pending SQL. See session notes above.
```

All other SQL files confirmed run:
- supabase_rls_fix.sql ✅ (critical — enables RLS)
- supabase_get_my_visitor.sql ⚠️ **MUST RUN** — security fix for blocked user bypass
- supabase_ads.sql ✅
- supabase_ad_inquiries.sql ✅
- supabase_user_notifications.sql ✅
- supabase_print_payments.sql ✅
- supabase_print_monetization.sql ✅
- supabase_custody_parent.sql ✅
- supabase_community_roles.sql ✅
- supabase_contributor_badge.sql ✅
- supabase_claim_revoke_notice.sql ✅
- supabase_profile_claim_delete_policy.sql ✅
- supabase_relationship_mvp.sql ✅
- supabase_access_gate.sql ✅
- supabase_activity_logs.sql ✅
- supabase_staff_activity_logs.sql ✅
- supabase_profile_claims.sql ✅
- supabase_forum.sql ✅
- supabase_signup_events.sql ✅
- supabase_role_applications.sql ✅
- supabase_family_editor_updates.sql ✅
- supabase_profile_change_log.sql ✅ (Activity History / source-of-info, see Session Update above)
- supabase_joined_by_marriage.sql ✅ (Community Status note, see Session Update above)
- supabase_onboarding_guide.sql ✅ (visitor_onboarding_acknowledgements table — applied 2026-06-18)

### One-time scripts (not standing migrations)
- supabase_fix_duplicate_families.sql — diagnostic/cleanup for duplicate `families` rows. Run once 2026-06-16: found 2 duplicate husband/wife pairs, cleaned up 1 (Mohammad Mazharul Haque / Suraiya). The 2nd pair is intentionally left for a later fix — re-run Step 1 to find it again when ready.

---

## Backlog (Not Yet Built)

### High Priority

- **Referral / vouching system** — new users enter email or mobile of an existing member to get auto-approved. Build when approved users > 200.

- **Activity log cleanup button** — activity_logs is 15 MB (largest table, 23% of DB). Admin button in Site Stats to delete logs older than 90 days. SQL:
  ```sql
  DELETE FROM public.activity_logs WHERE created_at < now() - interval '90 days';
  DELETE FROM public.staff_activity_logs WHERE created_at < now() - interval '180 days';
  ```
  Run manually in Supabase SQL editor until button is built.

- **Reactivate blocked users** — 28 users are currently blocked. Need a workflow to review and selectively reactivate. Currently requires manual DB edit.

- **Print Tree UPI payment Razorpay option** — Razorpay Option B (client-side) for automated payment verification instead of manual UTR check.

### Medium Priority

- **Browse Tree depth increase** — currently limited to 6 ancestor + 6 descendant generations. Increasing ancestors to 10 is safe (linear queries). Increasing descendants to 10 is risky (exponential query growth for large families). Consider "Load next generation" button instead.

- **eBook generator** — see detailed prompt at bottom of this file. Node.js script that queries Supabase and generates a printable HTML file organised by GEDCOM chapter with cross-references.

- **Location filter** — replace GEDCOM-filename-based locations filter with actual `birth_place`, `current_place`, `root_place`, `death_place` field values, auto-deduplicated. Planned SQL view in `supabase_places_view.sql`.

- **EmailJS notification layer** — layer email notifications on top of existing in-app notification system. Free tier: 200 emails/month. Needs EmailJS account setup (~30 min).

- **WhatsApp Business API** — fully automated WhatsApp notifications require Meta approval + backend server. Not feasible with current GitHub Pages stack.

### Low Priority / Ideas

- **Custody in Browse Tree** — show `w/Father` / `w/Mother` badges on child boxes inside the tree view (currently only on person.html profile page)
- **"Former marriage" label** in Browse Tree for divorced person's second marriage context
- **GEDCOM export** from edited native tables (`people`, `families`, `family_members`)
- **Source GEDCOM selector** when creating brand-new people/families in edit.html

---

## Database Schema Notes

### Key tables

```text
people              — archive (uid, name, sex, birth_place, death_place, root_place,
                      current_place, birth_date, death_date, death_flag, marr_status,
                      gedcom_id, notes, occupation, contact_address, email,
                      is_contributor, community_role, joined_by_marriage)
families            — family units (uid, husband_uid, wife_uid, marr_status, marr_date,
                      marr_place, marr_notes, gedcom_id)
profile_change_log — activity history (profile_uid, action, summary, source_of_info,
                      actor_name, actor_role, created_at)
family_members      — (family_uid, person_uid, role, birth_order, custody_parent)
gedcom_uploads      — (id, filename, people_count, families_count)
visitors            — registered users (auth_user_id, email, mobile, name_entered,
                      access_role, access_status, is_blocked, visitor_form_completed,
                      print_free, claim_revoke_notice, last_seen, first_seen)
activity_logs       — all user events (visitor_name, action, target, details jsonb,
                      device jsonb, created_at) — 15 MB, trim to 90 days when needed
admin_config        — key/value settings (print_monetization, print_price)
ads                 — ad campaigns (advertiser_name, image_url, status, target_impressions)
ad_impressions      — (ad_id, visitor_id, shown_at, dismissed_at)
print_payments      — (visitor_id, utr, amount, status)
user_notifications  — (recipient_mobile, recipient_email, title, message,
                      shown_at, acknowledged_at, reply_message, replied_at)
person_identity_groups/members — duplicate profile linking
canonical_family_groups/children — family overlay (community-added)
relationship_overrides — approved relationship links
correction_requests — user-submitted corrections
profile_claims      — user profile claims
visitor_onboarding_acknowledgements — one row per user who completed the onboarding guide
                      (visitor_id PK, acknowledged_at, language_viewed 'en'|'hi')
```

### RLS helper functions (created by supabase_rls_fix.sql)

```sql
public.akt_is_visitor()  — approved, non-blocked auth user
public.akt_is_staff()    — moderator or above
public.akt_is_admin()    — admin or superadmin
```

All policies use these instead of the broken `akt_has_role()`.

### Critical security function (created by supabase_get_my_visitor.sql)

```sql
public.get_my_visitor()  — SECURITY DEFINER, returns calling user's visitor record
```

**Why this exists — important context for future sessions:**

After the RLS fix, `findVisitorForUser()` in auth-flow.js reads the `visitors` table to check if a user is blocked/approved. The RLS policy `visitors_self_read` allows users to read their own record via `auth_user_id = auth.uid()`.

**The loophole:** users whose `auth_user_id` is null in the visitors table (e.g. registered before the RLS fix, or where the link wasn't established) cannot read their own record. `findVisitorForUser()` returns `null`. `visitorStatus(null)` falls back to `'approved'`. **Blocked users bypass the block entirely** — they see the app as a new user and start onboarding.

**The fix:** `get_my_visitor()` is SECURITY DEFINER (runs as DB owner, bypasses RLS). It matches the caller by `auth.uid()` OR by email from `auth.users`. Returns only the calling user's own record — safe by design. auth-flow.js calls `rpc('get_my_visitor')` first, falls back to direct table query.

**If `get_my_visitor()` is ever dropped or missing**, blocked users with null `auth_user_id` will bypass blocking again. Always ensure this function exists.

### Second RLS gap — ad_impressions UPDATE/INSERT (discovered 2026-06-05)

**The same null `auth_user_id` pattern also broke ad dismissal recording.**

The `ad_impressions_self_update` and `ad_impressions_self_insert` policies used:
```sql
USING (visitor_id IN (SELECT id FROM visitors WHERE auth_user_id = auth.uid()))
```

For users with `auth_user_id = null`, this returns no rows → UPDATE silently fails → `dismissed_at` never recorded → all impressions show as "Shown only" in admin panel even when user clearly clicked ×.

**Fix applied (must run in Supabase):**
```sql
DROP POLICY IF EXISTS "ad_impressions_self_update" ON public.ad_impressions;
CREATE POLICY "ad_impressions_self_update" ON public.ad_impressions
FOR UPDATE TO authenticated
USING (
  visitor_id IN (
    SELECT id FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
       OR lower(v.email) = lower(
            coalesce((SELECT email FROM auth.users WHERE id = auth.uid() LIMIT 1), '')
          )
  )
) WITH CHECK (true);

DROP POLICY IF EXISTS "ad_impressions_self_insert" ON public.ad_impressions;
CREATE POLICY "ad_impressions_self_insert" ON public.ad_impressions
FOR INSERT TO authenticated
WITH CHECK (
  visitor_id IN (
    SELECT id FROM public.visitors v
    WHERE v.auth_user_id = auth.uid()
       OR lower(v.email) = lower(
            coalesce((SELECT email FROM auth.users WHERE id = auth.uid() LIMIT 1), '')
          )
  )
);
```

**General pattern:** Any RLS policy OR helper function that does `WHERE auth_user_id = auth.uid()` will silently fail for users with null `auth_user_id`. Always add the email fallback: `OR lower(email) = lower((SELECT email FROM auth.users WHERE id = auth.uid() LIMIT 1))`.

**This also affects the three helper functions** (`akt_is_visitor`, `akt_is_staff`, `akt_is_admin`) — they also used `auth_user_id = auth.uid()` alone. All three must include the email fallback. Staff activity was not being recorded for admins with null `auth_user_id` because `akt_is_staff()` returned false. Run this to fix all three:
```sql
CREATE OR REPLACE FUNCTION public.akt_is_visitor() ...
CREATE OR REPLACE FUNCTION public.akt_is_staff() ...  
CREATE OR REPLACE FUNCTION public.akt_is_admin() ...
```
(See supabase_rls_fix.sql — update all three functions to add the email OR clause.)

**Also fixed (code-side):**
- Ad × dismiss button enlarged to 44×44px for mobile touch targets
- Backdrop click (dark area outside ad) now also triggers dismissal
- Error logging added to `dismissAd()` — check browser console if dismissals stop recording

**To fix a specific user's null auth_user_id:**
```sql
UPDATE public.visitors
SET auth_user_id = (SELECT id FROM auth.users WHERE email = 'user@example.com' LIMIT 1)
WHERE lower(email) = 'user@example.com' AND auth_user_id IS NULL;
```

---

## Google OAuth Consent Screen

Currently shows "fusairoeiabmqvsbxhfi.supabase.co" on the Google sign-in page.

**To fix:**
1. Google Cloud Console → APIs & Services → OAuth consent screen
2. App name → "Apno Ki Talash"
3. App logo → apnonkitalash-icon-light.png
4. Homepage → https://apnonkitalash.com
5. Authorized domains → apnonkitalash.com
6. Supabase → Authentication → URL Configuration → Site URL → https://apnonkitalash.com

---

## eBook Generator Prompt (Future Agent)

**Project context:** Apno Ki Talash (AKT) genealogy archive at apnonkitalash.com. Static HTML + Supabase. GitHub repo: https://github.com/mdshirazakt-stack/akt. Local: /Users/shiraz/apnonkitalash/akt/

**Key tables:** `gedcom_uploads` (chapter ordering by filename number), `people`, `families`, `family_members`, `canonical_family_groups`, `canonical_family_children`, `person_identity_members`/`groups`, `relationship_overrides`

**Task:** Generate a genealogy eBook — one chapter per GEDCOM file, organised by filename number. Cross-reference instead of duplicating data across GEDCOMs.

**Rules:**
1. Chapters ordered by leading number in filename (e.g. 153 in 153-Rasra.ged)
2. Each chapter covers people from that GEDCOM's `gedcom_id`
3. Organise by family units (`canonical_family_groups` + `families` table)
4. Daughter married OUT to another GEDCOM → show name + "(See Chapter N)"
5. Daughter-in-law FROM another GEDCOM → show name + "(Family details in Chapter N)"
6. Daughter married WITHIN same GEDCOM → at in-laws entry, note "See [father's name] family (this chapter)"
7. End of each chapter: cross-reference summary
8. End of book: global alphabetical index

**Output:** Single `ebook.html` in /Users/shiraz/apnonkitalash/akt/ — printable, A4, Amiri + Lato fonts, gold/green colour palette, page breaks between chapters, clickable Table of Contents.

**Implementation:** Node.js build script (`node generate-ebook.js`) querying Supabase REST API with anon key from auth-flow.js. Paginate people in batches of 1000.

---

## Quick Commands

```bash
# Start local server
cd /Users/shiraz/apnonkitalash/akt
python3 -m http.server 8000
# Open http://localhost:8000/

# Push changes
git add -A && git commit -m "message" && git push

# Check DB size
# Run in Supabase SQL editor:
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 15;
```

---

## Guardrails For Future Sessions

- Do not merge the two repos (akt and iraqibiradari-site)
- Do not move Shijra into /shijra/
- Do not put Iraqi Biradari content admin into akt
- Do not use the old Shijra Supabase project for portal data
- admin.html is superadmin-only — do not re-expose to admin role without deliberate decision
- RLS is now active on all tables — all new tables must have RLS + policies using akt_is_visitor/staff/admin
- activity_logs is 15 MB and growing — trim to 90 days when DB approaches 300 MB
- The `akt_has_role()` function is broken/missing — use `akt_is_visitor()`, `akt_is_staff()`, `akt_is_admin()` instead
- New GEDCOM imports remain superadmin-only (admins redirected away from admin.html)
- **`get_my_visitor()` SQL function must always exist** — if dropped, blocked users with null `auth_user_id` bypass blocking. See Database Schema Notes for full explanation.
- After any RLS change, verify blocked users cannot access the archive by checking that `findVisitorForUser()` correctly identifies their visitor record
- **RLS policy pattern for user-owned data:** Never use `WHERE auth_user_id = auth.uid()` alone. Always add email fallback: `OR lower(email) = lower((SELECT email FROM auth.users WHERE id = auth.uid() LIMIT 1))`. Missing this causes silent failures for users with null `auth_user_id` (common for users registered before the RLS fix).
- **ad_impressions policies** must use the email fallback pattern (see Database Schema Notes). Without it, dismissed_at is never recorded for ~50% of users.
