const RATE_LIMIT_WINDOW_MS = Number(process.env.RATE_LIMIT_WINDOW_MS || 10 * 60 * 1000);
const RATE_LIMIT_MAX_REQUESTS = Number(process.env.RATE_LIMIT_MAX_REQUESTS || 20);

const requestBuckets = new Map();

const getClientKey = (req) => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.length > 0) {
    return forwardedFor.split(',')[0].trim();
  }

  return req.ip || req.connection?.remoteAddress || 'unknown';
};

const authRateLimit = (req, res, next) => {
  const now = Date.now();
  const key = getClientKey(req);
  const current = requestBuckets.get(key);

  if (!current || now > current.resetAt) {
    requestBuckets.set(key, {
      count: 1,
      resetAt: now + RATE_LIMIT_WINDOW_MS,
    });
    return next();
  }

  current.count += 1;

  if (current.count > RATE_LIMIT_MAX_REQUESTS) {
    const retryAfterSeconds = Math.ceil((current.resetAt - now) / 1000);
    res.set('Retry-After', String(Math.max(retryAfterSeconds, 1)));
    return res.status(429).json({
      error: 'Too many requests. Please try again later.',
    });
  }

  return next();
};

module.exports = {
  authRateLimit,
};
