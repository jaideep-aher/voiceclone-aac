import type { NextFunction, Request, Response } from 'express';
import { AppError } from '../errors/AppError';
import { verifyToken } from '../lib/jwt';

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new AppError(401, 'Missing Authorization bearer token');
    }
    const token = header.slice(7);
    const payload = verifyToken(token);
    req.userId = payload.sub;
    next();
  } catch (e) {
    if (e instanceof AppError) {
      next(e);
    } else {
      next(new AppError(401, 'Invalid or expired token'));
    }
  }
}
