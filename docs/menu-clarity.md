# Menus e Ã¡reas de preparaÃ§Ã£o

- A AdministraÃ§Ã£o autoriza Ã¡reas pelo limite: zero desliga, um ou mais limita o nÃºmero de Ã¡reas ativas. O gerente escolhe os nomes e ativa a divisÃ£o. NÃ£o Ã© possÃ­vel criar/reativar acima do limite, baixar o limite abaixo das Ã¡reas ativas ou retirar a permissÃ£o enquanto a divisÃ£o estÃ¡ ativa.
- A atualizaÃ§Ã£o conserva a permissÃ£o dos estabelecimentos que jÃ¡ tinham a divisÃ£o ativa pelo fluxo antigo, ajustando o limite ao nÃºmero de Ã¡reas existentes (mÃ­nimo dois). Novos estabelecimentos comeÃ§am sem permissÃ£o.
- Um produto novo/editado requer tipo; com divisÃ£o ativa, requer uma Ã¡rea do prÃ³prio estabelecimento. A funÃ§Ã£o da Ã¡rea Ã© guardada automaticamente para o encaminhamento por zonas. Produtos antigos com tipo ou Ã¡rea em falta aparecem na classificaÃ§Ã£o em lote.
- Carta e menus por horÃ¡rio estÃ£o separados na gestÃ£o. Ao cliente, Carta tem as suas categorias num segundo nÃ­vel; pequeno-almoÃ§o/almoÃ§o mostram a hora de fim.
- Na configuraÃ§Ã£o do menu completo, assinalar um grupo significa que ele faz parte do preÃ§o e requer uma escolha do cliente. Desmarcar exclui-o. Produtos e grupos guardam-se numa sÃ³ operaÃ§Ã£o. A opÃ§Ã£o antiga Â«OpcionalÂ» sai do formulÃ¡rio. Grupos chamados Ovos sÃ£o retirados da configuraÃ§Ã£o; o alergÃ©nio Ovos permanece.
- Eliminar um estabelecimento usa o caixote do lixo e uma confirmaÃ§Ã£o simples. NÃ£o exige escrever o identificador. ServiÃ§o por concluir continua a bloquear a operaÃ§Ã£o; pedidos, pagamentos e auditoria anteriores sÃ£o preservados.
- Antes de atualizar a VPS, efetuar backup da base de dados. A nova migraÃ§Ã£o apenas regulariza as permissÃµes existentes; nÃ£o altera produtos nem pedidos.

## Grupos configuráveis
O almoço começa com Sopa, Prato, Café e Sobremesa. Cada grupo pode ser incluído ou retirado com Sim/Não. O gerente pode criar outros grupos, dar-lhes um nome, escolher o tipo e selecionar os produtos correspondentes. Os grupos do pequeno-almoço também são configuráveis; o nome do menu pode ser Brunch. Produtos vendidos à unidade têm uma seleção independente. Uma seleção explicitamente vazia não recupera os grupos antigos.
