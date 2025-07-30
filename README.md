# Infraestrutura Web na AWS com Monitoramento Automatizado

Este projeto configura automaticamente uma instância EC2 na AWS com um servidor Nginx, um site estático e um sistema de monitoramento contínuo. O objetivo é garantir alta disponibilidade do servidor web, notificando via webhook quando o serviço estiver fora do ar e tentando restaurá-lo automaticamente.

A infraestrutura inclui:

* Servidor EC2 com Nginx configurado para servir uma página simples;
* Script de monitoramento que verifica constantemente a disponibilidade do servidor e envia alertas para um canal do Discord em caso de falha;
* Reinício automático do serviço Nginx quando o monitoramento detecta falhas;
Automação via User Data que provisiona toda a configuração automaticamente no momento da criação da instância EC2;
* Projeto organizado com uso de Systemd para manter o monitoramento como um serviço persistente;

## Como iniciar o projeto

### Pré-requisitos

* Conta na AWS
* Sistema Linux
* Webhook do Discord

### Configuração de ambiente na AWS

1. **Criar uma instância EC2**

    * Acesse o console da AWS
    * Vá até **EC2 > Instâncias > Executar instância**
    * Escolha a AMI Ubuntu
    * Crie um novo KeyPair do tipo RSA e formato .pem, para se conectar à instância
    * Configure uma **sub-rede pública da VPC padrão** com **IP público habilitado**
    * Substitua o valor da variável `WEBHOOK_URL` pelo URL do seu Webhook do Discord no script `user-data.sh`. No campo **User Data**, insira o conteúdo do script (automatiza a instalação do Nginx, configuração do HTML, script de monitoramento e ativação do systemd)
    * Finalize e inicie a instância

2. **Liberar a portas HTTP e ssh**

    * No grupo de segurança associado à instância, adicione 2 regras:
        * Tipo: `HTTP` ; Origem: `0.0.0.0/0 (Anywhere)`
        * Tipo: `ssh` ; Origem: `Meu IP`

> Para verificar se tudo correu bem, acesse a página que a instância está hospedando através do link `http://IP_PÚBLICO_DA_EC2`, a página deverá conter um "Olá mundo".

### Acessando a instância via ssh

1. Localize e acesse diretório do arquivo .pem que foi baixado ao criar um novo KeyPair durante a configuração de ambiente.

2. Defina a permissão de chave privada através do comando:
    * `chmod 400 sua-chave.pem`

3. E finalmente para acessar sua instância, use o seguinte comando:
    * `ssh -i sua-chave.pem ubuntu@IP_PÚBLICO_DA_EC2`

_Substitua `sua-chave.pem` e `IP_PÚBLICO_DA_EC2` pelos correspondentes no seu caso._

### Testando o projeto

Se você conseguiu ver a página que instância está hospedando, está tudo certo até aqui. Para testar o script de monitoramento persistente, basta derrubar o servidor nginx manualmente:

1. Acesse sua istância via ssh.
2. Execute o comando `sudo systemctl stop nginx`

Se o script estiver funcionando corretamente, após 1 minuto, você receberá alertas no seu servidor do Discord e o servidor estará de pé novamente hospedando a página.

Alertas do Discord:

![Alt](https://imgur.com/gallery/alert-example-2VYn6Zk)

## Como funciona o script de monitoramento

O script `monitor-nginx.sh` realiza as seguintes tarefas:

* Verifica periodicamente (a cada 1 minuto) se o serviço Nginx está ativo
* Caso detecte falha:
  * Envia um alerta para um canal do Discord via Webhook
  * Reinicia automaticamente o serviço Nginx
* O script é gerenciado por um serviço systemd, garantindo que esteja sempre em execução após o boot

> O webhook é configurado diretamente no script. Basta substituir o valor da variável `WEBHOOK_URL`.

Veja a explicação detalhada do funcionamento:

Define, respectivamente, a página a ser monitorada, o caminho do arquivo de log e a URL do Webhook:

~~~bash
URL="http://localhost"
LOG="/var/log/monitoramento.log"
WEBHOOK_URL="COLE_AQUI_O_SEU_WEBHOOK"
~~~

---

Define a função `log_message` que registra mensagens com data e hora no log. Usa `tee -a` para adicionar ao arquivo. `> /dev/null` evita que o tee imprima no terminal.

~~~bash
log_message() {
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[${TIMESTAMP}] $1" | sudo tee -a "$LOG" > /dev/null
}
~~~

---

Executa uma requisição curl silenciosa `-s` e sem saída de corpo `-o /dev/null`. A opção `-w "%{http_code}"` retorna apenas o código HTTP da resposta. A saída é armazenada na variável `HTTP_CODE`.

~~~bash
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
~~~

---

Verifica se o código HTTP é diferente de 200, se for, entra no bloco de recuperação do servidor.

~~~bash
if [ "$HTTP_CODE" -ne 200 ]; then
~~~

---

Registra no log que osite está fora do ar.

~~~bash
log_message "Site fora do ar. Código HTTP: $HTTP_CODE"
~~~

---

Envia um alerta via Discord alertando a falha do servidor.

~~~bash
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\": \"⚠️ O servidor caiu (HTTP $HTTP_CODE). Reiniciando o Nginx...\"}" \
     "$WEBHOOK_URL"
~~~

---

Reinicia o servidor e aguarda 2 segundos antes de fazer outra verificação.

~~~bash
sudo systemctl restart nginx

sleep 2
~~~

---

Verifica se o nginx está ativo e rodando corretamente.

~~~bash
if systemctl is-active --quiet nginx; then
~~~

---

Se estiver tudo bem, envia um alerta confirmando a recuperação do servidor.

~~~bash
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"content": "✅ O servidor Nginx foi reiniciado com sucesso."}' \
     "$WEBHOOK_URL"
exit 0
~~~

---

Se o nginx ainda estiver inativo, envia o alerta de erro e finalizao script com código de erro.

~~~bash
else
  curl -H "Content-Type: application/json" \
       -X POST \
       -d '{"content": "❌ FALHA ao reiniciar o servidor Nginx! Verifique manualmente."}' \
       "$WEBHOOK_URL"
  exit 1
fi
~~~

---

Se o código HTTP for 200, registra no log o funcionamento do servidor.

~~~bash
else
  log_message "Site está no ar. Código HTTP: $HTTP_CODE"
  exit 0
fi
~~~
