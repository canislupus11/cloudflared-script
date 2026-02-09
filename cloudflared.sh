#!/bin/bash
set -e

DOMAIN="$1"
LOCAL_SERVICE="$2"

if [ -z "$DOMAIN" ] || [ -z "$LOCAL_SERVICE" ]; then
  echo "Użycie:"
  echo "  $0 <subdomena> <ip:port>"
  exit 1
fi

CONFIG="/etc/cloudflared/config.yml"

### logowanie jeśli potrzeba
if [ ! -f /root/.cloudflared/cert.pem ]; then
  echo "Brak logowania do Cloudflare"
  cloudflared tunnel login
fi

### pobierz nazwę i UUID tunelu z config.yml
TUNNEL_UUID=$(grep '^tunnel:' "$CONFIG" | awk '{print $2}')

if [ -z "$TUNNEL_UUID" ]; then
  echo "Nie znaleziono tunnel UUID w config.yml"
  exit 1
fi

TUNNEL_NAME=$(cloudflared tunnel list | awk -v uuid="$TUNNEL_UUID" '$1==uuid {print $2}')

if [ -z "$TUNNEL_NAME" ]; then
  echo "Nie znaleziono nazwy tunelu"
  exit 1
fi

### DNS route
cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" || true

### dodaj ingress przed fallbackiem
sed -i "/- service: http_status:404/i\  - hostname: $DOMAIN\n    service: http://$LOCAL_SERVICE" "$CONFIG"

### restart
systemctl restart cloudflared

echo "Dodano:"
echo "  https://$DOMAIN -> http://$LOCAL_SERVICE"
