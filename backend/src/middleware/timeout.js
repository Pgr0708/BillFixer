import { unavailable } from '../lib/errors.js';

/** Hard per-request deadline so a stuck dependency can never pin a worker. */
export const timeout = (ms) => (req, res, next) => {
  const timer = setTimeout(() => {
    if (!res.headersSent) next(unavailable('The request took too long. Please try again.', 'TIMEOUT'));
  }, ms);
  const clear = () => clearTimeout(timer);
  res.on('finish', clear);
  res.on('close', clear);
  next();
};
