-- Security hardening pass for Apnon Ki Talash.
-- Run after the existing table/setup SQL files.
--
-- Important operational change:
-- Admin/moderator/superadmin database actions now require Supabase Auth.
-- Password-only admin access is legacy UI access and should not be relied on
-- for privileged database reads/writes after this migration.
--
-- Before running, verify the first owner account is linked, for example:
-- update public.visitors
-- set auth_user_id = '<supabase-auth-user-uuid>',
--     access_status = 'approved',
--     access_role = 'superadmin',
--     is_blocked = false
-- where lower(email) = lower('<owner-email>');

create or replace function public.akt_role_rank(role_name text)
returns integer
language sql
immutable
as $$
  select case role_name
    when 'visitor' then 1
    when 'moderator' then 2
    when 'admin' then 3
    when 'superadmin' then 4
    else 0
  end;
$$;

create or replace function public.akt_current_access_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select v.access_role
  from public.visitors v
  where v.auth_user_id = auth.uid()
    and coalesce(v.is_blocked, false) = false
    and coalesce(v.access_status, 'approved') = 'approved'
  order by v.last_seen desc nulls last, v.updated_at desc nulls last
  limit 1;
$$;

create or replace function public.akt_has_role(min_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.akt_role_rank(public.akt_current_access_role()) >= public.akt_role_rank(min_role);
$$;

create or replace function public.akt_is_approved_visitor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.akt_has_role('visitor');
$$;

grant execute on function public.akt_role_rank(text) to anon, authenticated;
grant execute on function public.akt_current_access_role() to anon, authenticated;
grant execute on function public.akt_has_role(text) to anon, authenticated;
grant execute on function public.akt_is_approved_visitor() to anon, authenticated;

alter table if exists public.visitors enable row level security;
alter table if exists public.visitor_consent_records enable row level security;
alter table if exists public.profile_claims enable row level security;
alter table if exists public.role_applications enable row level security;
alter table if exists public.signup_events enable row level security;
alter table if exists public.activity_logs enable row level security;
alter table if exists public.staff_activity_logs enable row level security;
alter table if exists public.admin_config enable row level security;
alter table if exists public.people enable row level security;
alter table if exists public.families enable row level security;
alter table if exists public.family_members enable row level security;
alter table if exists public.gedcom_uploads enable row level security;
alter table if exists public.correction_requests enable row level security;
alter table if exists public.suggestions enable row level security;
alter table if exists public.find_requests enable row level security;
alter table if exists public.forum_categories enable row level security;
alter table if exists public.forum_threads enable row level security;
alter table if exists public.forum_posts enable row level security;
alter table if exists public.forum_flags enable row level security;
alter table if exists public.person_profile_overrides enable row level security;
alter table if exists public.relationship_overrides enable row level security;
alter table if exists public.person_identity_groups enable row level security;
alter table if exists public.person_identity_members enable row level security;
alter table if exists public.community_family_submissions enable row level security;
alter table if exists public.community_family_people enable row level security;
alter table if exists public.community_family_relationships enable row level security;
alter table if exists public.canonical_family_groups enable row level security;
alter table if exists public.canonical_family_children enable row level security;

do $$
declare
  row record;
begin
  for row in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'visitors',
        'visitor_consent_records',
        'profile_claims',
        'role_applications',
        'signup_events',
        'activity_logs',
        'staff_activity_logs',
        'admin_config',
        'people',
        'families',
        'family_members',
        'gedcom_uploads',
        'correction_requests',
        'suggestions',
        'find_requests',
        'forum_categories',
        'forum_threads',
        'forum_posts',
        'forum_flags',
        'person_profile_overrides',
        'relationship_overrides',
        'person_identity_groups',
        'person_identity_members',
        'community_family_submissions',
        'community_family_people',
        'community_family_relationships',
        'canonical_family_groups',
        'canonical_family_children'
      )
  loop
    execute format('drop policy if exists %I on %I.%I', row.policyname, row.schemaname, row.tablename);
  end loop;
end $$;

-- Visitors and consent records
create policy "visitors_self_or_admin_read"
on public.visitors
for select
to authenticated
using (
  public.akt_has_role('admin')
  or auth_user_id = auth.uid()
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
);

create policy "visitors_self_insert"
on public.visitors
for insert
to authenticated
with check (
  auth_user_id = auth.uid()
  and access_role = 'visitor'
  and access_status = 'approved'
  and coalesce(is_blocked, false) = false
);

create policy "visitors_self_update_basic"
on public.visitors
for update
to authenticated
using (
  auth_user_id = auth.uid()
  or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
)
with check (
  auth_user_id = auth.uid()
  and access_role = 'visitor'
  and access_status = 'approved'
  and coalesce(is_blocked, false) = false
);

create policy "visitors_admin_update"
on public.visitors
for update
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "visitor_consent_self_insert"
on public.visitor_consent_records
for insert
to authenticated
with check (auth_user_id = auth.uid());

create policy "visitor_consent_self_or_admin_read"
on public.visitor_consent_records
for select
to authenticated
using (auth_user_id = auth.uid() or public.akt_has_role('admin'));

-- Core archive: approved visitors may read; only admins may mutate.
create policy "people_approved_read"
on public.people
for select
to authenticated
using (public.akt_is_approved_visitor());

create policy "people_admin_write"
on public.people
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "families_approved_read"
on public.families
for select
to authenticated
using (public.akt_is_approved_visitor());

create policy "families_admin_write"
on public.families
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "family_members_approved_read"
on public.family_members
for select
to authenticated
using (public.akt_is_approved_visitor());

create policy "family_members_admin_write"
on public.family_members
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "gedcom_uploads_approved_read"
on public.gedcom_uploads
for select
to authenticated
using (public.akt_is_approved_visitor());

create policy "gedcom_uploads_admin_write"
on public.gedcom_uploads
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "admin_config_superadmin_only"
on public.admin_config
for all
to authenticated
using (public.akt_has_role('superadmin'))
with check (public.akt_has_role('superadmin'));

-- Private queues and personal data
create policy "profile_claims_self_insert"
on public.profile_claims
for insert
to authenticated
with check (auth_user_id = auth.uid() and public.akt_is_approved_visitor());

create policy "profile_claims_self_or_admin_read"
on public.profile_claims
for select
to authenticated
using (auth_user_id = auth.uid() or public.akt_has_role('admin'));

create policy "profile_claims_admin_update"
on public.profile_claims
for update
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "role_applications_self_insert"
on public.role_applications
for insert
to authenticated
with check (auth_user_id = auth.uid() and public.akt_is_approved_visitor());

create policy "role_applications_self_or_admin_read"
on public.role_applications
for select
to authenticated
using (auth_user_id = auth.uid() or public.akt_has_role('admin'));

create policy "role_applications_admin_update"
on public.role_applications
for update
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "signup_events_public_insert"
on public.signup_events
for insert
to anon, authenticated
with check (true);

create policy "signup_events_admin_read"
on public.signup_events
for select
to authenticated
using (public.akt_has_role('admin'));

-- Activity and audit logs
create policy "activity_logs_approved_insert"
on public.activity_logs
for insert
to authenticated
with check (public.akt_is_approved_visitor());

create policy "activity_logs_staff_read"
on public.activity_logs
for select
to authenticated
using (public.akt_has_role('moderator'));

create policy "staff_activity_logs_staff_insert"
on public.staff_activity_logs
for insert
to authenticated
with check (public.akt_has_role('moderator'));

create policy "staff_activity_logs_staff_read"
on public.staff_activity_logs
for select
to authenticated
using (public.akt_has_role('moderator'));

-- Community submissions: visitors submit, staff reviews.
create policy "correction_requests_approved_insert"
on public.correction_requests
for insert
to authenticated
with check (public.akt_is_approved_visitor() and coalesce(status, 'new') = 'new');

create policy "correction_requests_staff_read"
on public.correction_requests
for select
to authenticated
using (public.akt_has_role('moderator'));

create policy "correction_requests_staff_update"
on public.correction_requests
for update
to authenticated
using (public.akt_has_role('moderator'))
with check (public.akt_has_role('moderator'));

create policy "suggestions_approved_insert"
on public.suggestions
for insert
to authenticated
with check (public.akt_is_approved_visitor() and coalesce(status, 'new') = 'new');

create policy "suggestions_staff_read"
on public.suggestions
for select
to authenticated
using (public.akt_has_role('moderator'));

create policy "suggestions_staff_update"
on public.suggestions
for update
to authenticated
using (public.akt_has_role('moderator'))
with check (public.akt_has_role('moderator'));

create policy "find_requests_approved_insert"
on public.find_requests
for insert
to authenticated
with check (public.akt_is_approved_visitor() and coalesce(status, 'new') = 'new');

create policy "find_requests_staff_read"
on public.find_requests
for select
to authenticated
using (public.akt_has_role('moderator'));

create policy "find_requests_staff_update"
on public.find_requests
for update
to authenticated
using (public.akt_has_role('moderator'))
with check (public.akt_has_role('moderator'));

-- Forum: approved visitors read published content and submit pending content.
create policy "forum_categories_approved_read"
on public.forum_categories
for select
to authenticated
using (public.akt_is_approved_visitor());

create policy "forum_threads_approved_read"
on public.forum_threads
for select
to authenticated
using (status = 'published' or public.akt_has_role('moderator'));

create policy "forum_threads_approved_insert_pending"
on public.forum_threads
for insert
to authenticated
with check (public.akt_is_approved_visitor() and status = 'pending');

create policy "forum_threads_staff_update"
on public.forum_threads
for update
to authenticated
using (public.akt_has_role('moderator'))
with check (public.akt_has_role('moderator'));

create policy "forum_posts_approved_read"
on public.forum_posts
for select
to authenticated
using (status = 'published' or public.akt_has_role('moderator'));

create policy "forum_posts_approved_insert_pending"
on public.forum_posts
for insert
to authenticated
with check (public.akt_is_approved_visitor() and status = 'pending');

create policy "forum_posts_staff_update"
on public.forum_posts
for update
to authenticated
using (public.akt_has_role('moderator'))
with check (public.akt_has_role('moderator'));

create policy "forum_flags_approved_insert"
on public.forum_flags
for insert
to authenticated
with check (public.akt_is_approved_visitor() and status = 'new');

create policy "forum_flags_staff_read"
on public.forum_flags
for select
to authenticated
using (public.akt_has_role('moderator'));

create policy "forum_flags_staff_update"
on public.forum_flags
for update
to authenticated
using (public.akt_has_role('moderator'))
with check (public.akt_has_role('moderator'));

-- Staff-only overlays and review/merge work areas.
create policy "person_profile_overrides_staff_only"
on public.person_profile_overrides
for all
to authenticated
using (public.akt_has_role('moderator'))
with check (public.akt_has_role('moderator'));

create policy "relationship_overrides_approved_read"
on public.relationship_overrides
for select
to authenticated
using (status = 'approved' and public.akt_is_approved_visitor() or public.akt_has_role('moderator'));

create policy "relationship_overrides_staff_write"
on public.relationship_overrides
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "identity_groups_staff_only"
on public.person_identity_groups
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "identity_members_staff_only"
on public.person_identity_members
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "community_family_submissions_staff_only"
on public.community_family_submissions
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "community_family_people_staff_only"
on public.community_family_people
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "community_family_relationships_staff_only"
on public.community_family_relationships
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "canonical_family_groups_approved_read"
on public.canonical_family_groups
for select
to authenticated
using ((status = 'approved' and public.akt_is_approved_visitor()) or public.akt_has_role('moderator'));

create policy "canonical_family_groups_staff_write"
on public.canonical_family_groups
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));

create policy "canonical_family_children_approved_read"
on public.canonical_family_children
for select
to authenticated
using (
  public.akt_has_role('moderator')
  or exists (
    select 1
    from public.canonical_family_groups g
    where g.id = canonical_family_children.family_group_id
      and g.status = 'approved'
      and public.akt_is_approved_visitor()
  )
);

create policy "canonical_family_children_staff_write"
on public.canonical_family_children
for all
to authenticated
using (public.akt_has_role('admin'))
with check (public.akt_has_role('admin'));
