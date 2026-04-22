import type { NextFunction, Request, Response } from 'express';
import { getSupabaseAnon } from '../lib/supabase.js';
import { AppError } from '../errors/AppError';

export async function requireAuth(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new AppError(401, 'Missing Authorization bearer token');
    }
    const token = header.slice(7);
    const supabase = getSupabaseAnon();
    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data.user) {
      throw new AppError(401, 'Invalid or expired token');
    }
    req.user = data.user;
    req.userId = data.user.id;
    next();
  } catch (e) {
    next(e);
  }
}
