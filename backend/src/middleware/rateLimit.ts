import { createHash } from 'crypto';
import type { Request } from 'express';
import rateLimit from 'express-rate-limit';

function clientKey(req: Request): string {
  const auth = req.headers.authorization;
  if (auth?.startsWith('Bearer ')) {
    const token = auth.slice(7);
    const hash = createHash('sha256').update(token).digest('hex');
    return `user:${hash.slice(0, 40)}`;
  }
  const fwd = req.headers['x-forwarded-for'];
  const raw = typeof fwd === 'string' ? fwd.split(',')[0]?.trim() : undefined;
  const ip = raw || req.ip || req.socket.remoteAddress || 'unknown';
  return `ip:${ip}`;
}

export const apiRateLimiter = rateLimit({
  windowMs: 60_000,
  limit: 60,
  statusCode: 429,          // standard rate-limit status (was defaulting to 429, now explicit)
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => clientKey(req as Request),
  message: { error: 'Too many requests, please slow down.' },
});
