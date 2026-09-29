#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  BillFixer — ONE-TIME server provisioning (Ubuntu 22.04 / 24.04, Hostinger VPS)
#  Run as root from the repo:   sudo bash backend/deploy/setup-server.sh you@example.com
#  Safe to re-run: every step checks before it acts.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

DOMAIN="billfixer.dakshyaminfotech.store"
EMAIL="${1:-}"                                   # for Let's Encrypt expiry notices
APP_USER="billfixer"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"   # repo root (contains backend/)
BACKEND="$REPO_DIR/backend"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0 <email>"; exit 1; }
[[ -n "$EMAIL" ]] || { echo "Usage: sudo bash $0 you@example.com"; exit 1; }
log() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }

log "1/10  System packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl git ufw nginx mysql-server redis-server certbot python3 python3-venv python3-pip build-essential ca-certificates gnupg

log "2/10  Node.js 22 LTS + PM2"
if ! command -v node >/dev/null || [[ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
npm install -g pm2@latest
node -v

log "3/10  App user"
id "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /bin/bash "$APP_USER"
chown -R "$APP_USER:$APP_USER" "$REPO_DIR"

log "4/10  MySQL"
cp "$BACKEND/deploy/mysql-billfixer.cnf" /etc/mysql/mysql.conf.d/billfixer.cnf
systemctl restart mysql
if [[ ! -f "$BACKEND/.env" ]]; then
  DB_PASS="$(openssl rand -base64 30 | tr -d '/+=' | cut -c1-32)"
  JWT_SECRET="$(openssl rand -base64 64 | tr -d '/+=\n' | cut -c1-64)"
  WEBHOOK_SECRET="$(openssl rand -hex 24)"
  mysql <<SQL
CREATE DATABASE IF NOT EXISTS billfixer CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'billfixer'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER 'billfixer'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES, EVENT, CREATE TEMPORARY TABLES ON billfixer.* TO 'billfixer'@'localhost';
FLUSH PRIVILEGES;
SQL
  cp "$BACKEND/.env.example" "$BACKEND/.env"
  sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|; s|^JWT_ACCESS_SECRET=.*|JWT_ACCESS_SECRET=${JWT_SECRET}|; s|^REVENUECAT_WEBHOOK_AUTH=.*|REVENUECAT_WEBHOOK_AUTH=${WEBHOOK_SECRET}|" "$BACKEND/.env"
  chown "$APP_USER:$APP_USER" "$BACKEND/.env"; chmod 600 "$BACKEND/.env"
  echo "  ✓ Created $BACKEND/.env with generated DB password, JWT secret and webhook secret."
  echo "  ⚠ Still add OPENAI_API_KEY, REVENUECAT_SECRET_KEY and SMTP_* to $BACKEND/.env"
else
  echo "  .env already exists — leaving it untouched."
fi

log "5/10  Redis (cache only, localhost)"
grep -q "BillFixer" /etc/redis/redis.conf || { echo "# BillFixer" >> /etc/redis/redis.conf; cat "$BACKEND/deploy/redis-billfixer.conf" >> /etc/redis/redis.conf; }
systemctl enable --now redis-server
systemctl restart redis-server

log "6/10  Firewall"
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

log "7/10  Dependencies + database schema"
sudo -u "$APP_USER" bash -c "cd '$BACKEND' && npm ci --omit=dev && npm run migrate:seed"

log "8/10  PM2 (cluster, auto-start on boot, log rotation)"
sudo -u "$APP_USER" bash -c "cd '$BACKEND' && pm2 startOrReload ecosystem.config.cjs --update-env && pm2 save"
env PATH="$PATH:/usr/bin" pm2 startup systemd -u "$APP_USER" --hp "/home/$APP_USER" >/dev/null
sudo -u "$APP_USER" pm2 install pm2-logrotate >/dev/null 2>&1 || true
sudo -u "$APP_USER" pm2 set pm2-logrotate:max_size 20M >/dev/null
sudo -u "$APP_USER" pm2 set pm2-logrotate:retain 14 >/dev/null

log "9/10  nginx + TLS certificate"
mkdir -p /var/www/certbot
cp "$BACKEND/nginx/billfixer-proxy.conf" /etc/nginx/snippets/billfixer-proxy.conf
rm -f /etc/nginx/sites-enabled/default
if [[ ! -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
  cp "$BACKEND/nginx/billfixer-bootstrap.conf" /etc/nginx/sites-available/billfixer.conf
  ln -sf /etc/nginx/sites-available/billfixer.conf /etc/nginx/sites-enabled/billfixer.conf
  nginx -t && systemctl reload nginx
  certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive
fi
cp "$BACKEND/nginx/billfixer.conf" /etc/nginx/sites-available/billfixer.conf
ln -sf /etc/nginx/sites-available/billfixer.conf /etc/nginx/sites-enabled/billfixer.conf
if ! nginx -t 2>/dev/null; then
  # nginx < 1.25.1 doesn't know "http2 on;" — fall back to the older syntax.
  sed -i 's/^\s*http2 on;.*$//; s/listen 443 ssl;/listen 443 ssl http2;/; s/listen \[::\]:443 ssl;/listen [::]:443 ssl http2;/' /etc/nginx/sites-available/billfixer.conf
fi
nginx -t && systemctl reload nginx
systemctl enable --now certbot.timer 2>/dev/null || true
echo 'deploy-hook = systemctl reload nginx' >> /etc/letsencrypt/cli.ini 2>/dev/null || true

log "10/10  Official data pipeline (Python, systemd timer)"
bash "$BACKEND/data-pipeline/install.sh" "$APP_USER"

sleep 3
if curl -fsS "http://127.0.0.1:3000/health/ready" >/dev/null; then
  echo -e "\n\033[1;32m✓ BillFixer API is live at https://$DOMAIN\033[0m"
else
  echo -e "\n\033[1;33m⚠ API not ready yet — check: sudo -u $APP_USER pm2 logs billfixer-api\033[0m"
fi
