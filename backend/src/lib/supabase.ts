import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { config } from '../config.js';

let anon: SupabaseClient | null = null;
let admin: SupabaseClient | null = null;

export function getSupabaseAnon(): SupabaseClient {
  if (!anon) {
    anon = createClient(config.supabaseUrl, config.supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }
  return anon;
}

export function getSupabaseAdmin(): SupabaseClient {
  if (!admin) {
    admin = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }
  return admin;
}
