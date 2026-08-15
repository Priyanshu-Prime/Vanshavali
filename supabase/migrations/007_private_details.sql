-- Owner-only home for sensitive per-member fields (medical, etc.) — split
-- out of family_members.deep_details, which is readable by every
-- authenticated user (correct for education/occupation/village, wrong for
-- medical information). This ships the safe structure now, before any
-- medical field is actually collected or displayed anywhere in the app
-- (confirmed: deep_details today only ever holds education/occupation/
-- has_password), so there's no existing data to migrate — just a place for
-- it to live correctly once that feature is built.
--
-- One row per CLAIMED member, 1:1 with family_members. Deliberately does
-- NOT support unclaimed placeholders having private details — there's no
-- "owner" to restrict access to until a real person claims the profile.

BEGIN;

CREATE TABLE IF NOT EXISTS public.member_private_details (
  member_id UUID PRIMARY KEY REFERENCES public.family_members(id) ON DELETE CASCADE,
  medical TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.member_private_details ENABLE ROW LEVEL SECURITY;

-- Every policy below resolves through family_members.auth_user_id — only
-- the member themselves (once claimed) can read or write their own row.
-- No "everyone can read" policy exists here at all, unlike family_members.
CREATE POLICY "Owner can view their private details"
  ON public.member_private_details
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = member_private_details.member_id
        AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Owner can insert their private details"
  ON public.member_private_details
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = member_private_details.member_id
        AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Owner can update their private details"
  ON public.member_private_details
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = member_private_details.member_id
        AND fm.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = member_private_details.member_id
        AND fm.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Owner can delete their private details"
  ON public.member_private_details
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = member_private_details.member_id
        AND fm.auth_user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.member_private_details TO authenticated;

-- Reuses set_updated_at() defined in migration 006.
DROP TRIGGER IF EXISTS trg_member_private_details_updated_at ON public.member_private_details;
CREATE TRIGGER trg_member_private_details_updated_at
  BEFORE UPDATE ON public.member_private_details
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

COMMIT;
