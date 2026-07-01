-- Support This Project — donation records for apnonkitalash.com
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)

CREATE TABLE IF NOT EXISTS public.donations (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_name    text        NOT NULL,
  donor_mobile  text,
  amount        integer     NOT NULL,
  utr           text        NOT NULL,   -- UTR / Transaction ID entered by donor
  message       text,
  status        text        NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'verified', 'rejected')),
  admin_notes   text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_donations_utr ON public.donations (utr);
CREATE INDEX IF NOT EXISTS idx_donations_created ON public.donations (created_at DESC);

ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;

-- Anyone (including anon) can insert a donation record
CREATE POLICY "donations_public_insert" ON public.donations
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- Only admins can read donation records
CREATE POLICY "donations_admin_read" ON public.donations
  FOR SELECT TO authenticated
  USING (public.akt_is_admin());

-- Only admins can update (verify / reject)
CREATE POLICY "donations_admin_update" ON public.donations
  FOR UPDATE TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());
