# Apno Ki Talash MVP Security Review

Last updated: 2026-05-26

## Purpose

This document lists security and privacy gaps found during the first MVP wrap-up. It is intentionally practical: each item names the risk, where it exists, and what should happen before broader public rollout.

## Highest Priority Before Wider Rollout

### 1. Replace Broad Public RLS Policies

Several MVP SQL files currently use permissive policies such as `to public`, `to anon`, `using (true)`, or `with check (true)`.

Known files:

- `supabase_profile_claims.sql`
- `supabase_role_applications.sql`
- `supabase_activity_logs.sql`
- `supabase_staff_activity_logs.sql`

Risk:

- Any browser user with the anon key may read or update sensitive records if the table policy allows it.
- Profile claims contain private email/mobile data.
- Role applications contain mobile numbers, profile links, and applicant notes.
- Staff activity logs may expose admin/moderator actions.

Required fix:

- Keep public insert only where needed.
- Restrict read/update/delete to authenticated admin/superadmin users.
- For user-owned rows, allow authenticated users to read only their own records where necessary.
- Move staff-only writes into RPC functions or Edge Functions where practical.

### 2. Lock Down Admin-Only Table Writes

The client currently performs sensitive updates directly from `admin.html` and `edit.html`.

Examples:

- `people`, `families`, `family_members`
- `visitors`
- `profile_claims`
- `role_applications`
- `gedcom_uploads`
- `admin_config`

Risk:

- If RLS is absent or broad, a normal authenticated user could call the same Supabase REST operations from the browser console.

Required fix:

- Enable RLS on every table that is reachable from the browser.
- Add role-aware policies based on `public.visitors.auth_user_id = auth.uid()` and `access_role`.
- Only `admin` and `superadmin` should modify relationships, imports, exports, users, and claims.
- Moderators should only modify approved profile-detail fields.

### 3. Remove Password-Based Admin Fallback

`admin.html` still has password fallback behavior through `admin_config`.

Risk:

- Shared passwords are harder to audit and revoke.
- If `admin_config` has weak RLS, password read/update becomes a severe issue.

Required fix:

- Prefer Supabase Auth role-based admin login only.
- Remove or disable password login after confirming all admins can use Google/email auth.
- If any emergency password remains, store it server-side only and never expose it to the browser.

### 4. Protect Private Contact Fields

Private emails and mobile numbers are currently stored in `visitors`, `profile_claims`, and may be copied into `people`.

Risk:

- Public profile pages must never expose private contact details.
- Search/index exports must avoid private fields.

Required fix:

- Audit `person.html`, `index.html`, `archive.html`, exports, and admin drilldowns for private field exposure.
- Use dedicated private columns for contact verification instead of overloading public-facing fields like `contact_address`.
- Restrict private contact reads to moderator/admin/superadmin.

### 5. Split Public Inserts From Admin Review

Visitors should be able to submit corrections, suggestions, duplicate flags, forum posts, profile claims, and role applications. They should not be able to approve, edit, or delete those records.

Required fix:

- Public/authenticated users: insert only.
- Submitter: read own record if needed.
- Admin/moderator: review and update status according to role.
- Superadmin: final destructive operations.

## Important Hardening

### 6. Add Security-Definer Role Helper

Create a helper function such as:

```sql
public.current_access_role()
```

It should look up `public.visitors.access_role` by `auth.uid()` and return `visitor`, `moderator`, `admin`, or `superadmin`.

Then policies can use:

```sql
public.current_access_role() in ('admin', 'superadmin')
```

### 7. Add Audit Logging At The Database Boundary

Browser-side `staff_activity_logs` are useful but not enough.

Required fix:

- Add database triggers or RPC-level audit inserts for sensitive changes.
- Log actor auth user id, table name, action, target id, old values, and new values where practical.

### 8. Avoid Full-Table Public Reads

Several app screens read large tables client-side for search and admin convenience.

Risk:

- A determined user can inspect network requests and copy more data than intended.

Required fix:

- Keep public read access limited to fields meant for normal archive browsing.
- Use views that exclude private fields.
- Move staff views to admin-only views or RPCs.

### 9. Rate Limit Public Submissions

Corrections, suggestions, forum posts, role applications, and profile claims need basic spam control.

Required fix:

- Add per-user or per-email rate limits in SQL/RPC or Edge Functions.
- Add admin-visible duplicate/spam signals.

### 10. Scheduled Blocking And Reminders

The 72-hour claim rule is ready conceptually, but automation should be carefully deployed.

Required fix:

- Run the block job every 12 hours.
- Track reminder count and last reminder before email reminders are enabled.
- Make unblocking explicit and audited.

## Verification Checklist

Before wider launch, verify:

- RLS is enabled on every table touched from browser code.
- `anon` cannot read `visitors`, `profile_claims`, `role_applications`, `staff_activity_logs`, or private contact data.
- A normal `visitor` cannot update `people`, `families`, `family_members`, `gedcom_uploads`, `visitors.access_role`, or `visitors.access_status`.
- A `moderator` can only perform approved profile-detail updates.
- Only `admin`/`superadmin` can apply claims, manage users, import/export GEDCOM, and change relationships.
- Only `superadmin` can perform destructive bulk operations.
- Public pages do not render mobile numbers or email addresses.
- Exports do not leak private contact data unless intentionally generated for staff.

