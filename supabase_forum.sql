-- Community discussion forum for Apno Ki Talash.
-- Run this in the AKT Supabase project used by apnonkitalash.com:
-- https://fusairoeiabmqvsbxhfi.supabase.co
--
-- Public visitors can submit threads and replies. New content is stored as
-- pending and becomes visible only after admin moderation from admin.html.

create table if not exists public.forum_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.forum_threads (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.forum_categories(id) on delete cascade,
  title text not null,
  body text not null,
  author_name text not null,
  author_mobile text,
  status text not null default 'pending'
    check (status in ('pending', 'published', 'hidden', 'locked')),
  reply_count integer not null default 0,
  last_reply_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.forum_posts (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.forum_threads(id) on delete cascade,
  body text not null,
  author_name text not null,
  author_mobile text,
  status text not null default 'pending'
    check (status in ('pending', 'published', 'hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.forum_flags (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid references public.forum_threads(id) on delete cascade,
  post_id uuid references public.forum_posts(id) on delete cascade,
  reporter_name text not null,
  reason text not null,
  status text not null default 'new'
    check (status in ('new', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (thread_id is not null or post_id is not null)
);

create index if not exists idx_forum_categories_order
  on public.forum_categories(display_order, title);

create index if not exists idx_forum_threads_category_status
  on public.forum_threads(category_id, status, updated_at desc);

create index if not exists idx_forum_posts_thread_status
  on public.forum_posts(thread_id, status, created_at);

create index if not exists idx_forum_flags_status
  on public.forum_flags(status, created_at desc);

insert into public.forum_categories (slug, title, description, display_order)
values
  ('genealogy-help', 'Genealogy Help', 'Ask for help identifying people, families, source files, or family connections.', 1),
  ('corrections', 'Corrections & Clarifications', 'Discuss possible corrections before submitting formal profile updates.', 2),
  ('family-stories', 'Family Stories', 'Share memories, oral history, migration stories, and family context.', 3),
  ('community', 'Community Matters', 'Discuss community initiatives, welfare, announcements, and general matters.', 4)
on conflict (slug) do update
set title = excluded.title,
    description = excluded.description,
    display_order = excluded.display_order,
    is_active = true;
