-- Claim revocation notice column
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)
-- Stores the admin's reason when a profile claim is revoked, so the user
-- sees a prominent banner on their next login prompting them to re-claim.
-- Cleared automatically once the user successfully submits a new claim.

ALTER TABLE public.visitors
  ADD COLUMN IF NOT EXISTS claim_revoke_notice text;
