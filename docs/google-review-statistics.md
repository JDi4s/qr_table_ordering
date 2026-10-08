# Cliques nas avaliações Google

O botão do cliente envia um POST com proteção CSRF e abre o endereço Google
configurado pelo estabelecimento numa nova aba, sem acrescentar um passo.
Consultar a página, fechar o convite ou testar a ligação nas Definições não
regista um clique. O pedido só é aceite para o navegador com um pedido próprio
não recusado nessa mesa e com o módulo de avaliações configurado e ativo.

As Estatísticas, o PDF estatístico e o CSV estatístico mostram os cliques totais
e os navegadores distintos no período selecionado. O CSV estatístico passa a
partilhar a estrutura e os valores do PDF, com resumo, comparações, avaliações,
produtos, categorias, pagamentos, mesas, horários e notas. Usa UTF-8 com BOM,
separador ponto e vírgula e linhas CRLF para abrir corretamente no Excel em PT.
Os valores são do estabelecimento inteiro, mesmo com filtro de funcionário.

Não se contam avaliações publicadas no Google. A distinção de navegadores usa
um resumo SHA-256 da identidade de sessão e do estabelecimento, sem guardar IP,
nome, email ou o token da sessão. Limpar cookies ou trocar de navegador pode
contar novamente. Cliques repetidos contam no total mas só uma vez no indicador
de navegadores distintos do período.

A migração regista a data de início da contagem para cada estabelecimento.
Períodos anteriores mostram «Sem registo»; não se inventam contagens históricas.
Um período que inclua datas anteriores só tem registos desde a instalação,
conforme a nota visível na app, no PDF e no CSV. O Caixa mantém os seus dados
financeiros; esta métrica pertence às Estatísticas.
