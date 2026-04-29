import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { AppError } from '../errors/AppError';
import { pool } from '../lib/db';
import { signToken } from '../lib/jwt';
import { asyncHandler } from '../utils/asyncHandler';
import { loginBody, signupBody } from '../validation/auth';

export const authRouter = Router();

authRouter.post(
  '/signup',
  asyncHandler(async (req, res) => {
    const { email, password, display_name } = signupBody.parse(req.body);

    const exists = await pool.query('SELECT id FROM profiles WHERE email = $1', [email.toLowerCase()]);
    if (exists.rows.length > 0) {
      throw new AppError(400, 'An account with this email already exists');
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const { rows } = await pool.query(
      `INSERT INTO profiles (email, password_hash, display_name)
       VALUES ($1, $2, $3)
       RETURNING id, email, display_name, voice_clone_id, voice_clone_status, created_at, updated_at`,
      [email.toLowerCase(), passwordHash, display_name.trim()]
    );

    const user = rows[0];
    const token = signToken(user.id, user.email);

    res.status(201).json({
      access_token: token,
      token_type: 'bearer',
      expires_in: 2592000, // 30 days in seconds
      user,
    });
  })
);

authRouter.post(
  '/login',
  asyncHandler(async (req, res) => {
    const { email, password } = loginBody.parse(req.body);

    const { rows } = await pool.query(
      'SELECT id, email, display_name, password_hash, voice_clone_id, voice_clone_status, created_at, updated_at FROM profiles WHERE email = $1',
      [email.toLowerCase()]
    );

    const user = rows[0];
    // Use constant-time compare — don't reveal whether email exists
    const valid = user ? await bcrypt.compare(password, user.password_hash) : false;
    if (!user || !valid) {
      throw new AppError(401, 'Invalid email or password');
    }

    const token = signToken(user.id, user.email);

    res.json({
      access_token: token,
      token_type: 'bearer',
      expires_in: 2592000,
      user: {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
        voice_clone_id: user.voice_clone_id,
        voice_clone_status: user.voice_clone_status,
        created_at: user.created_at,
        updated_at: user.updated_at,
      },
    });
  })
);
