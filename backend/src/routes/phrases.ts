import { Router } from 'express';
import { AppError } from '../errors/AppError';
import { getSupabaseAdmin } from '../lib/supabase';
import { requireAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import {
  createPhraseBody,
  listPhrasesQuery,
  updatePhraseBody,
} from '../validation/phrases';

export const phrasesRouter = Router();

phrasesRouter.use(requireAuth);

phrasesRouter.post(
  '/phrases',
  asyncHandler(async (req, res) => {
    const body = createPhraseBody.parse(req.body);
    const admin = getSupabaseAdmin();

    const { data, error } = await admin
      .from('phrases')
      .insert({
        user_id: req.userId,
        text: body.text,
        category: body.category,
        is_quick_phrase: body.is_quick_phrase,
      })
      .select()
      .single();

    if (error || !data) {
      throw new AppError(400, error?.message || 'Could not create phrase');
    }

    res.status(201).json(data);
  })
);

phrasesRouter.get(
  '/phrases',
  asyncHandler(async (req, res) => {
    const q = listPhrasesQuery.parse(req.query);
    const admin = getSupabaseAdmin();

    let query = admin
      .from('phrases')
      .select('*')
      .eq('user_id', req.userId as string);

    if (q.category) {
      query = query.eq('category', q.category);
    }

    const { data, error } = await query.order('use_count', { ascending: false });

    if (error) {
      throw new AppError(400, error.message);
    }

    res.json(data ?? []);
  })
);

phrasesRouter.put(
  '/phrases/:id',
  asyncHandler(async (req, res) => {
    const id = req.params.id;
    const patch = updatePhraseBody.parse(req.body);

    if (
      patch.text === undefined &&
      patch.category === undefined &&
      patch.is_quick_phrase === undefined
    ) {
      throw new AppError(400, 'No fields to update');
    }

    const admin = getSupabaseAdmin();
    const updatePayload: Record<string, unknown> = {};
    if (patch.text !== undefined) updatePayload.text = patch.text;
    if (patch.category !== undefined) updatePayload.category = patch.category;
    if (patch.is_quick_phrase !== undefined) {
      updatePayload.is_quick_phrase = patch.is_quick_phrase;
    }

    const { data, error } = await admin
      .from('phrases')
      .update(updatePayload)
      .eq('id', id)
      .eq('user_id', req.userId as string)
      .select()
      .maybeSingle();

    if (error) {
      throw new AppError(400, error.message);
    }
    if (!data) {
      throw new AppError(404, 'Phrase not found');
    }

    res.json(data);
  })
);

phrasesRouter.delete(
  '/phrases/:id',
  asyncHandler(async (req, res) => {
    const id = req.params.id;
    const admin = getSupabaseAdmin();

    const { data, error } = await admin
      .from('phrases')
      .delete()
      .eq('id', id)
      .eq('user_id', req.userId as string)
      .select('id')
      .maybeSingle();

    if (error) {
      throw new AppError(400, error.message);
    }
    if (!data) {
      throw new AppError(404, 'Phrase not found');
    }

    res.status(204).send();
  })
);
