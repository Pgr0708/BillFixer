import { SignJWT, jwtVerify, errors as joseErrors } from 'jose';
import { config } from '../config/index.js';
import { unauthorized } from './errors.js';

const secret = new TextEncoder().encode(config.auth.accessSecret);

export async function signAccessToken(userId) {
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(userId)
    .setIssuer(config.auth.issuer)
    .setAudience(config.auth.audience)
    .setIssuedAt()
    .setExpirationTime(`${config.auth.accessTtlSeconds}s`)
    .sign(secret);
}

export async function verifyAccessToken(token) {
  try {
    const { payload } = await jwtVerify(token, secret, {
      issuer: config.auth.issuer,
      audience: config.auth.audience,
      algorithms: ['HS256'],
      clockTolerance: 30,
    });
    if (!payload.sub) throw unauthorized();
    return payload;
  } catch (err) {
    if (err instanceof joseErrors.JWTExpired) throw unauthorized('Session expired.', 'TOKEN_EXPIRED');
    throw unauthorized('Invalid session.', 'TOKEN_INVALID');
  }
}
