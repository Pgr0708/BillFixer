#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  BillFixer — deploy an update (after the one-time setup). Zero downtime.
#  Run on the server:   sudo -u billfixer bash backend/deploy/deploy.sh
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
PORT="$(grep -E '^PORT=' backend/.env 2>/dev/null | cut -d= -f2)"

echo "▶ Pulling latest code"
git pull --ff-only

cd backend
echo "▶ Installing dependencies"
npm ci --omit=dev

echo "▶ Running tests"
npm install --no-save --no-audit --no-fund >/dev/null 2>&1 || true
npm test

echo "▶ Applying database schema (idempotent)"
npm run migrate:seed   # schema + reference data (both idempotent)

echo "▶ Reloading API workers one at a time"
pm2 startOrReload ecosystem.config.cjs --update-env
pm2 save

echo "▶ Health check"
for i in {1..15}; do
  if curl -fsS "http://127.0.0.1:${PORT:-3000}/health/ready" >/dev/null; then echo "✓ Deployed and healthy"; exit 0; fi
  sleep 2
done
echo "✗ Health check failed — inspect: pm2 logs billfixer-api --lines 100"
exit 1
