# Testar na VPS com Apache e Docker Compose

Use um subdomínio dedicado (ex.: `mesas.seudominio.pt`). Não substitua a configuração de sites existentes. A porta 3100 deve estar livre. Estes passos destinam-se à VPS quando a versão for aprovada para testes; não foram executados na VPS pelo assistente.

## 1. Preparação

É necessário Docker Engine com Compose v2, Git, Apache 2.4.47+ e certificado HTTPS válido. Crie o registo DNS do subdomínio para o IP da VPS e configure o respetivo VirtualHost/certificado pelo método que já usa. No Cloudflare, use SSL/TLS Full (strict), caso utilize esse proxy.

Faça um backup da base existente antes de migrar. Para uma instalação anterior fora de Docker, use o utilizador/nome corretos no `pg_dump` e importe numa base de testes isolada. A migração de estabelecimentos é irreversível; rollback exige restauro do backup.

## 2. Obter a versão e definir segredos

```sh
git clone --branch codex/multi-establishment-vps https://github.com/JDi4s/qr_table_ordering.git mesa-test
cd mesa-test
cp .env.example .env
chmod 600 .env
openssl rand -hex 64
openssl rand -hex 32
```

Edite `.env` localmente na VPS: coloque o domínio HTTPS em `APP_PUBLIC_URL`, o primeiro valor gerado em `SECRET_KEY_BASE` e o segundo em `POSTGRES_PASSWORD`. Não partilhe esses valores. Use apenas hexadecimal na password neste exemplo, para ser segura dentro do URL da base de dados. Mantenha os segredos entre reinícios; mudar `SECRET_KEY_BASE` invalida sessões e revisões pendentes.

## 3. Construir e arrancar

```sh
docker compose build
docker compose up -d
docker compose logs --tail=100 web
docker compose exec web bin/rails setup:platform_admin
```

A aplicação prepara/migra a base automaticamente no arranque. Não cria utilizadores de demonstração. O último comando pede email e palavra-passe no terminal. O container usa o ambiente de produção, Redis e uma base persistente num volume.

## 4. Apache e HTTPS

Ative módulos necessários se ainda não estiverem ativos:

```sh
sudo a2enmod proxy proxy_http headers ssl
```

Dentro do VirtualHost HTTPS do subdomínio, adapte o conteúdo de `deploy/apache.conf.example`. O domínio e o certificado pertencem ao VirtualHost; este ficheiro contém apenas as diretivas de proxy. Encaminhe HTTP para HTTPS. Valide antes de recarregar:

```sh
sudo apachectl configtest
sudo systemctl reload apache2
```

Não exponha a porta 3100 na firewall: o Apache liga-se à porta local. A política HTTPS e origem WebSocket usam `APP_PUBLIC_URL`. Se o domínio mudar, os QR já impressos continuam a apontar ao antigo endereço: mantenha redirecionamento ou volte a imprimir.

## 5. Ensaio

Abra `https://SEU-SUBDOMINIO/login`. Crie um estabelecimento com gerente e limite de duas mesas. Entre como gerente, crie categoria/produtos/mesas. Descarregue e leia o QR num telemóvel; acompanhe pelo painel noutro dispositivo. Execute o roteiro de `TESTING.md`.

## 6. Atualização e backup

Antes de atualizar:

```sh
mkdir -p backups
chmod 700 backups
docker compose exec -T db pg_dump -U mesa -d mesa -Fc > backups/antes-da-atualizacao.dump
chmod 600 backups/antes-da-atualizacao.dump
git pull --ff-only
docker compose up -d --build
```

O comando `pg_dump` acima substitui o ficheiro com esse nome: use nomes datados para conservar várias versões. Guarde uma cópia fora da VPS e teste o restauro numa base separada. Faça backup também do `.env` num local privado.

Para parar sem apagar dados: `docker compose stop`. Nunca use `docker compose down -v` para uma instalação cujos dados queira conservar. Para voltar a código anterior sem alteração de schema, faça checkout do commit anterior e reconstrua; após migrações incompatíveis, restaure primeiro um backup para uma base isolada e valide.
