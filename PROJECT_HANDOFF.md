# Apnon Ki Talash / Iraqi Biradari Project Handoff

Last updated: 2026-06-04

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
Latest commit: 3e01d47 Fix 7-day visitor count lower than yesterday — add explicit limits
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
index.html      — main archive (search, browse tree, index, user guide, contributions)
person.html     — individual profile view + edit/correction tools
edit.html       — native family tree editor (admin+)
admin.html      — operations panel (superadmin only)
advertise.html  — ad policy, pricing, interest form (public)
terms.html      — terms & conditions, privacy policy (public)
trouble.html    — login troubleshooting, WhatsApp community links (public)
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

## SQL Files — All Run Status

All SQL files are confirmed run in Supabase **except**:

```text
supabase_profile_overrides.sql  — NOT run (person_profile_overrides table missing)
                                   Needed for "Apply Safe Fields" in Corrections tab.
                                   Skip if corrections overlay feature not needed.
```

All other SQL files confirmed run:
- supabase_rls_fix.sql ✅ (critical — enables RLS)
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
                      is_contributor, community_role)
families            — family units (uid, husband_uid, wife_uid, marr_status, marr_date,
                      marr_place, marr_notes, gedcom_id)
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
```

### RLS helper functions (created by supabase_rls_fix.sql)

```sql
public.akt_is_visitor()  — approved, non-blocked auth user
public.akt_is_staff()    — moderator or above
public.akt_is_admin()    — admin or superadmin
```

All policies use these instead of the broken `akt_has_role()`.

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
