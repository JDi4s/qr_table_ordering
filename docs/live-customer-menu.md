# Menu do cliente em tempo real

Produtos e categorias publicam, após commit, uma substituição Turbo do menu
público do próprio estabelecimento. O canal exige uma sessão de cliente e um
QR ativo; verifica novamente a autorização em cada transmissão. Não transmite
pedidos, identidades ou quantidades de clientes. Cada ligação/religação recebe
uma fotografia atual do menu para recuperar alterações perdidas offline.

Antes de substituir o menu, o navegador guarda localmente pesquisa, categoria
e quantidades escolhidas. Repõe os produtos ainda disponíveis e recalcula os
totais com os preços atuais. Produtos que deixaram de estar disponíveis saem
da seleção com um aviso, sem afetar pedidos já enviados. A atualização não
recarrega a página nem cria outra visita da mesa.
