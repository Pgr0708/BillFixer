import { unprocessable } from '../lib/errors.js';

/**
 * Validate and *replace* req.body / req.params / req.query with the parsed (typed, stripped) result.
 * Express 5 makes req.query a getter, so parsed query lives on req.validQuery.
 */
export const validate = ({ body, params, query }) => (req, _res, next) => {
  const errors = {};
  const run = (schema, value, label) => {
    if (!schema) return value;
    const result = schema.safeParse(value ?? {});
    if (!result.success) {
      for (const issue of result.error.issues) {
        const path = [label, ...issue.path].join('.');
        (errors[path] ??= []).push(issue.message);
      }
      return undefined;
    }
    return result.data;
  };
  const parsedParams = run(params, req.params, 'params');
  const parsedQuery = run(query, req.query, 'query');
  const parsedBody = run(body, req.body, 'body');
  if (Object.keys(errors).length) return next(unprocessable({ fields: errors }));
  if (params) req.params = parsedParams;
  if (query) req.validQuery = parsedQuery;
  if (body) req.body = parsedBody;
  return next();
};
