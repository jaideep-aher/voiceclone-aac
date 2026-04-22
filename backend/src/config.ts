import 'dotenv/config';

function required(name: string): string {
  const v = process.env[name];
  if (!v) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return v;
}

export const config = {
  port: Number(process.env.PORT) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  supabaseUrl: process.env.SUPABASE_URL || '',
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  elevenLabsApiKey: process.env.ELEVENLABS_API_KEY || '',
  supabaseVoiceBucket: process.env.SUPABASE_VOICE_BUCKET || 'voiceclone-aac',
  corsOrigins: (process.env.CORS_ORIGINS || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
};

export function assertConfig(): void {
  required('SUPABASE_URL');
  required('SUPABASE_ANON_KEY');
  required('SUPABASE_SERVICE_ROLE_KEY');
  required('ELEVENLABS_API_KEY');
}
