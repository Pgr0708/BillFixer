import { ZodError } from 'zod';
import { AppError } from '../lib/errors.js';
import { logger } from '../lib/logger.js';

export function notFoundHandler(req, _res, next) {
  next(new AppError(404, 'ROUTE_NOT_FOUND', `No route for ${req.method} ${req.path}`));
}

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, _next) {
  let error = err;

  if (err instanceof ZodError) {
    error = new AppError(422, 'VALIDATION_ERROR', 'Some fields are invalid.', { fields: err.flatten().fieldErrors });
  } else if (err?.type === 'entity.parse.failed') {
    error = new AppError(400, 'MALFORMED_JSON', 'Request body is not valid JSON.');
  } else if (err?.type === 'entity.too.large') {
    error = new AppError(413, 'PAYLOAD_TOO_LARGE', 'Request body is too large.');
  } else if (err?.code === 'ER_DUP_ENTRY') {
    error = new AppError(409, 'DUPLICATE', 'This record already exists.');
  } else if (err?.code === 'ER_NO_REFERENCED_ROW_2' || err?.code === 'ER_NO_REFERENCED_ROW') {
    error = new AppError(422, 'INVALID_REFERENCE', 'A referenced record does not exist.');
  } else if (['ECONNREFUSED', 'PROTOCOL_CONNECTION_LOST', 'ER_CON_COUNT_ERROR', 'ETIMEDOUT'].includes(err?.code)) {
    error = new AppError(503, 'DATABASE_UNAVAILABLE', 'Service temporarily unavailable. Please try again shortly.');
  } else if (!(err instanceof AppError)) {
    error = new AppError(500, 'INTERNAL_ERROR', 'Something went wrong on our side. Please try again.');
  }

  const log = error.status >= 500 ? logger.error.bind(logger) : logger.warn.bind(logger);
  log(
    { reqId: req.id, code: error.code, status: error.status, path: req.path, method: req.method,
      err: error.status >= 500 ? { message: err?.message, code: err?.code, stack: err?.stack } : undefined },
    'request failed',
  );

  if (res.headersSent) return undefined;
  if (error.status === 429 && error.details?.retryAfterSeconds) res.setHeader('Retry-After', String(error.details.retryAfterSeconds));
  return res.status(error.status).json({
    error: { code: error.code, message: error.message, details: error.details ?? {}, requestId: req.id },
  });
}
