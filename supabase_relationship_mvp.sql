-- Relationship and new-family overlay MVP for Apno Ki Talash.
-- Run this in the AKT Supabase project used by apnonkitalash.com:
-- https://fusairoeiabmqvsbxhfi.supabase.co
--
-- GEDCOM source tables remain intact. These tables store community/admin
-- additions that can later be reviewed, exported, or merged deliberately.

create table if not exists public.person_identity_groups (
  id uuid primary key default gen_random_uuid(),
  canonical_person_uid text references public.people(uid) on delete set null,
  display_name text not null,
  notes text,
  status text not null default 'active'
    check (status in ('active', 'merged', 'archived')),
  created_by text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.person_identity_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.person_identity_groups(id) on delete cascade,
  person_uid text not null references public.people(uid) on delete cascade,
  source_role text not null default 'source_profile',
  source_strength text,
  notes text,
  created_at timestamptz default now(),
  unique (group_id, person_uid)
);

create table if not exists public.relationship_overrides (
  id uuid primary key default gen_random_uuid(),
  source_person_uid text not null references public.people(uid) on delete cascade,
  related_person_uid text references public.people(uid) on delete set null,
  related_name text,
  related_gender text,
  relationship_type text not null
    check (relationship_type in ('father', 'mother', 'spouse', 'son', 'daughter', 'sibling')),
  mode text not null default 'existing_person'
    check (mode in ('existing_person', 'new_person')),
  status text not null default 'approved'
    check (status in ('draft', 'pending', 'approved', 'rejected', 'archived')),
  source_type text not null default 'community_overlay',
  notes text,
  created_by text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  check (related_person_uid is not null or related_name is not null)
);

create table if not exists public.community_family_submissions (
  id uuid primary key default gen_random_uuid(),
  root_family_name text not null,
  root_place text,
  submitter_name text,
  submitter_mobile text,
  notes text,
  status text not null default 'draft'
    check (status in ('draft', 'pending_review', 'approved', 'archived', 'rejected')),
  created_by text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.community_family_people (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.community_family_submissions(id) on delete cascade,
  name text not null,
  gender text,
  birth_date text,
  death_date text,
  birth_place text,
  current_place text,
  notes text,
  display_order integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.community_family_relationships (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.community_family_submissions(id) on delete cascade,
  person_a_id uuid not null references public.community_family_people(id) on delete cascade,
  person_b_id uuid not null references public.community_family_people(id) on delete cascade,
  relationship_type text not null
    check (relationship_type in ('father', 'mother', 'spouse', 'son', 'daughter', 'sibling')),
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.canonical_family_groups (
  id uuid primary key default gen_random_uuid(),
  primary_person_uid text not null references public.people(uid) on delete cascade,
  spouse_person_uid text references public.people(uid) on delete set null,
  spouse_name text,
  spouse_gender text,
  label text,
  relationship_status text default 'married',
  marriage_date_text text,
  divorce_date_text text,
  merge_status text default 'reviewed',
  merged_at timestamptz,
  merged_by text,
  merge_notes text,
  status text not null default 'approved'
    check (status in ('draft', 'pending', 'approved', 'rejected', 'archived')),
  notes text,
  created_by text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  check (spouse_person_uid is not null or spouse_name is not null)
);

alter table public.canonical_family_groups
  add column if not exists relationship_status text default 'married',
  add column if not exists marriage_date_text text,
  add column if not exists divorce_date_text text,
  add column if not exists merge_status text default 'reviewed',
  add column if not exists merged_at timestamptz,
  add column if not exists merged_by text,
  add column if not exists merge_notes text;

create table if not exists public.canonical_family_children (
  id uuid primary key default gen_random_uuid(),
  family_group_id uuid not null references public.canonical_family_groups(id) on delete cascade,
  child_person_uid text references public.people(uid) on delete cascade,
  child_name text,
  birth_order integer,
  notes text,
  created_at timestamptz default now(),
  check (child_person_uid is not null or child_name is not null)
);

create index if not exists idx_person_identity_groups_canonical
  on public.person_identity_groups(canonical_person_uid);

create index if not exists idx_person_identity_members_person
  on public.person_identity_members(person_uid);

create index if not exists idx_relationship_overrides_source
  on public.relationship_overrides(source_person_uid, status);

create index if not exists idx_relationship_overrides_related
  on public.relationship_overrides(related_person_uid, status);

create index if not exists idx_community_family_submissions_status
  on public.community_family_submissions(status, created_at desc);

create index if not exists idx_community_family_people_submission
  on public.community_family_people(submission_id, display_order);

create index if not exists idx_canonical_family_groups_primary
  on public.canonical_family_groups(primary_person_uid, status);

create index if not exists idx_canonical_family_children_group
  on public.canonical_family_children(family_group_id, birth_order);
