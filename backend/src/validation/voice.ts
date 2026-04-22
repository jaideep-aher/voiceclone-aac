import { z } from 'zod';

export const synthesizeBody = z.object({
  text: z.string().min(1).max(500),
  voice_id: z.string().min(1).optional(),
  phrase_id: z.string().uuid().optional(),
});
