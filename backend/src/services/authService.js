import bcrypt from 'bcryptjs';
import { randomInt, timingSafeEqual } from 'node:crypto';
import { config } from '../config/index.js';
import { signAccessToken } from '../lib/jwt.js';
import { verifyAppleIdentityToken } from '../lib/apple.js';
import { randomToken, sha256, uuid } from '../lib/ids.js';
import { conflict, unauthorized, unavailable, tooManyRequests, badRequest, unprocessable } from '../lib/errors.js';
import { mailEnabled, sendMail } from '../lib/mailer.js';
import { logger } from '../lib/logger.js';
import { mapUser } from '../repositories/mappers.js';
import * as users from '../repositories/userRepo.js';
import * as tokens from '../repositories/tokenRepo.js';

const BCRYPT_COST = 12;
// Compared against when the email is unknown so response time doesn't reveal which emails exist.
const DUMMY_HASH = bcrypt.hashSync('timing-equaliser-not-a-real-password', BCRYPT_COST);

const refreshExpiry = () => new Date(Date.now() + config.auth.refreshTtlDays * 86_400_000);

async function issueSession(user, userAgent, familyId = uuid()) {
  const refreshToken = randomToken();
  await tokens.insertRefreshToken({ userId: user.id, tokenHash: sha256(refreshToken), familyId, expiresAt: refreshExpiry(), userAgent });
  users.touchActive(user.id).catch(() => {});
  return {
    accessToken: await signAccessToken(user.id),
    refreshToken,
    expiresIn: config.auth.accessTtlSeconds,
    user: mapUser(user),
  };
}

export async function signInWithApple({ identityToken, nonce, displayName, userAgent }) {
  const apple = await verifyAppleIdentityToken(identityToken, nonce);
  let user = await users.findByAppleSub(apple.sub);
  if (!user && apple.email && apple.emailVerified) {
    const existing = await users.findByEmail(apple.email);
    if (existing) {
      await users.linkAppleSub(existing.id, apple.sub); // same verified email → same account
      user = await users.findById(existing.id);
    }
  }
  if (!user) {
    try {
      user = await users.createAppleUser({ appleSub: apple.sub, email: apple.email, emailVerified: apple.emailVerified, displayName: displayName || null });
    } catch (err) {
      if (err.code !== 'ER_DUP_ENTRY') throw err;
      user = await users.findByAppleSub(apple.sub); // concurrent first sign-in from two devices
    }
  } else if (displayName && !user.display_name) {
    await users.updateDisplayName(user.id, displayName); // Apple only sends the name on the very first sign-in
    user = await users.findById(user.id);
  }
  return issueSession(user, userAgent);
}

export async function register({ email, password, displayName, userAgent }) {
  if (await users.findByEmail(email)) throw conflict('An account with this email already exists. Try signing in.', 'EMAIL_IN_USE');
  const passwordHash = await bcrypt.hash(password, BCRYPT_COST);
  try {
    const user = await users.createEmailUser({ email, passwordHash, displayName: displayName || null });
    return issueSession(user, userAgent);
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') throw conflict('An account with this email already exists. Try signing in.', 'EMAIL_IN_USE');
    throw err;
  }
}

export async function login({ email, password, userAgent }) {
  const user = await users.findByEmail(email);
  const hash = user ? await users.getPasswordHash(user.id) : null;
  const ok = await bcrypt.compare(password, hash ?? DUMMY_HASH);
  if (!user || !hash || !ok) {
    if (user && !hash) throw unauthorized('This account uses Sign in with Apple. Please continue with Apple.', 'USE_APPLE_SIGN_IN');
    throw unauthorized('Email or password is incorrect.', 'INVALID_CREDENTIALS');
  }
  return issueSession(user, userAgent);
}

export async function refresh({ refreshToken, userAgent }) {
  const next = randomToken();
  const result = await tokens.consumeRefreshToken(sha256(refreshToken), { tokenHash: sha256(next), expiresAt: refreshExpiry(), userAgent });
  if (result.status === 'reused') {
    logger.warn({ userId: result.userId }, 'refresh token reuse detected — session family revoked');
    throw unauthorized('Your session was ended for your security. Please sign in again.', 'SESSION_REVOKED');
  }
  if (result.status !== 'ok') throw unauthorized('Your session has expired. Please sign in again.', 'SESSION_EXPIRED');
  return { accessToken: await signAccessToken(result.userId), refreshToken: next, expiresIn: config.auth.accessTtlSeconds };
}

export const logout = ({ refreshToken }) => tokens.revokeByHash(sha256(refreshToken));

const codeHash = (userId, code) => sha256(`${userId}:${code}`);

export async function requestPasswordReset({ email }) {
  if (!mailEnabled()) throw unavailable('Password reset is temporarily unavailable. Please contact support.', 'RESET_UNAVAILABLE');
  const user = await users.findByEmail(email);
  // Same response whether or not the account exists — no email enumeration.
  if (!user || !(await users.getPasswordHash(user.id))) return;
  if ((await tokens.recentResetCount(user.id)) >= 3) return;
  const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
  await tokens.insertResetCode({ userId: user.id, codeHash: codeHash(user.id, code), expiresAt: new Date(Date.now() + 15 * 60_000) });
  await sendMail({
    to: email,
    subject: 'Your Bill Fixer reset code',
    text: `Your Bill Fixer password reset code is ${code}.\n\nIt expires in 15 minutes. If you didn’t ask for this, you can ignore this email.`,
  });
}

export async function resetPassword({ email, code, newPassword, userAgent }) {
  const user = await users.findByEmail(email);
  const record = user ? await tokens.latestResetCode(user.id) : null;
  if (!user || !record) throw badRequest('That code is invalid or has expired. Request a new one.');
  if (record.attempts >= 5) throw tooManyRequests(900);
  const a = Buffer.from(codeHash(user.id, code));
  const b = Buffer.from(record.code_hash);
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    await tokens.bumpResetAttempts(record.id);
    throw badRequest('That code is invalid or has expired. Request a new one.');
  }
  await users.setPasswordHash(user.id, await bcrypt.hash(newPassword, BCRYPT_COST));
  await tokens.markResetUsed(record.id);
  await tokens.revokeAllForUser(user.id); // sign out every other device
  return issueSession(user, userAgent);
}

/**
 * Email change. Password accounts must re-enter their password, so a stolen access token alone
 * can't redirect password-reset mail. Apple-only accounts have no password; Apple remains their login.
 */
export async function changeEmail({ userId, email, currentPassword }) {
  const hash = await users.getPasswordHash(userId);
  if (hash) {
    // 422 field errors (not 401): a 401 on an authenticated call means "session expired" to the app.
    if (!currentPassword) throw unprocessable({ fields: { currentPassword: ['Enter your current password to change your email.'] } });
    if (!(await bcrypt.compare(currentPassword, hash))) throw unprocessable({ fields: { currentPassword: ['Current password is incorrect.'] } });
  }
  const existing = await users.findByEmail(email);
  if (existing && existing.id !== userId) throw conflict('That email is already used by another account.', 'EMAIL_TAKEN');
  try {
    await users.updateEmail(userId, email);
  } catch (err) {
    if (err?.code === 'ER_DUP_ENTRY') throw conflict('That email is already used by another account.', 'EMAIL_TAKEN');
    throw err;
  }
  return mapUser(await users.findById(userId));
}
