#!/bin/bash

# Atualiza o sistema e instala o Nginx
apt update -y && apt upgrade -y
apt install curl -y
apt install nginx -y
systemctl enable nginx
systemctl start nginx

# cria página simples
echo "<h1>Olá mundo!</h1>" > /var/www/html/index.html

# cria o script de monitoramento
cat <<'EOF' > /usr/local/bin/monitor-nginx.sh
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
EOF

chmod +x /usr/local/bin/monitor-nginx.sh

# cria o service systemd
cat <<EOF > /etc/systemd/system/monitor-nginx.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/monitor-nginx.sh
ExecStartPost=/bin/bash -c 'if [ $? -ne 0 ]; then echo "$(date "+%Y-%m-%d %H:%M:%S") [monitor] Reiniciando Nginx" | tee -a /var/log/monitoramento.log; systemctl restart nginx; fi'
EOF

# cria o timer
cat <<EOF > /etc/systemd/system/monitor-nginx.timer
[Unit]
Description=Verifica o status do Nginx periodicamente

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=monitor-nginx.service

[Install]
WantedBy=timers.target
EOF

# ativa e inicia o timer
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now monitor-nginx.timer