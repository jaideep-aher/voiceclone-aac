import { Router } from 'express';
import { AppError } from '../errors/AppError';
import { getSupabaseAdmin, getSupabaseAnon } from '../lib/supabase';
import { asyncHandler } from '../utils/asyncHandler';
import { appleBody, loginBody, signupBody } from '../validation/auth';

export const authRouter = Router();

function sessionResponse(session: {
  access_token: string;
  refresh_token: string;
  expires_in?: number;
  token_type: string;
}, user: unknown) {
  return {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_in: session.expires_in,
    token_type: session.token_type,
    user,
  };
}

authRouter.post(
  '/signup',
  asyncHandler(async (req, res) => {
    const { email, password, display_name } = signupBody.parse(req.body);
    const admin = getSupabaseAdmin();

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name },
    });

    if (createErr || !created.user) {
      throw new AppError(400, createErr?.message || 'Signup failed');
    }

    const userId = created.user.id;

    const { error: profileErr } = await admin.from('profiles').insert({
      id: userId,
      display_name,
    });

    if (profileErr) {
      await admin.auth.admin.deleteUser(userId);
      throw new AppError(400, profileErr.message);
    }

    const anon = getSupabaseAnon();
    const { data: signIn, error: signErr } = await anon.auth.signInWithPassword({
      email,
      password,
    });

    if (signErr || !signIn.session) {
      throw new AppError(500, signErr?.message || 'Login after signup failed');
    }

    res.status(201).json(sessionResponse(signIn.session, signIn.user));
  })
);

authRouter.post(
  '/login',
  asyncHandler(async (req, res) => {
    const { email, password } = loginBody.parse(req.body);
    const anon = getSupabaseAnon();
    const { data, error } = await anon.auth.signInWithPassword({ email, password });

    if (error || !data.session) {
      throw new AppError(401, error?.message || 'Invalid credentials');
    }

    res.json(sessionResponse(data.session, data.user));
  })
);

authRouter.post(
  '/apple',
  asyncHandler(async (req, res) => {
    const { id_token, nonce } = appleBody.parse(req.body);
    const anon = getSupabaseAnon();

    const { data, error } = await anon.auth.signInWithIdToken({
      provider: 'apple',
      token: id_token,
      nonce: nonce ?? undefined,
    });

    if (error || !data.session || !data.user) {
      throw new AppError(401, error?.message || 'Apple sign-in failed');
    }

    const admin = getSupabaseAdmin();
    const userId = data.user.id;
    const { data: existing } = await admin
      .from('profiles')
      .select('id')
      .eq('id', userId)
      .maybeSingle();

    if (!existing) {
      const meta = data.user.user_metadata as Record<string, unknown> | undefined;
      const fromMeta =
        (typeof meta?.full_name === 'string' && meta.full_name) ||
        (typeof meta?.name === 'string' && meta.name) ||
        '';
      const display =
        fromMeta ||
        (data.user.email ? data.user.email.split('@')[0] : '') ||
        'User';

      const { error: insErr } = await admin.from('profiles').insert({
        id: userId,
        display_name: display,
      });

      if (insErr) {
        throw new AppError(400, insErr.message);
      }
    }

    res.json(sessionResponse(data.session, data.user));
  })
);
