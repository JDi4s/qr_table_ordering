# Ativação e visita da mesa

O QR continua a identificar a mesa e a abrir o menu imediatamente. A primeira
abertura de uma mesa sem visita cria uma única visita a aguardar ativação. Os
clientes podem escolher artigos e rever o pedido, mas apenas podem enviá-lo
quando um funcionário ativa a mesa no painel de Pedidos.

O painel distingue mesas à espera (amarelo), visitas abertas (verde) e mesas
inativas. Gerentes e funcionários do estabelecimento podem abrir e fechar
visitas. Uma leitura repetida, mesmo por vários clientes, não repete o aviso.

A visita fecha quando o pagamento deixa a mesa sem pedidos por pagar, ou
manualmente em Consumo da mesa quando não existem pedidos pendentes. Pagamentos
parciais mantêm a visita aberta. Anular um pagamento repõe a dívida, mas não
reabre automaticamente o acesso dos clientes. Pedidos e pagamentos antigos
continuam no histórico; os pedidos da visita fechada são recolhidos em Pedidos
anteriores para o mesmo cliente durante 24 horas.

Cada navegador guarda a identidade da visita. Revisões assinadas incluem essa
identidade; fechar e voltar a abrir a mesa não permite enviar revisões antigas.
O servidor confirma o estado novamente sob os mesmos bloqueios usados nos
pagamentos. Os clientes só consultam os seus próprios pedidos.

## Alertas

Novas mesas à espera geram um evento em tempo real em todas as páginas de gestão
e um sinal de duas notas. Usa Testar som no painel uma vez no dispositivo para
verificar a permissão do navegador, mantendo o som ativo nas Preferências.
O estado também é reconciliado de 10 em 10 segundos e ao recuperar a ligação.

É igualmente enviado push para os dispositivos com subscrição ativa quando
VAPID está configurado. A notificação abre diretamente o painel de ativação.
Com a aplicação fechada, a entrega e o som dependem da permissão de notificações,
do sistema operativo e da disponibilidade de rede. Web Push não permite impor
um som personalizado em todos os sistemas. Os testes de navegador verificam o
evento e o funcionamento do AudioContext; a entrega e o som físicos de push
devem ser verificados nos dispositivos do café.

## Limite de proteção

A ativação é um controlo de serviço, não uma prova de presença física. Uma foto
do QR continua a permitir iniciar uma tentativa de acesso enquanto a mesa está
aberta. Não é feita validação de localização nem usado um QR rotativo.

## Instalação

A migração mantém abertas as mesas com pedidos por pagar e associa esses pedidos
à visita, para não interromper o serviço em curso. As outras mesas começam sem
visita aberta. O QR e a opção administrativa de disponibilizar a mesa não mudam.
