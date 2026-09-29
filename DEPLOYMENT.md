# BillFixer — Deployment & Setup Guide

Everything needed to go from this repo to a live API at
`https://billfixer.dakshyaminfotech.store` and a working iOS build.

```
repo/
├─ BillFixer/            iOS app (Xcode project root — every file here is compiled into the app)
├─ BillFixerTests/       parser unit tests (+ run-parser-checks.sh, runs without Xcode)
├─ backend/              Node.js API, MySQL schema, nginx, deploy scripts, Python data pipeline
└─ design-exports/       Figma SVG exports and previews (not shipped)
```

---

## 1. On your Mac — push the code

```bash
cd "/Users/minaxi/Desktop/parth demo/BillFixer"
git add -A
git commit -m "BillFixer app, backend and data pipeline"
git push origin main
```

`backend/.gitignore` already keeps `node_modules`, `.env` and logs out of git. **Never commit `backend/.env`.**

---

## 2. DNS (Hostinger hPanel)

Add an **A record**: `billfixer` → your VPS public IPv4 (TTL 300).
Wait until `dig +short billfixer.dakshyaminfotech.store` returns the VPS IP — the TLS certificate step needs it.

---

## 3. On the server — one-time setup (Ubuntu 22.04 / 24.04)

```bash
ssh root@YOUR_VPS_IP
git clone --filter=blob:none --sparse https://github.com/Pgr0708/BillFixer.git /opt/billfixer
cd /opt/billfixer
git sparse-checkout set backend
sudo bash backend/deploy/setup-server.sh you@example.com
```

**Backend only:** `--sparse` + `git sparse-checkout set backend` checks out just `backend/` (Node API + Python
data pipeline). The iOS/Swift code and design files are never downloaded to the server, and every later
`git pull` (including the one inside `deploy.sh`) keeps it that way.

Clone into `/opt/billfixer` (not `/root`): the script hands the repo to a dedicated `billfixer` user, which can't read inside `/root`.
If the repo is private, use a GitHub deploy key or an HTTPS token so `git pull` works for updates.

The script is safe to re-run. It does, in order:

| Step | What happens |
|---|---|
| 1 | apt packages: nginx, MySQL, Redis, certbot, Python 3, build tools |
| 2 | Node.js 22 LTS + PM2 |
| 3 | `billfixer` system user, owns the repo |
| 4 | MySQL database + user, **generates `backend/.env`** with random DB password, JWT secret and webhook secret |
| 5 | Redis bound to localhost (cache + rate limits; the API keeps working if Redis goes down) |
| 6 | UFW firewall: SSH + HTTP/HTTPS only |
| 7 | `npm ci` + creates all tables (`db/schema.sql`) + seeds official 2026 HHS poverty guidelines |
| 8 | PM2 cluster (one worker per CPU), auto-start on boot, log rotation |
| 9 | nginx reverse proxy + Let's Encrypt certificate (auto-renew) |
| 10 | Python data pipeline + systemd timer (daily refresh of official data) |

---

## 4. Add your secrets

```bash
sudo nano /opt/billfixer/backend/.env
```

| Key | Where to get it |
|---|---|
| `OPENAI_API_KEY` | platform.openai.com → API keys |
| `OPENAI_MODEL` | `gpt-4o-mini` (default) or `o4-mini` |
| `LLM_ENABLED` | `true` (with `false`, letters and scripts use the built-in deterministic templates) |
| `REVENUECAT_SECRET_KEY` | RevenueCat → Project → API keys → **Secret** key (`sk_…`) |
| `REVENUECAT_WEBHOOK_AUTH` | already generated — copy it into the RevenueCat webhook (step 5) |
| `SMTP_HOST` `SMTP_PORT` `SMTP_USER` `SMTP_PASSWORD` `SMTP_FROM` | Hostinger email (`smtp.hostinger.com`, 465) — used for password-reset codes |
| `APPLE_BUNDLE_IDS` | `com.bhavik.BillFixer` (already set) |

Apply the new values:

```bash
sudo -u billfixer bash -c "cd /opt/billfixer/backend && pm2 reload ecosystem.config.cjs --update-env"
```

---

## 5. RevenueCat (subscriptions)

1. In App Store Connect, create two auto-renewable subscriptions in one group:
   `com.billfixer.app.premium.monthly` and `com.billfixer.app.premium.annual`.
2. In RevenueCat, add the iOS app (bundle `com.bhavik.BillFixer`) and its App Store Connect shared secret.
3. Create the entitlement **`pro`** and attach both products.
4. Create an offering named `default` (mark it Current) with a **Monthly** and an **Annual** package.
5. Integrations → Webhooks:
   - URL: `https://billfixer.dakshyaminfotech.store/v1/webhooks/revenuecat`
   - Authorization header: the `REVENUECAT_WEBHOOK_AUTH` value from `.env`
6. Copy the **public** Apple SDK key (`appl_…`) into `BillFixer/Consts.swift` → `revenueCatAPIKey`.
   It's designed to ship inside the app. Until it's set, the paywall shows "Subscriptions aren't available in this build yet" instead of crashing.

The app logs RevenueCat in with the BillFixer user id, so webhooks map straight to the account. The server never trusts the app's claim: premium is re-verified with RevenueCat.

---

## 6. Xcode / Apple Developer

1. **Signing & Capabilities** → add **Sign in with Apple** (the entitlement is already in `GoViral.entitlements`), and enable it for `com.bhavik.BillFixer` in the Developer portal.
2. Push Notifications and iCloud are already configured.
3. Fonts and the camera permission text are registered in `Info.plist`.
4. Build and run. Release builds always use the production API.

**Local backend (Debug only):** Edit Scheme → Run → Arguments → Environment Variables → `BF_API_URL` = `http://127.0.0.1:4100/v1`.

---

## 7. Verify

```bash
curl -s https://billfixer.dakshyaminfotech.store/health/live
curl -s https://billfixer.dakshyaminfotech.store/health/ready
sudo -u billfixer pm2 status
sudo -u billfixer pm2 logs billfixer-api --lines 50
systemctl list-timers | grep billfixer
journalctl -u billfixer-pipeline --since today
```

`/health/ready` reports database, Redis and LLM status. A 503 means MySQL is unreachable.

---

## 8. Deploying updates

Push from your Mac, then on the server:

```bash
cd /opt/billfixer
sudo -u billfixer bash backend/deploy/deploy.sh
```

It pulls, installs dependencies, runs tests, applies schema changes, reloads PM2 with zero downtime, and health-checks.

---

## 9. Official data pipeline

Runs daily at 03:17 UTC through a systemd timer. It refreshes:

- HHS poverty guidelines (ASPE API) for the financial-assistance estimator
- the CMS hospital directory (Hospital General Information)
- Medicare Physician Fee Schedule benchmarks
- hospital price-transparency files (MRF) for hospitals you add — copy `mrf_targets.example.json` to `mrf_targets.json`, or run
  `.venv/bin/python -m pipeline.run --add-site <CMS_FACILITY_ID> <HOSPITAL_WEBSITE>`

If a source is unreachable or changes format, the last good data stays in place. Manual run:

```bash
sudo systemctl start billfixer-pipeline
cd /opt/billfixer/backend/data-pipeline && sudo -u billfixer .venv/bin/python -m pipeline.run --source fpl --force
```

---

## 10. Tests

```bash
cd backend && npm test                         # 31 API/engine tests
cd backend/data-pipeline && .venv/bin/python -m unittest discover tests   # pipeline parsers
./BillFixerTests/run-parser-checks.sh          # iOS OCR bill/EOB parsers, no Xcode needed
```

To run the iOS tests inside Xcode: File → New → Target → **Unit Testing Bundle**, name it `BillFixerTests`. The existing folder is picked up automatically.
