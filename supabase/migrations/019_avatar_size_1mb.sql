-- 019: raise the avatars bucket limit from 300 KB to 1 MB.
--
-- 016's 300 KB cap forced 512px / JPEG q70 photos, which showed visible 8x8
-- blocking and colour smearing (owner report, 2026-10-11). The app now saves
-- one JPEG at up to 1080px / q90 (typically 150-400 KB, occasionally more for
-- busy scenes). 1 MB leaves headroom; ~500 users x <=1 MB stays inside the
-- free tier's 1 GB storage. Idempotent: safe to re-run.
--
-- If this UPDATE errors on your project, set it in the dashboard instead:
-- Storage -> avatars -> Edit bucket -> File size limit = 1 MB.

UPDATE storage.buckets
   SET file_size_limit = 1048576
 WHERE id = 'avatars';

-- Self-check: expect 1048576.
-- SELECT file_size_limit FROM storage.buckets WHERE id = 'avatars';
