-- Community Status flag for person.html profile pages.
-- Run this once in Supabase SQL Editor.
--
-- Marks people whose ancestors were not part of the Iraqi Biradari but who
-- are connected to the community through marriage. Admins set this in
-- edit.html; person.html shows a gentle "Community Status" note when true.

alter table public.people
  add column if not exists joined_by_marriage boolean not null default false;
