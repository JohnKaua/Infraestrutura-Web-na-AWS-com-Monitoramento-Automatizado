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

![Alt](https://i.imgur.com/v5ub94D.png)

Verifique, também, o arquivo de log.

![Alt](https://i.imgur.com/mpUnHQi.png)

## Como funcionam os scripts

### Script de monitoramento

O script `monitor-nginx.sh` realiza as seguintes tarefas:

* Verifica periodicamente (a cada 1 minuto) se o serviço Nginx está ativo
* Caso detecte falha:
  * Envia um alerta para um canal do Discord via Webhook
  * Reinicia automaticamente o serviço Nginx
* O script é gerenciado por um serviço systemd, garantindo que esteja sempre em execução após o boot

> O webhook é configurado diretamente no script. Basta substituir o valor da variável `WEBHOOK_URL`.

### Script User Data

O script user-data realiza as seguintes tarefas:

* Atualiza e instala pacotes necessários e garante que o Nginx será iniciado automaticamente e já esteja rodando.
* Define o conteúdo da página servida pelo Nginx.
* Cria o script de monitoramento e o torna executável.
* Cria um serviço que executa o script de monitoramento.
* Cria um timer que executa o serviço de monitoramento.
* Recarrega os serviços e timers do `systemd` e ativa imediatamente o timer criado, garantindo que o monitoramento comece a rodar automaticamente.
