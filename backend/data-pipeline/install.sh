#!/usr/bin/env bash
# One-time install of the data pipeline. After this it runs itself daily via systemd.
#   sudo bash backend/data-pipeline/install.sh [app-user]
set -euo pipefail
APP_USER="${1:-billfixer}"
DIR="$(cd "$(dirname "$0")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

echo "▶ Python virtualenv"
python3 -m venv "$DIR/.venv"
"$DIR/.venv/bin/pip" install --upgrade pip >/dev/null
"$DIR/.venv/bin/pip" install -r "$DIR/requirements.txt"
mkdir -p "$DIR/downloads"
chown -R "$APP_USER:$APP_USER" "$DIR"

echo "▶ Unit tests"
sudo -u "$APP_USER" "$DIR/.venv/bin/python" -m unittest discover -s "$DIR/tests" -t "$DIR" -q

echo "▶ systemd timer"
for unit in billfixer-pipeline.service billfixer-pipeline.timer; do
  sed "s|@DIR@|$DIR|g; s|@USER@|$APP_USER|g" "$DIR/systemd/$unit" > "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable --now billfixer-pipeline.timer

echo "▶ First run (in the background — follow with: journalctl -u billfixer-pipeline -f)"
systemctl start --no-block billfixer-pipeline.service
systemctl list-timers billfixer-pipeline.timer --no-pager
