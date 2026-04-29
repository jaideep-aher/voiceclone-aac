import { Router } from 'express';
import { AppError } from '../errors/AppError';
import { pool } from '../lib/db';
import { requireAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { createPhraseBody, updatePhraseBody } from '../validation/phrases';

export const phrasesRouter = Router();
phrasesRouter.use(requireAuth);

phrasesRouter.get(
  '/phrases',
  asyncHandler(async (req, res) => {
    const { rows } = await pool.query(
      `SELECT id, user_id, text, category, is_quick_phrase, audio_url,
              use_count, last_used_at, created_at
       FROM phrases
       WHERE user_id = $1
       ORDER BY use_count DESC, created_at DESC`,
      [req.userId]
    );
    res.json(rows);
  })
);

phrasesRouter.post(
  '/phrases',
  asyncHandler(async (req, res) => {
    const body = createPhraseBody.parse(req.body);
    const { rows } = await pool.query(
      `INSERT INTO phrases (user_id, text, category, is_quick_phrase)
       VALUES ($1, $2, $3, $4)
       RETURNING id, user_id, text, category, is_quick_phrase, audio_url, use_count, last_used_at, created_at`,
      [req.userId, body.text, body.category, body.is_quick_phrase]
    );
    res.status(201).json(rows[0]);
  })
);

phrasesRouter.put(
  '/phrases/:id',
  asyncHandler(async (req, res) => {
    const patch = updatePhraseBody.parse(req.body);

    if (!patch.text && !patch.category && patch.is_quick_phrase === undefined) {
      throw new AppError(400, 'No fields to update');
    }

    const sets: string[] = [];
    const vals: unknown[] = [];
    let i = 1;

    if (patch.text !== undefined)           { sets.push(`text = $${i++}`);           vals.push(patch.text); }
    if (patch.category !== undefined)       { sets.push(`category = $${i++}`);       vals.push(patch.category); }
    if (patch.is_quick_phrase !== undefined){ sets.push(`is_quick_phrase = $${i++}`);vals.push(patch.is_quick_phrase); }

    vals.push(req.params.id, req.userId);

    const { rows } = await pool.query(
      `UPDATE phrases SET ${sets.join(', ')}
       WHERE id = $${i++} AND user_id = $${i}
       RETURNING id, user_id, text, category, is_quick_phrase, audio_url, use_count, last_used_at, created_at`,
      vals
    );

    if (!rows[0]) throw new AppError(404, 'Phrase not found');
    res.json(rows[0]);
  })
);

phrasesRouter.delete(
  '/phrases/:id',
  asyncHandler(async (req, res) => {
    const { rowCount } = await pool.query(
      'DELETE FROM phrases WHERE id = $1 AND user_id = $2',
      [req.params.id, req.userId]
    );
    if (!rowCount) throw new AppError(404, 'Phrase not found');
    res.status(204).send();
  })
);
