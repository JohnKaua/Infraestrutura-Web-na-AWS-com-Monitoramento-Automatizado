#!/bin/bash

URL="http://localhost"
LOG="/var/log/monitoramento.log"
WEBHOOK_URL="COLE_AQUI_O_SEU_WEBHOOK"

log_message() {
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[${TIMESTAMP}] $1" | sudo tee -a "$LOG" > /dev/null
}

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$HTTP_CODE" -ne 200 ]; then
  log_message "Site fora do ar. Código HTTP: $HTTP_CODE"

  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"⚠️ O servidor caiu (HTTP $HTTP_CODE). Reiniciando o Nginx...\"}" \
       "$WEBHOOK_URL"

  sudo systemctl restart nginx

  sleep 2

  if systemctl is-active --quiet nginx; then
      curl -H "Content-Type: application/json" \
           -X POST \
           -d '{"content": "✅ O servidor Nginx foi reiniciado com sucesso."}' \
           "$WEBHOOK_URL"
           exit 0
  else
      curl -H "Content-Type: application/json" \
           -X POST \
           -d '{"content": "❌ FALHA ao reiniciar o servidor Nginx! Verifique manualmente."}' \
           "$WEBHOOK_URL"
           exit 1
  fi

else
  log_message "Site está no ar. Código HTTP: $HTTP_CODE"
  exit 0
fi