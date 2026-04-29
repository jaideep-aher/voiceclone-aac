import { randomUUID } from 'crypto';
import { extname } from 'path';
import { Router } from 'express';
import multer from 'multer';
import { parseBuffer } from 'music-metadata';
import { AppError } from '../errors/AppError';
import { addVoiceFromSample, deleteVoice, synthesizeSpeech } from '../lib/elevenlabs';
import { pool } from '../lib/db';
import { requireAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { synthesizeBody } from '../validation/voice';

const MAX_BYTES = 10 * 1024 * 1024;
const ALLOWED_MIME = new Set([
  'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/x-wav',
  'audio/wave', 'audio/mp4', 'audio/m4a', 'audio/x-m4a',
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES },
  fileFilter: (_req, file, cb) => {
    const mt = (file.mimetype || '').toLowerCase();
    ALLOWED_MIME.has(mt) ? cb(null, true) : cb(new Error(`Unsupported audio type: ${file.mimetype}`));
  },
});

export const voiceRouter = Router();
voiceRouter.use(requireAuth);

voiceRouter.get(
  '/voice/status',
  asyncHandler(async (req, res) => {
    const { rows } = await pool.query(
      'SELECT voice_clone_id, voice_clone_status FROM profiles WHERE id = $1',
      [req.userId]
    );
    if (!rows[0]) throw new AppError(404, 'Profile not found');
    res.json({ voice_id: rows[0].voice_clone_id, status: rows[0].voice_clone_status });
  })
);

voiceRouter.delete(
  '/voice/clone',
  asyncHandler(async (req, res) => {
    const { rows } = await pool.query(
      'SELECT voice_clone_id FROM profiles WHERE id = $1',
      [req.userId]
    );
    if (!rows[0]) throw new AppError(404, 'Profile not found');

    if (rows[0].voice_clone_id) {
      await deleteVoice(rows[0].voice_clone_id);
    }

    await pool.query(
      `UPDATE profiles SET voice_clone_id = NULL, voice_clone_status = 'none', updated_at = now()
       WHERE id = $1`,
      [req.userId]
    );

    res.json({ ok: true, status: 'none' });
  })
);

voiceRouter.post(
  '/voice/clone',
  upload.single('file'),
  asyncHandler(async (req, res) => {
    if (!req.file) throw new AppError(400, 'Missing file field (use multipart name "file")');

    const buf = req.file.buffer;
    const meta = await parseBuffer(buf, { mimeType: req.file.mimetype, size: buf.length });
    const duration = meta.format.duration;

    if (duration == null || Number.isNaN(duration)) throw new AppError(400, 'Could not read audio duration');
    if (duration < 10 || duration > 300) throw new AppError(400, 'Audio must be between 10 seconds and 5 minutes');

    // Mark as processing
    await pool.query(
      `UPDATE profiles SET voice_clone_status = 'processing', updated_at = now() WHERE id = $1`,
      [req.userId]
    );

    // Log the voice sample
    await pool.query(
      'INSERT INTO voice_samples (user_id, duration_seconds) VALUES ($1, $2)',
      [req.userId, duration]
    );

    try {
      const ext = extname(req.file.originalname) || '.mp3';
      const { voice_id } = await addVoiceFromSample({
        name: `user_${req.userId}_voice`,
        description: 'Voice clone for AAC user',
        buffer: buf,
        filename: req.file.originalname || `sample${ext}`,
        mimeType: req.file.mimetype || 'audio/mpeg',
      });

      await pool.query(
        `UPDATE profiles SET voice_clone_id = $1, voice_clone_status = 'active', updated_at = now()
         WHERE id = $2`,
        [voice_id, req.userId]
      );

      res.status(201).json({ voice_id, status: 'active' });
    } catch (e) {
      await pool.query(
        `UPDATE profiles SET voice_clone_status = 'failed', updated_at = now() WHERE id = $1`,
        [req.userId]
      );
      throw e;
    }
  })
);

voiceRouter.post(
  '/voice/synthesize',
  asyncHandler(async (req, res) => {
    const body = synthesizeBody.parse(req.body);

    let resolvedVoiceId: string;
    if (body.voice_id) {
      resolvedVoiceId = body.voice_id;
    } else {
      const { rows } = await pool.query(
        'SELECT voice_clone_id FROM profiles WHERE id = $1',
        [req.userId]
      );
      if (!rows[0]?.voice_clone_id) {
        throw new AppError(400, 'No voice_id provided and profile has no cloned voice');
      }
      resolvedVoiceId = rows[0].voice_clone_id;
    }

    const elRes = await synthesizeSpeech(resolvedVoiceId, body.text);
    const webBody = elRes.body;
    if (!webBody) throw new AppError(502, 'Empty response from voice service');

    res.status(200);
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Transfer-Encoding', 'chunked');

    const reader = webBody.getReader();
    const chunks: Uint8Array[] = [];
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        if (value?.length) { chunks.push(value); res.write(Buffer.from(value)); }
      }
    } finally {
      res.end();
    }

    // Update use_count for saved phrases (fire-and-forget, non-blocking)
    if (body.phrase_id) {
      void pool.query(
        `UPDATE phrases SET use_count = use_count + 1, last_used_at = now()
         WHERE id = $1 AND user_id = $2`,
        [body.phrase_id, req.userId]
      ).catch((e: Error) => console.error('[tts post-process]', e.message));
    }
  })
);
