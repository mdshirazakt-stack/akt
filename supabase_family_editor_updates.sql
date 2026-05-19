-- Family editor direct-write additions for Apno Ki Talash.
-- Run this in the AKT Supabase project used by apnonkitalash.com:
-- https://fusairoeiabmqvsbxhfi.supabase.co

alter table public.families
  add column if not exists marr_notes text;
