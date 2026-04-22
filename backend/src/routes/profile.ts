import { Router } from 'express';
import { AppError } from '../errors/AppError';
import { getSupabaseAdmin } from '../lib/supabase';
import { requireAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';

export const profileRouter = Router();

profileRouter.get(
  '/profile',
  requireAuth,
  asyncHandler(async (req, res) => {
    const admin = getSupabaseAdmin();
    const { data, error } = await admin
      .from('profiles')
      .select('*')
      .eq('id', req.userId as string)
      .single();

    if (error || !data) {
      throw new AppError(404, error?.message || 'Profile not found');
    }

    res.json(data);
  })
);
