import { z } from 'zod';

export const signupBody = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  display_name: z.string().min(1).max(200),
});

export const loginBody = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const appleBody = z.object({
  id_token: z.string().min(10),
  nonce: z.string().optional(),
});
