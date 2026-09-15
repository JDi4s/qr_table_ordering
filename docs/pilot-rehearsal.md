# Ensaio técnico de 30 mesas

O workflow Rails executa `test/support/pilot_rehearsal.rb` numa base PostgreSQL
exclusiva, `mesa_rehearsal_test`, com `RAILS_ENV=test`. O script recusa outra base
ou uma base já preenchida. Nunca o executar com credenciais da VPS.

São 30 mesas, 90 sessões independentes de clientes e 180 pedidos reais pelas
rotas Rails, incluindo observações, repetição da submissão, isolamento de
clientes, chamadas de assistência, aceitação e serviço, pagamento simultâneo
do mesmo pedido, pagamentos parciais, anulação, fecho e reabertura do Caixa.

Cada grupo de três clientes representa uma mesa: os 30 grupos começam juntos.
Há oito ligações PostgreSQL disponíveis; as restantes operações aguardam a pool.
As corridas de pagamento usam objetos ActiveRecord e ligações independentes.
Os testes de navegador existentes continuam a executar separadamente.

O artefacto GitHub `pilot-rehearsal-report/report.json` contém resultados e
duração de cada cenário. Um cenário falhado faz o workflow falhar. Os valores
esperados são calculados independentemente: 180 pedidos de 10 €, 1 800 € de
receita ativa, dívida zero no final e um pagamento anulado preservado.

Isto não é um benchmark de produção: as requisições são em processo, sem rede,
proxy ou Puma. Não comprova capacidade da VPS, tempos WebSocket, notificações
com ecrã bloqueado, backups/restauros ou resistência a falhas reais de rede.
Esses pontos precisam do ensaio separado e dos dispositivos do café.
