/** Application error carrying an HTTP status and a stable machine-readable code. */
export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
    this.expose = status < 500;
  }
}

export const badRequest = (message = 'Invalid request.', details) => new AppError(400, 'BAD_REQUEST', message, details);
export const unauthorized = (message = 'Please sign in again.', code = 'UNAUTHORIZED') => new AppError(401, code, message);
export const paymentRequired = (feature = 'this feature') =>
  new AppError(402, 'PREMIUM_REQUIRED', `Premium is required for ${feature}.`, { feature });
export const forbidden = (message = 'You do not have access to this resource.') => new AppError(403, 'FORBIDDEN', message);
export const notFound = (what = 'Resource') => new AppError(404, 'NOT_FOUND', `${what} not found.`);
export const conflict = (message = 'This request conflicts with existing data.', code = 'CONFLICT') =>
  new AppError(409, code, message);
export const unprocessable = (details, message = 'Some fields are invalid.') =>
  new AppError(422, 'VALIDATION_ERROR', message, details);
export const tooManyRequests = (retryAfterSeconds) =>
  new AppError(429, 'RATE_LIMITED', 'Too many requests. Please wait a moment and try again.', { retryAfterSeconds });
export const unavailable = (message = 'Service temporarily unavailable. Please try again shortly.', code = 'UNAVAILABLE') =>
  new AppError(503, code, message);
