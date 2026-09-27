# BillFixer — Infrastructure

> DELETE BEFORE SUBMISSION

---

## Hosting

| Service | Provider | Purpose |
|---|---|---|
| VPS | Hostinger | Node.js API, Redis, MySQL |
| Object Storage | Cloudflare R2 | Document storage |
| CDN | Cloudflare | Static assets |
| DNS | Cloudflare | billfixer.app domain |

---

## Backend Stack

```
Node.js 20 LTS
Express 4.x
MySQL 8.0 (primary DB)
Redis 7 (job queue + caching)
Bull (job queue management)
Knex.js (SQL query builder)
Zod (request validation)
JWT (auth tokens, RS256)
node-cron (scheduled jobs)
```

---

## Environment Variables (never in source code)

### Required for Production

```bash
# Database
DB_HOST=
DB_PORT=3306
DB_NAME=billfixer
DB_USER=
DB_PASSWORD=

# Redis
REDIS_URL=redis://...

# JWT
JWT_PRIVATE_KEY=      # RS256 private key (PEM)
JWT_PUBLIC_KEY=       # RS256 public key (PEM)
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=30d

# Cloudflare R2
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=billfixer-docs
R2_PUBLIC_URL=        # for presigned URL generation

# LLM APIs
OPENAI_API_KEY=
ANTHROPIC_API_KEY=    # fallback
LLM_PRIMARY=openai    # openai | anthropic

# App Store
APP_STORE_SHARED_SECRET=     # for receipt validation
APP_STORE_SERVER_NOTIFICATION_SECRET=

# Apple Sign In
APPLE_TEAM_ID=
APPLE_CLIENT_ID=
APPLE_KEY_ID=
APPLE_PRIVATE_KEY=    # .p8 content

# Environment
NODE_ENV=production
API_BASE_URL=https://api.billfixer.app
CORS_ALLOWED_ORIGINS=billfixer.app
```

---

## Cloudflare R2 Storage Structure

```
billfixer-docs/
└── users/
    └── {userId}/
        └── cases/
            └── {caseId}/
                └── documents/
                    └── {documentId}/
                        ├── page_1.jpg
                        ├── page_2.jpg
                        └── page_3.jpg
```

Access:
- Presigned GET URLs (1 hour TTL) — user downloads
- Presigned PUT URLs (15 min TTL) — iOS direct upload
- Server has full R2 access for deletion

---

## Background Job Queues (Bull + Redis)

```
Queue: ocr-jobs
  Job types: process-document
  Concurrency: 5
  Timeout: 30s

Queue: analysis-jobs
  Job types: analyze-case
  Concurrency: 3
  Timeout: 120s

Queue: generation-jobs
  Job types: generate-letter, generate-script
  Concurrency: 5
  Timeout: 60s

Queue: cleanup-jobs
  Job types: delete-expired-documents, purge-old-analytics
  Schedule: cron (daily 2:00 AM UTC)
  Concurrency: 1

Queue: notification-jobs
  Job types: send-deadline-notification
  Schedule: cron (daily 10:00 AM user-local — batch by timezone)
  Concurrency: 2

Queue: mrf-jobs
  Job types: fetch-hospital-mrf
  Schedule: cron (monthly 1st, 1:00 AM UTC)
  Concurrency: 1
```

---

## Monitoring

| Tool | Purpose |
|---|---|
| Uptime Robot / Betterstack | Uptime monitoring (API ping every 1 min) |
| Sentry | Error tracking (Node.js + iOS) |
| Prometheus + Grafana (future) | Metrics dashboard |
| MySQL slow query log | DB performance monitoring |
| Redis Monitor | Queue health |

Alerts:
- API down > 1 min → PagerDuty / email
- Error rate > 5% in 5 min window → alert
- Queue backlog > 100 jobs → alert
- Disk > 80% → alert

---

## Deployment

Simple initial deployment (scale later):

```
Hostinger VPS (Ubuntu 22.04)
  └── PM2 (process manager)
        ├── api-server (Express app, 2 workers)
        ├── bull-worker (job processor, 1 worker)
        └── cron-worker (scheduled jobs, 1 worker)

MySQL: managed on same VPS initially
Redis: managed on same VPS initially
```

CI/CD (future):
- GitHub Actions → build → test → SSH deploy to VPS
- Zero-downtime: PM2 reload

---

## iOS Environment Configuration

```swift
// Use different API base URLs per build configuration
enum APIEnvironment {
    case debug    // http://localhost:3000
    case staging  // https://api-staging.billfixer.app
    case production // https://api.billfixer.app
}
```

Store environment in `Config.xcconfig` files per scheme. Never in source code.
