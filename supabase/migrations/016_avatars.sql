-- 016: Optional node profile pictures (avatars).
--
-- Adds a nullable avatar_url column to family_members and a PUBLIC storage
-- bucket 'avatars' for the image files. Photos are optional — a NULL
-- avatar_url is the normal case and the UI falls back to the gender symbol.
--
-- Storage layout: files live at '<member_id>/avatar.jpg'. Write access is
-- gated by the SAME rule as editing that member's row, via
-- public.can_edit_family_member(uuid) (added in migration 010): the first
-- path segment (foldername[1]) is the member id, so you may only write an
-- avatar for a member you are already allowed to edit. Read is public,
-- matching the public-tree model (family_members is world-readable).
--
-- Bucket limits: 300 KB (307200 bytes) per file, jpeg/png/webp only — keeps
-- us comfortably inside the Supabase free-tier storage quota at village scale.
--
-- OWNER: run this in the SQL editor. If storage.buckets rejects the
-- file_size_limit / allowed_mime_types columns on your project, create the
-- 'avatars' bucket (public, 300 KB limit, jpeg/png/webp) from the dashboard
-- Storage UI instead, then run only the ALTER TABLE + CREATE POLICY parts.

BEGIN;

ALTER TABLE public.family_members ADD COLUMN IF NOT EXISTS avatar_url text;

INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES ('avatars','avatars',true,307200,ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET public=excluded.public,
  file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

CREATE POLICY "avatars public read" ON storage.objects FOR SELECT USING (bucket_id='avatars');
CREATE POLICY "avatars insert if can edit member" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id='avatars' AND public.can_edit_family_member(((storage.foldername(name))[1])::uuid));
CREATE POLICY "avatars update if can edit member" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id='avatars' AND public.can_edit_family_member(((storage.foldername(name))[1])::uuid))
  WITH CHECK (bucket_id='avatars' AND public.can_edit_family_member(((storage.foldername(name))[1])::uuid));
CREATE POLICY "avatars delete if can edit member" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id='avatars' AND public.can_edit_family_member(((storage.foldername(name))[1])::uuid));

COMMIT;
