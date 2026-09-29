import { createRemoteJWKSet, jwtVerify } from 'jose';
import { config } from '../config/index.js';
import { sha256 } from './ids.js';
import { unauthorized } from './errors.js';

// Apple rotates keys; jose caches the JWKS and refetches on unknown `kid` (with cooldown).
const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'), {
  cacheMaxAge: 24 * 60 * 60 * 1000,
  cooldownDuration: 30_000,
  timeoutDuration: 5_000,
});

/**
 * Verify a Sign in with Apple identity token.
 * If the client passed the raw nonce, Apple's `nonce` claim must equal SHA-256(rawNonce).
 */
export async function verifyAppleIdentityToken(identityToken, rawNonce) {
  let payload;
  try {
    ({ payload } = await jwtVerify(identityToken, APPLE_JWKS, {
      issuer: 'https://appleid.apple.com',
      audience: config.auth.appleBundleIds,
      algorithms: ['RS256'],
      clockTolerance: 60,
    }));
  } catch {
    throw unauthorized('Apple sign-in could not be verified. Please try again.', 'APPLE_TOKEN_INVALID');
  }
  if (rawNonce && payload.nonce !== sha256(rawNonce)) {
    throw unauthorized('Apple sign-in could not be verified. Please try again.', 'APPLE_NONCE_MISMATCH');
  }
  return {
    sub: String(payload.sub),
    email: typeof payload.email === 'string' ? payload.email.toLowerCase() : null,
    emailVerified: payload.email_verified === true || payload.email_verified === 'true',
  };
}
