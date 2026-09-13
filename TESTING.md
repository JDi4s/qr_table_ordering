# Ensaio de aceitação na VPS

Utilize dados fictícios e dois navegadores/dispositivos. Pagamentos online estão fora do âmbito.

1. Como administrador, crie A e B com limite 2 e gerentes distintos. Como A, crie duas mesas; a terceira deve falhar. Repita com duas janelas em simultâneo. B também pode criar Mesa 1.
2. Descarregue o mesmo QR várias vezes: continua a contar uma mesa. Desative uma mesa: o QR deixa de aceitar pedidos e pode criar outra. Reativar sem quota deve falhar. Aumente o limite na administração e repita.
3. Abra o QR no telemóvel por dados móveis: domínio HTTPS correto, menu apenas desse estabelecimento. Crie produtos diferentes em A e B. Os menus e painéis não se devem misturar.
4. Envie um pedido com dois artigos. O painel aberto deve recebê-lo sem refresh. Ative o som por clique e teste um segundo pedido. Reenviar a mesma revisão não pode duplicar o pedido.
5. Rejeite um artigo com motivo e conclua a avaliação. O cliente vê o motivo e total sem esse artigo; só após aceitar é que o pedido fica aceite. Rejeitar todos termina o pedido sem pedir confirmação.
6. Proponha «sem queijo» com novo preço. Conclua a avaliação e confirme no cliente. Teste também cancelar em vez de aceitar. Sem confirmação, não pode marcar como servido.
7. Aceite um pedido inteiro e marque-o servido. O estado no cliente e histórico do funcionário devem coincidir. Pedidos terminados não podem ser reabertos ou alterados.
8. Abra a mesma mesa noutro navegador: não deve receber os pedidos pessoais do primeiro cliente. Teste também trocar os IDs nos URLs entre estabelecimentos: acesso negado/404.
9. Chame o funcionário pelo QR. Dois funcionários veem o alerta; apenas um consegue assumir. Outro funcionário não pode finalizar a chamada assumida, salvo gerente. Cliques repetidos não criam alertas duplicados. Aguarde 60 segundos para uma nova chamada.
10. Suspenda B: login, QR e ações passam a estar bloqueados; A continua a funcionar. Desative uma conta da equipa e confirme que deixa de conseguir operar.
11. Reinicie os containers e confirme que os dados permanecem. Teste a ligação WebSocket pelo subdomínio HTTPS e o restauro de backup numa base separada.
