import { z } from 'zod';

export const phraseCategory = z.enum([
  'medical',
  'family',
  'daily',
  'emergency',
  'custom',
]);

export const createPhraseBody = z.object({
  text: z.string().min(1).max(5000),
  category: phraseCategory.default('custom'),
  is_quick_phrase: z.boolean().optional().default(false),
});

export const updatePhraseBody = z.object({
  text: z.string().min(1).max(5000).optional(),
  category: phraseCategory.optional(),
  is_quick_phrase: z.boolean().optional(),
});

export const listPhrasesQuery = z.object({
  category: phraseCategory.optional(),
});
