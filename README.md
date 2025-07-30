# Infraestrutura Web na AWS com Monitoramento Automatizado

Este projeto configura automaticamente uma instância EC2 na AWS com um servidor Nginx, um site estático e um sistema de monitoramento contínuo. O objetivo é garantir alta disponibilidade do servidor web, notificando via webhook quando o serviço estiver fora do ar e tentando restaurá-lo automaticamente.

A infraestrutura inclui:

* Servidor EC2 com Nginx configurado para servir um site HTML;
* Script de monitoramento que verifica constantemente a disponibilidade do servidor e envia alertas para um canal do Discord em caso de falha;
* Reinício automático do serviço Nginx quando o monitoramento detecta falhas;
Automação via User Data que provisiona toda a configuração automaticamente no momento da criação da instância EC2;
* Projeto organizado com uso de Systemd para manter o monitoramento como um serviço persistente;
* Estrutura em uma VPC com sub-redes públicas e privadas, garantindo maior controle de rede e segurança.

## Como iniciar o projeto

### Configuração de ambiente na AWS

1. **Criar uma instância EC2**

    - Acesse o [console da AWS](https://console.aws.amazon.com/)
    - Vá até **EC2 > Instâncias > Iniciar instância**
    - Escolha a AMI Ubuntu
    - Tipo de instância: `t2.micro`
    - Crie um novo KeyPair do tipo RSA e formato .pem, para se conectar à instância
    - Configure uma **sub-rede pública da VPC padrão** com **IP público habilitado**
    - Substitua o valor da variável `WEBHOOK_URL` pelo URL do seu Webhook do Discord no script `user-data.sh`. No campo **User Data**, insira o conteúdo do script (automatiza a instalação do Nginx, configuração do HTML, script de monitoramento e ativação do systemd)
    - Finalize e inicie a instância

2. **Liberar a portas HTTP e ssh**

    - No grupo de segurança associado à instância, adicione 2 regras:
        - Tipo: `HTTP` ; Origem: `0.0.0.0/0 (Anywhere)` 
        - Tipo: `ssh` ; Origem: `Meu IP`

## Como funciona o script de monitoramento

O script `monitor-nginx.sh` realiza as seguintes tarefas:

- Verifica periodicamente (a cada 1 minuto) se o serviço Nginx está ativo
- Caso detecte falha:
  - Envia um alerta para um canal do Discord via Webhook
  - Reinicia automaticamente o serviço Nginx
- O script é gerenciado por um serviço `systemd`, garantindo que esteja sempre em execução após o boot

> O webhook é configurado diretamente no script. Basta substituir o valor da variável `WEBHOOK_URL`.

Veja a explicação detalhada do funcionamento:

