import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { config } from './config';
import { errorHandler } from './middleware/errorHandler';
import { apiRateLimiter } from './middleware/rateLimit';
import { authRouter } from './routes/auth';
import { healthRouter } from './routes/health';
import { phrasesRouter } from './routes/phrases';
import { profileRouter } from './routes/profile';
import { voiceRouter } from './routes/voice';

export function createApp() {
  const app = express();
  app.set('trust proxy', 1);

  app.use(helmet());
  app.use(
    cors({
      origin:
        config.corsOrigins.includes('*') || config.corsOrigins.length === 0
          ? true
          : config.corsOrigins,
      credentials: true,
    })
  );
  app.use(express.json({ limit: '2mb' }));
  app.use(apiRateLimiter);

  app.use(healthRouter);
  app.use('/api/auth', authRouter);
  app.use('/api', profileRouter);
  app.use('/api', phrasesRouter);
  app.use('/api', voiceRouter);

  app.use(errorHandler);
  return app;
}
