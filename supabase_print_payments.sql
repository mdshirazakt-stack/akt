-- Print Tree payment records for apnonkitalash.com
-- Run once in the AKT Supabase project (fusairoeiabmqvsbxhfi.supabase.co)

CREATE TABLE IF NOT EXISTS public.print_payments (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id   uuid        REFERENCES public.visitors(id) ON DELETE SET NULL,
  visitor_name text,
  utr          text        NOT NULL,   -- UTR / Transaction ID entered by user
  amount       integer     NOT NULL DEFAULT 49,
  status       text        NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'verified', 'rejected')),
  admin_notes  text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_print_payments_utr ON public.print_payments (utr);
CREATE INDEX IF NOT EXISTS idx_print_payments_visitor ON public.print_payments (visitor_id);

ALTER TABLE public.print_payments ENABLE ROW LEVEL SECURITY;

-- Approved visitors can insert their own payment record
CREATE POLICY "print_payments_self_insert" ON public.print_payments
  FOR INSERT TO authenticated
  WITH CHECK (public.akt_is_visitor());

-- Users can read their own payments; admins read all
CREATE POLICY "print_payments_self_or_admin_read" ON public.print_payments
  FOR SELECT TO authenticated
  USING (
    visitor_id IN (SELECT id FROM public.visitors WHERE auth_user_id = auth.uid())
    OR public.akt_is_admin()
  );

-- Only admins can update (verify / reject)
CREATE POLICY "print_payments_admin_update" ON public.print_payments
  FOR UPDATE TO authenticated
  USING (public.akt_is_admin()) WITH CHECK (public.akt_is_admin());
