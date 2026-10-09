# Menus e áreas de preparação

- A Administração autoriza áreas pelo limite: zero desliga, um ou mais limita o número de áreas ativas. O gerente escolhe os nomes e ativa a divisão. Não é possível criar/reativar acima do limite, baixar o limite abaixo das áreas ativas ou retirar a permissão enquanto a divisão está ativa.
- A atualização conserva a permissão dos estabelecimentos que já tinham a divisão ativa pelo fluxo antigo, ajustando o limite ao número de áreas existentes (mínimo dois). Novos estabelecimentos começam sem permissão.
- Um produto novo/editado requer tipo; com divisão ativa, requer uma área do próprio estabelecimento. A função da área é guardada automaticamente para o encaminhamento por zonas. Produtos antigos com tipo ou área em falta aparecem na classificação em lote.
- Carta e menus por horário estão separados na gestão. Ao cliente, Carta tem as suas categorias num segundo nível; pequeno-almoço/almoço mostram a hora de fim.
- Na configuração do menu completo, assinalar um grupo significa que ele faz parte do preço e requer uma escolha do cliente. Desmarcar exclui-o. Produtos e grupos guardam-se numa só operação. A opção antiga «Opcional» sai do formulário. Grupos chamados Ovos são retirados da configuração; o alergénio Ovos permanece.
- Eliminar um estabelecimento usa o caixote do lixo e uma confirmação simples. Não exige escrever o identificador. Serviço por concluir continua a bloquear a operação; pedidos, pagamentos e auditoria anteriores são preservados.
- Antes de atualizar a VPS, efetuar backup da base de dados. A nova migração apenas regulariza as permissões existentes; não altera produtos nem pedidos.

## Grupos configuráveis
O almoço começa com Sopa, Prato, Café e Sobremesa. Cada grupo pode ser incluído ou retirado com Sim/Não. O gerente pode criar outros grupos, dar-lhes um nome, escolher o tipo e selecionar os produtos correspondentes. Os grupos do pequeno-almoço também são configuráveis; o nome do menu pode ser Brunch. Produtos vendidos à unidade têm uma seleção independente. Uma seleção explicitamente vazia não recupera os grupos antigos.
