import { Router } from 'express';
import { AppError } from '../errors/AppError';
import { pool } from '../lib/db';
import { requireAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

export const profileRouter = Router();

profileRouter.get(
  '/profile',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { rows } = await pool.query(
      `SELECT id, display_name, voice_clone_id, voice_clone_status, created_at, updated_at
       FROM profiles WHERE id = $1`,
      [req.userId]
    );

    if (!rows[0]) throw new AppError(404, 'Profile not found');
    res.json(rows[0]);
  })
);
