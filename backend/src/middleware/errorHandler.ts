import type { NextFunction, Request, Response } from 'express';
import multer from 'multer';
import { ZodError } from 'zod';
import { AppError } from '../errors/AppError';

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      res.status(400).json({ error: 'File too large (max 10MB)' });
      return;
    }
    res.status(400).json({ error: err.message });
    return;
  }

  if (err instanceof ZodError) {
    res.status(400).json({
      error: 'Validation failed',
      issues: err.flatten(),
    });
    return;
  }

  if (
    err instanceof Error &&
    err.message.startsWith('Unsupported audio type:')
  ) {
    res.status(400).json({ error: err.message });
    return;
  }

  if (err instanceof AppError) {
    if (err.responseHeaders) {
      for (const [k, v] of Object.entries(err.responseHeaders)) {
        res.setHeader(k, v);
      }
    }
    res.status(err.statusCode).json({
      error: err.message,
      ...(err.details !== undefined ? { details: err.details } : {}),
    });
    return;
  }

  const message = err instanceof Error ? err.message : 'Internal server error';
  console.error('[unhandled]', err);
  res.status(500).json({ error: message });
}
