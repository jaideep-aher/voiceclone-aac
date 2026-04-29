import 'dotenv/config';

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required environment variable: ${name}`);
  return v;
}

export const config = {
  port: Number(process.env.PORT) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL || '',
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-in-prod',
  elevenLabsApiKey: process.env.ELEVENLABS_API_KEY || '',
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
};

export function assertConfig(): void {
  required('DATABASE_URL');
  required('ELEVENLABS_API_KEY');
  if (config.nodeEnv === 'production') required('JWT_SECRET');
}
