# Menus por horário e organização do serviço

## Configuração do gerente

1. Em Menu → Classificar produtos, selecionar os produtos por classificar e definir o tipo. Esta entrada só aparece quando há produtos por classificar. Na criação e edição, o tipo é obrigatório. A preparação é opcional e só aparece com a divisão ativa; a presença no menu normal é definida na edição individual. Nenhuma classificação por nome é aplicada automaticamente.
2. Em Menu → Pequeno-almoço ou Menu de almoço, definir dias, horário de Lisboa, produtos avulso, preços e grupos do menu completo. Os produtos ocultos no menu normal continuam disponíveis nestes menus. A disponibilidade do produto e da categoria é respeitada em todos.
3. Em Definições → Organização do serviço, ativar a divisão. Criam-se Balcão e Cozinha quando não existem. É possível criar outros postos, incluindo cozinha de snacks e vários balcões.
4. Criar zonas e escolher os postos de destino de balcão, cozinha e snacks. Atribuir a zona a uma mesa ou a um intervalo de mesas.
5. Em Definições → Equipa, atribuir a função Preparação e pelo menos um posto ao funcionário. Uma conta de preparação tem acesso apenas ao seu painel e preferências pessoais. As contas existentes continuam como sala/atendimento.

## Fluxo

O cliente mantém um único pedido. A sala aceita o conjunto; só depois se criam tarefas por produto ou componente do menu completo. A zona encaminha para o posto correto. Sem zona, usa-se a área explícita do produto ou um posto geral da mesma preparação. Sem destino, a sala vê uma tarefa «Sem posto», que nunca é descartada.

Cada posto marca a sua parte Pronta; a sala marca Entregue. O pedido só fica Servido quando todas as tarefas são entregues. É possível usar Marcar servido no pedido depois de todas as partes estarem prontas. Preços e pagamentos permanecem no pedido original; componentes não criam vendas duplicadas.

O destino fica registado na aceitação: mudar posteriormente o produto ou a zona não move uma tarefa já em preparação. Alterações das áreas devem ser feitas entre serviços. Não é possível desativar um posto com trabalho em curso nem desligar a divisão com pedidos em preparação.

Os painéis usam eventos por utilizador sem conteúdo de pedidos; cada recarregamento consulta apenas os postos autorizados. A cozinha não subscreve o canal geral de pedidos. Há recarregamento de segurança a cada 15 segundos e ao regressar à aplicação. Sons continuam sujeitos às preferências e autorização de áudio do dispositivo; notificações push dependem da configuração já existente.

## Transição dos dados existentes

Menus de almoço existentes mantêm as suas escolhas. Grupos antigos aceitam produtos ainda por classificar, evitando interromper o serviço na atualização. Ao guardar grupos configurados, exige-se a classificação compatível. O gerente deve classificar os produtos antes de reconfigurar esses grupos.

A divisão permanece desligada até o gerente a ativar. A ativação inclui pedidos aceites que já estejam em curso. As contas de preparação só ficam limitadas quando a divisão está ativa.

## Eliminar um estabelecimento

Na Administração → Contrato e plano → Eliminar estabelecimento, escrever o identificador do cliente e confirmar. A eliminação retira o cliente da gestão, desativa os utilizadores e mesas, encerra intervenções de suporte e bloqueia novas operações. Pedidos, pagamentos e auditoria são preservados; não é destruição física do histórico. Pedidos por pagar ou chamadas em curso impedem a eliminação. Um estabelecimento eliminado não pode ser reativado pela edição normal.

## Atualização na VPS

Criar cópia PostgreSQL antes de atualizar. A imagem executa `db:prepare`, incluindo a migração `20261009140000`. A migração conserva os menus de almoço e adiciona a classificação, menus por horário, zonas e tarefas.

