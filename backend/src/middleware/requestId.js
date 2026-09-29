import { randomUUID } from 'node:crypto';

const VALID = /^[A-Za-z0-9._-]{8,128}$/;

export function requestId(req, res, next) {
  const incoming = req.get('x-request-id');
  req.id = incoming && VALID.test(incoming) ? incoming : randomUUID();
  res.setHeader('X-Request-Id', req.id);
  next();
}
