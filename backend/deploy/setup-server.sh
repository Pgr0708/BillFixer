#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  BillFixer — ONE-TIME server provisioning (Ubuntu 22.04 / 24.04, Hostinger VPS)
#  Run as root from the repo:   sudo bash backend/deploy/setup-server.sh you@example.com
#  Safe to re-run: every step checks before it acts.
#
#  SHARED-SERVER SAFE: if the VPS already hosts other sites (nginx sites, a MySQL/MariaDB,
#  Redis, Node apps, a firewall), this script ADDS BillFixer next to them and never changes
#  their global configuration, never removes their nginx sites, never upgrades their Node,
#  and picks a free local port if 3000 is taken.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

DOMAIN="billfixer.dakshyaminfotech.store"
EMAIL="${1:-}"                                   # for Let's Encrypt expiry notices
APP_USER="billfixer"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"   # repo root (contains backend/)
BACKEND="$REPO_DIR/backend"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo bash $0 <email>"; exit 1; }
[[ -n "$EMAIL" ]] || { echo "Usage: sudo bash $0 you@example.com"; exit 1; }
log()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ⚠ %s\033[0m\n' "$*"; }
port_in_use() { ss -ltnH "sport = :$1" 2>/dev/null | grep -q .; }

# ── What is already on this server? (decides how careful each step must be) ──
HAD_MYSQL=0;  { command -v mysqld >/dev/null || command -v mariadbd >/dev/null; } && HAD_MYSQL=1
HAD_REDIS=0;  command -v redis-server >/dev/null && HAD_REDIS=1
HAD_NODE=0;   command -v node >/dev/null && HAD_NODE=1
HAD_UFW_ON=0; command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active" && HAD_UFW_ON=1

log "1/10  System packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# Install ONLY packages that are missing. `apt-get install` on an installed package would upgrade it and
# restart it (nginx, MySQL, Redis) — never do that on a server that runs other sites.
install_missing() {
  local missing=()
  for p in "$@"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if [[ ${#missing[@]} -gt 0 ]]; then apt-get install -y --no-upgrade "${missing[@]}"; else echo "  all present: $*"; fi
}
install_missing curl git ufw nginx certbot python3 python3-venv python3-pip build-essential ca-certificates gnupg iproute2
if [[ $HAD_MYSQL -eq 0 ]]; then install_missing mysql-server; else echo "  existing MySQL/MariaDB found — using it as is"; fi
if [[ $HAD_REDIS -eq 0 ]]; then install_missing redis-server; else echo "  existing Redis found — using it as is"; fi

log "2/10  Node.js + PM2"
if [[ $HAD_NODE -eq 0 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
elif [[ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]]; then
  warn "Node $(node -v) is installed and other apps may depend on it, so it will NOT be upgraded."
  warn "BillFixer needs Node 20+. Install it for the billfixer user only (does not touch other apps):"
  warn "  sudo -u $APP_USER bash -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && . ~/.nvm/nvm.sh && nvm install 22'"
  warn "Then re-run this script."
  exit 1
fi
command -v pm2 >/dev/null || npm install -g pm2@latest
node -v

log "3/10  App user"
id "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /bin/bash "$APP_USER"
chown -R "$APP_USER:$APP_USER" "$REPO_DIR"

log "4/10  MySQL database"
# Root login: socket auth on a fresh Ubuntu MySQL; on an existing server pass the root password:
#   MYSQL_ROOT_PASSWORD='...' sudo -E bash backend/deploy/setup-server.sh you@example.com
[[ -n "${MYSQL_ROOT_PASSWORD:-}" ]] && export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
if ! mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
  warn "Cannot log in to MySQL as root. Re-run with the root password:"
  warn "  MYSQL_ROOT_PASSWORD='your-root-password' sudo -E bash $0 $EMAIL"
  exit 1
fi
if [[ $HAD_MYSQL -eq 0 ]]; then
  # Fresh MySQL installed by us → tuned config is safe (nothing else uses it).
  cp "$BACKEND/deploy/mysql-billfixer.cnf" /etc/mysql/mysql.conf.d/billfixer.cnf
  systemctl restart mysql
else
  # Shared database server: no global config, no restart. BillFixer sets UTC + strict mode per connection.
  # Never flip server-wide switches here. MySQL 8 has event_scheduler ON by default; if it's OFF, someone chose that.
  [[ "$(mysql -N -e 'SELECT @@event_scheduler')" == "ON" ]] || warn "event_scheduler is OFF: BillFixer's nightly cleanup events won't run (harmless; tables just grow slowly)."
fi
COLLATION="utf8mb4_0900_ai_ci"
mysql -N -e "SELECT VERSION()" | grep -qi mariadb && COLLATION="utf8mb4_unicode_ci"
if [[ ! -f "$BACKEND/.env" ]]; then
  DB_PASS="$(openssl rand -base64 30 | tr -d '/+=' | cut -c1-32)"
  JWT_SECRET="$(openssl rand -base64 64 | tr -d '/+=\n' | cut -c1-64)"
  WEBHOOK_SECRET="$(openssl rand -hex 24)"
  mysql <<SQL
CREATE DATABASE IF NOT EXISTS billfixer CHARACTER SET utf8mb4 COLLATE ${COLLATION};
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

log "5/10  Redis (cache only, localhost, keys prefixed bf:)"
if [[ $HAD_REDIS -eq 0 ]]; then
  grep -q "BillFixer" /etc/redis/redis.conf || { echo "# BillFixer" >> /etc/redis/redis.conf; cat "$BACKEND/deploy/redis-billfixer.conf" >> /etc/redis/redis.conf; }
  systemctl enable --now redis-server
  systemctl restart redis-server
else
  echo "  existing Redis left exactly as configured (BillFixer only reads/writes bf:* keys and works even if Redis is down)"
fi

log "6/10  Firewall"
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
if [[ $HAD_UFW_ON -eq 1 ]]; then
  echo "  firewall already active — added SSH + HTTP/HTTPS rules only"
else
  OTHER_PORTS="$(ss -ltnH | awk '{print $4}' | grep -vE '^(127\.0\.0\.1|\[::1\]|::1)' | sed 's/.*://' | sort -un | grep -vxE '22|80|443' | tr '\n' ' ' || true)"
  if [[ -n "${OTHER_PORTS// }" ]]; then
    warn "Firewall NOT enabled: other public ports are in use (${OTHER_PORTS}) and enabling it could block another app."
    warn "Review, allow what you need (ufw allow <port>), then run: ufw enable"
  else
    ufw --force enable
  fi
fi

log "7/10  Local port for the API"
APP_PORT="$(grep -E '^PORT=' "$BACKEND/.env" | cut -d= -f2)"; APP_PORT="${APP_PORT:-3000}"
if port_in_use "$APP_PORT" && ! sudo -u "$APP_USER" pm2 describe billfixer-api >/dev/null 2>&1; then
  for p in $(seq 3100 3199); do port_in_use "$p" || { APP_PORT="$p"; break; }; done
  sed -i "s|^PORT=.*|PORT=${APP_PORT}|" "$BACKEND/.env"
  echo "  port 3000 is used by another app — BillFixer will listen on ${APP_PORT}"
fi
echo "  API port: ${APP_PORT} (localhost only; nginx proxies to it)"
# Shared server: 2 workers (≈20 MySQL connections, ≈1 GB RAM max) instead of one per CPU core.
if [[ $HAD_MYSQL -eq 1 ]] && ! grep -q '^PM2_INSTANCES=' "$BACKEND/.env"; then
  echo "PM2_INSTANCES=2" >> "$BACKEND/.env"
  echo "  shared server → PM2_INSTANCES=2 (change in .env if you need more)"
fi

log "8/10  Dependencies, database schema, PM2"
sudo -u "$APP_USER" bash -c "cd '$BACKEND' && npm ci --omit=dev && npm run migrate:seed"
sudo -u "$APP_USER" bash -c "cd '$BACKEND' && pm2 startOrReload ecosystem.config.cjs --update-env && pm2 save"
env PATH="$PATH:/usr/bin" pm2 startup systemd -u "$APP_USER" --hp "/home/$APP_USER" >/dev/null
sudo -u "$APP_USER" pm2 install pm2-logrotate >/dev/null 2>&1 || true
sudo -u "$APP_USER" pm2 set pm2-logrotate:max_size 20M >/dev/null
sudo -u "$APP_USER" pm2 set pm2-logrotate:retain 14 >/dev/null

log "9/10  nginx site + TLS certificate (other sites untouched)"
mkdir -p /var/www/certbot
cp "$BACKEND/nginx/billfixer-proxy.conf" /etc/nginx/snippets/billfixer-proxy.conf
# Other sites (including "default") are never modified or removed; BillFixer only answers its own server_name.
if [[ ! -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
  cp "$BACKEND/nginx/billfixer-bootstrap.conf" /etc/nginx/sites-available/billfixer.conf
  ln -sf /etc/nginx/sites-available/billfixer.conf /etc/nginx/sites-enabled/billfixer.conf
  if ! nginx -t; then rm -f /etc/nginx/sites-enabled/billfixer.conf; warn "nginx config test failed — BillFixer site removed again, other sites untouched."; exit 1; fi
  systemctl reload nginx
  # The reload hook is stored in THIS certificate's renewal file only (no global certbot config change).
  certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive \
    --deploy-hook "systemctl reload nginx"
fi
# Build the final file BEFORE enabling it: right port, and the http2 syntax this nginx understands.
TMP_CONF="$(mktemp)"
sed "s|127.0.0.1:3000|127.0.0.1:${APP_PORT}|" "$BACKEND/nginx/billfixer.conf" > "$TMP_CONF"
NGINX_VER="$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [[ "$(printf '%s\n1.25.1\n' "$NGINX_VER" | sort -V | head -1)" != "1.25.1" ]]; then
  # nginx < 1.25.1 (e.g. Ubuntu 22.04's 1.18) doesn't know "http2 on;" — use the older listen syntax.
  sed -i 's/^\s*http2 on;.*$//; s/listen 443 ssl;/listen 443 ssl http2;/; s/listen \[::\]:443 ssl;/listen [::]:443 ssl http2;/' "$TMP_CONF"
fi
install -m 644 "$TMP_CONF" /etc/nginx/sites-available/billfixer.conf && rm -f "$TMP_CONF"
ln -sf /etc/nginx/sites-available/billfixer.conf /etc/nginx/sites-enabled/billfixer.conf
if ! nginx -t; then rm -f /etc/nginx/sites-enabled/billfixer.conf; warn "nginx config test failed — BillFixer site removed again, other sites untouched."; exit 1; fi
systemctl reload nginx   # graceful: existing connections to other sites are not dropped
systemctl is-enabled certbot.timer >/dev/null 2>&1 || warn "certbot.timer is not enabled — make sure 'certbot renew' runs (cron or timer) so HTTPS renews."

log "10/10  Official data pipeline (Python, systemd timer)"
bash "$BACKEND/data-pipeline/install.sh" "$APP_USER"

sleep 3
if curl -fsS "http://127.0.0.1:${APP_PORT}/health/ready" >/dev/null; then
  echo -e "\n\033[1;32m✓ BillFixer API is live at https://$DOMAIN\033[0m"
else
  echo -e "\n\033[1;33m⚠ API not ready yet — check: sudo -u $APP_USER pm2 logs billfixer-api\033[0m"
fi
