import jwt from 'jsonwebtoken';
import { config } from '../config';

export interface JwtPayload {
  sub: string;   // user UUID
  email: string;
}

export function signToken(userId: string, email: string): string {
  return jwt.sign({ sub: userId, email } as JwtPayload, config.jwtSecret, {
    expiresIn: '30d',
  });
}

export function verifyToken(token: string): JwtPayload {
  return jwt.verify(token, config.jwtSecret) as JwtPayload;
}
