# Research: node profile-pic upload (F-A, #14 compress, #15 limit)

Status: RESEARCHED (2026-09-22). Design locked, ready to implement — but sequence
AFTER `sprint/quick-ui-wins` merges (both touch `_PersonBox` in family_tree_screen).

## Decisions (minimal / ponytail)
- **Storage:** one `avatars` bucket, **public read**, path `<member_id>/avatar.jpg`,
  `upsert:true` (no orphans). Store full public URL + `?v=<epoch_ms>` cache-bust in a
  new nullable `avatar_url text` column on `family_members`.
- **Write authz reuses `can_edit_family_member(uuid)`** (migration 010) → "who can set
  avatar" == "who can edit the row". Zero new authz.
- **Packages:** `image_picker ^1.1.2` (native downscale+recompress via
  `pickImage(maxWidth:512,maxHeight:512,imageQuality:70)` — covers #14, no compression
  dep) + `cached_network_image ^3.4.1` (disk cache, justified by rural connections).
  NO cropper (BoxFit.cover). Add `flutter_image_compress` ONLY if measured sizes exceed cap.
- **#15 size cap:** 300 KB client check + server `file_size_limit=307200` on the bucket.
- **Model:** `avatarUrl` at `@HiveField(20)` (18/19 taken, 5 retired — don't reuse);
  add to toJson/fromJson/copyWith; regen family_member.g.dart.
- **Render:** keep existing gender-symbol fallback when null/loading/error (no spinner in
  36px node). member_detail CircleAvatar keeps initial as fallback.
- **Offline:** photo upload needs connectivity; on failure keep prior avatar and STILL
  save the rest of the profile (photo is optional). Bilingual snackbar.
- **l10n keys:** addPhoto, changePhoto, removePhoto, takePhoto, chooseFromGallery,
  photoUploadFailed, photoTooLarge (EN+GU).

## DRAFT migration (assign real number at build time — coordinate with R-infra's index migration to avoid a 015 collision)
```sql
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
```

## Implementation order
1. migration (avatar_url + bucket + 4 policies) 2. model avatarUrl 3. SupabaseService.uploadAvatar
4. deps 5. pick+resize flow 6. size cap 7. upload UI + states 8. render (_PersonBox + detail)
9. l10n 10. verify skill + on-device (incl. RLS: can't upload to a non-relative node).

## Owner-action (fallback only — appended to NEEDS-OWNER-ACTION)
If SQL editor rejects `file_size_limit`/`allowed_mime_types` or storage.objects policies,
create bucket `avatars` (Public) + the 4 policies + caps in the Dashboard. Verify Public.
