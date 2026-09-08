# Mesa — pedidos por QR para estabelecimentos

Rails 7.1 / Ruby 3.3.5 / PostgreSQL / Redis. Aplicação para testes de pedidos à mesa, sem pagamentos online.

## Funcionalidades

- Administrador da plataforma: criar estabelecimentos e gerente inicial; definir limite de mesas, mensalidade acordada (registo manual) e suspender/reabrir o acesso.
- Gerente: produtos, categorias, equipa, criação e desativação de mesas dentro do limite contratado.
- Funcionário: disponibilidade de produtos/categorias, decisões sobre pedidos, serviço, QR existentes e chamadas.
- Cliente: menu por QR, revisão do preço antes do envio, histórico do seu dispositivo, confirmação de alterações, cancelamento antes de aceitação e chamada à mesa.
- Propostas textuais por produto (ex.: «sem queijo») e novo preço exigem confirmação. Não inclui inventário normalizado de ingredientes ou alergénios.
- Um QR por mesa ativa; reimprimir é gratuito em termos de quota. Desativar invalida novos pedidos naquele QR. Reativar reutiliza o código e ocupa uma vaga.
- Eventos em tempo real isolados por estabelecimento e sessão do cliente. Histórico preservado; produtos já usados devem ser desativados.

## Desenvolvimento

Instalar Ruby 3.3.5, PostgreSQL e Bundler 2.7.2. Depois:

```sh
bundle install
bin/rails db:prepare
bin/rails setup:platform_admin
bin/rails server
```

A base nova contém um estabelecimento inicial vazio; pode editá-lo ou criar um novo com gerente pela administração. Numa base existente, a migração associa mesas, categorias e utilizadores ao estabelecimento inicial sem apagar pedidos ou códigos. Contas antigas `admin` tornam-se gerentes desse estabelecimento. Para promover um funcionário existente: `bin/rails setup:manager`.

Não existem passwords predefinidas nos seeds. O administrador é criado interativamente. A mensalidade é apenas informação contratual: não é cobrada pela aplicação.

## Testes

```sh
RAILS_ENV=test bin/rails db:prepare
bin/rails test
bin/rails test:system # requer Chrome/Chromium
bin/rails zeitwerk:check
```

A CI usa PostgreSQL real e testa isolamento, decisões/valores, QR/quota, chamadas, permissões e formulários. Ver [TESTING.md](TESTING.md) para ensaio manual em dispositivos.

## Alojamento de testes na VPS

Ver [deploy/VPS.md](deploy/VPS.md). O Docker Compose publica apenas em `127.0.0.1:3100`; Apache disponibiliza o subdomínio HTTPS. Não publica PostgreSQL nem Redis na Internet.

## Limites desta versão

- Pagamento presencial; sem processamento financeiro ou emissão de faturas.
- QR público identifica a mesa, não prova presença física. Uma fotografia permite abrir o menu à distância enquanto a mesa está ativa; não existe ainda abertura de sessões pelo funcionário ou calendário de funcionamento.
- Chamadas: uma pendente/assumida por mesa, intervalo mínimo de 60 segundos entre novas chamadas. Sem notificações push com o navegador fechado; painel deve permanecer aberto.
- Os pedidos do cliente são associados à sessão do navegador (não a uma conta pessoal). Outro dispositivo ou limpeza de cookies não recupera esse histórico.
- Uma conta de equipa pertence a um estabelecimento. Grupos com várias lojas e utilizadores partilhados não estão incluídos.
- Não existe ainda recuperação automática de palavra-passe por email. Gerentes podem redefinir passwords da equipa; o operador pode gerir contas pela consola.
- Antes de utilização comercial: ensaio real de serviço, recuperação de backups, monitorização, política de retenção de dados e controlo adicional de abuso conforme o tráfego.
