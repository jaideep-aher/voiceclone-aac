import { randomUUID } from 'crypto';
import { extname } from 'path';
import { Router } from 'express';
import multer from 'multer';
import { parseBuffer } from 'music-metadata';
import { config } from '../config';
import { AppError } from '../errors/AppError';
import { addVoiceFromSample, deleteVoice, synthesizeSpeech } from '../lib/elevenlabs';
import { getSupabaseAdmin } from '../lib/supabase';
import { requireAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { synthesizeBody } from '../validation/voice';

const MAX_BYTES = 10 * 1024 * 1024;
const ALLOWED_MIME = new Set([
  'audio/mpeg',
  'audio/mp3',
  'audio/wav',
  'audio/x-wav',
  'audio/wave',
  'audio/mp4',
  'audio/m4a',
  'audio/x-m4a',
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES },
  fileFilter: (_req, file, cb) => {
    const mt = (file.mimetype || '').toLowerCase();
    if (ALLOWED_MIME.has(mt)) {
      cb(null, true);
      return;
    }
    cb(new Error(`Unsupported audio type: ${file.mimetype}`));
  },
});

export const voiceRouter = Router();
voiceRouter.use(requireAuth);

voiceRouter.get(
  '/voice/status',
  asyncHandler(async (req, res) => {
    const admin = getSupabaseAdmin();
    const { data, error } = await admin
      .from('profiles')
      .select('voice_clone_id, voice_clone_status')
      .eq('id', req.userId as string)
      .single();

    if (error || !data) {
      throw new AppError(404, error?.message || 'Profile not found');
    }

    res.json({
      voice_id: data.voice_clone_id,
      status: data.voice_clone_status,
    });
  })
);

voiceRouter.delete(
  '/voice/clone',
  asyncHandler(async (req, res) => {
    const admin = getSupabaseAdmin();
    const { data: profile, error: profErr } = await admin
      .from('profiles')
      .select('voice_clone_id')
      .eq('id', req.userId as string)
      .single();

    if (profErr || !profile) {
      throw new AppError(404, profErr?.message || 'Profile not found');
    }

    const vid = profile.voice_clone_id;
    if (vid) {
      await deleteVoice(vid);
    }

    const { error: upErr } = await admin
      .from('profiles')
      .update({
        voice_clone_id: null,
        voice_clone_status: 'none',
      })
      .eq('id', req.userId as string);

    if (upErr) {
      throw new AppError(400, upErr.message);
    }

    res.json({ ok: true, status: 'none' });
  })
);

voiceRouter.post(
  '/voice/clone',
  upload.single('file'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new AppError(400, 'Missing file field (use multipart name "file")');
    }

    const buf = req.file.buffer;
    const meta = await parseBuffer(buf, {
      mimeType: req.file.mimetype,
      size: buf.length,
    });

    const duration = meta.format.duration;
    if (duration == null || Number.isNaN(duration)) {
      throw new AppError(400, 'Could not read audio duration');
    }
    if (duration < 10 || duration > 30) {
      throw new AppError(400, 'Audio must be between 10 and 30 seconds');
    }

    const userId = req.userId as string;
    const admin = getSupabaseAdmin();
    const bucket = config.supabaseVoiceBucket;

    const { error: stProc } = await admin
      .from('profiles')
      .update({ voice_clone_status: 'processing' })
      .eq('id', userId);

    if (stProc) {
      throw new AppError(400, stProc.message);
    }

    const ext = extname(req.file.originalname) || '.mp3';
    const samplePath = `samples/${userId}/${randomUUID()}${ext}`;

    const { error: upSample } = await admin.storage
      .from(bucket)
      .upload(samplePath, buf, {
        contentType: req.file.mimetype || 'application/octet-stream',
        upsert: false,
      });

    if (upSample) {
      await admin
        .from('profiles')
        .update({ voice_clone_status: 'failed' })
        .eq('id', userId);
      throw new AppError(400, `Storage upload failed: ${upSample.message}`);
    }

    const { data: pub } = admin.storage.from(bucket).getPublicUrl(samplePath);
    const sampleUrl = pub.publicUrl;

    const { error: insVs } = await admin.from('voice_samples').insert({
      user_id: userId,
      sample_url: sampleUrl,
      duration_seconds: duration,
    });

    if (insVs) {
      await admin
        .from('profiles')
        .update({ voice_clone_status: 'failed' })
        .eq('id', userId);
      throw new AppError(400, insVs.message);
    }

    const voiceName = `user_${userId}_voice`;

    let cloneResponseSent = false;
    try {
      const { voice_id } = await addVoiceFromSample({
        name: voiceName,
        description: 'Voice clone for AAC user',
        buffer: buf,
        filename: req.file.originalname || `sample${ext}`,
        mimeType: req.file.mimetype || 'audio/mpeg',
      });

      const { error: finErr } = await admin
        .from('profiles')
        .update({
          voice_clone_id: voice_id,
          voice_clone_status: 'active',
        })
        .eq('id', userId);

      if (finErr) {
        await deleteVoice(voice_id).catch(() => undefined);
        throw new AppError(500, finErr.message);
      }

      cloneResponseSent = true;
      res.status(201).json({ voice_id, status: 'active' as const });
    } catch (e) {
      if (!cloneResponseSent) {
        await admin
          .from('profiles')
          .update({ voice_clone_status: 'failed' })
          .eq('id', userId);
      }
      throw e;
    }
  })
);

voiceRouter.post(
  '/voice/synthesize',
  asyncHandler(async (req, res) => {
    const body = synthesizeBody.parse(req.body);
    const admin = getSupabaseAdmin();
    const userId = req.userId as string;

    let resolvedVoiceId: string;
    if (body.voice_id) {
      resolvedVoiceId = body.voice_id;
    } else {
      const { data: profile, error: pErr } = await admin
        .from('profiles')
        .select('voice_clone_id')
        .eq('id', userId)
        .single();

      if (pErr || !profile?.voice_clone_id) {
        throw new AppError(
          400,
          'No voice_id provided and profile has no cloned voice'
        );
      }
      resolvedVoiceId = profile.voice_clone_id;
    }

    const elRes = await synthesizeSpeech(resolvedVoiceId, body.text);

    res.status(200);
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Transfer-Encoding', 'chunked');

    const webBody = elRes.body;
    if (!webBody) {
      throw new AppError(502, 'Empty response from voice service');
    }

    const reader = webBody.getReader();
    const chunks: Uint8Array[] = [];

    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        if (value && value.length) {
          chunks.push(value);
          res.write(Buffer.from(value));
        }
      }
    } finally {
      res.end();
    }

    const audioBuffer = Buffer.concat(chunks.map((c) => Buffer.from(c)));

    // Only update use_count/last_used_at for saved library phrases.
    // Skipping Supabase Storage upload for ad-hoc text — iOS caches on-device.
    if (body.phrase_id) {
      void (async () => {
        try {
          const { data: phraseRow } = await admin
            .from('phrases')
            .select('id, use_count')
            .eq('id', body.phrase_id)
            .eq('user_id', userId)
            .maybeSingle();

          if (!phraseRow) return;

          await admin
            .from('phrases')
            .update({
              use_count: (phraseRow.use_count ?? 0) + 1,
              last_used_at: new Date().toISOString(),
            })
            .eq('id', phraseRow.id)
            .eq('user_id', userId);
        } catch (e) {
          console.error('[tts post-process]', e);
        }
      })();
    }
  })
);
