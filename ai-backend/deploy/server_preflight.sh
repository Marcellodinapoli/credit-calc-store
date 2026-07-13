#!/usr/bin/env bash
# Preflight sul server ai.creditcore.it — eseguire via SSH prima del deploy Realtime.
# Uso: bash deploy/server_preflight.sh

set -euo pipefail

echo "=== Preflight ai.creditcore.it Realtime proxy ==="
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo "Data: $(date -Is)"
echo

echo "--- 1. PM2 (se presente) ---"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list || true
else
  echo "pm2 non installato o non in PATH"
fi
echo

echo "--- 2. Nginx ---"
if command -v systemctl >/dev/null 2>&1; then
  systemctl is-active nginx 2>/dev/null || echo "nginx: stato non disponibile"
  systemctl status nginx --no-pager -l 2>/dev/null | head -20 || true
else
  echo "systemctl non disponibile"
fi
echo

echo "--- 3. Porte 3000 / 3002 ---"
if command -v ss >/dev/null 2>&1; then
  ss -tulpn | grep -E ':3000|:3002' || echo "porte 3000/3002 libere (nessun listener)"
elif command -v netstat >/dev/null 2>&1; then
  netstat -tulpn 2>/dev/null | grep -E ':3000|:3002' || echo "porte 3000/3002 libere"
else
  echo "ss/netstat non disponibili"
fi
echo

echo "--- 4. Directory applicative comuni ---"
for dir in /opt/creditcore /var/www /srv /home/*/ai-backend; do
  if [ -d "$dir" ]; then
    echo "TROVATA: $dir"
    ls -la "$dir" 2>/dev/null | head -10 || true
  fi
done
echo

echo "--- 5. Config Nginx ai.creditcore.it ---"
NGINX_CONF=""
for candidate in \
  /etc/nginx/sites-enabled/ai.creditcore.it \
  /etc/nginx/sites-enabled/default \
  /etc/nginx/conf.d/ai.creditcore.it.conf; do
  if [ -f "$candidate" ]; then
    NGINX_CONF="$candidate"
    break
  fi
done

if [ -n "$NGINX_CONF" ]; then
  echo "File: $NGINX_CONF"
  grep -nE 'server_name|call-analysis|normative-search|realtime-ws|proxy_pass|Upgrade|upgrade' \
    "$NGINX_CONF" || echo "(nessuna direttiva rilevante trovata)"
else
  echo "Config Nginx dedicata non trovata — cercare manualmente:"
  echo "  grep -r ai.creditcore.it /etc/nginx/ 2>/dev/null"
fi
echo

echo "--- 6. Health endpoint (se raggiungibile in locale) ---"
if command -v curl >/dev/null 2>&1; then
  curl -fsS --max-time 5 http://127.0.0.1:3000/health 2>/dev/null && echo || \
    echo "http://127.0.0.1:3000/health non risponde (normale se proxy non ancora deployato)"
  curl -fsS --max-time 5 https://ai.creditcore.it/health 2>/dev/null && echo || \
    echo "https://ai.creditcore.it/health non raggiungibile da questo host"
else
  echo "curl non disponibile"
fi
echo

echo "=== Fine preflight ==="
echo "Prossimi passi se porte libere:"
echo "  1. copiare ai-backend/ in /opt/creditcore/ai-backend"
echo "  2. configurare .env"
echo "  3. npm ci --omit=dev && pm2 start ecosystem.config.cjs"
echo "  4. aggiungere deploy/nginx-ai-creditcore.conf e reload nginx"
echo "  5. npm run smoke -- https://ai.creditcore.it wss://ai.creditcore.it/realtime-ws"
