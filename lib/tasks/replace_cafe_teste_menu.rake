namespace :menu do
  desc 'Replace the Café Teste menu with a realistic Portuguese café menu'
  task replace_cafe_teste: :environment do
    establishment = Establishment.find_by(name: 'Café Teste') || Establishment.find_by(slug: 'cafe-teste')
    raise 'Não foi encontrado o estabelecimento Café Teste.' unless establishment

    menu = {
      'Bebidas' => {
        'Cafetaria' => [
          ['Café', '0.85'], ['Descafeinado', '0.95'], ['Café duplo', '1.50'],
          ['Café americano', '1.20'], ['Café com leite', '1.30'], ['Meia de leite', '1.30'],
          ['Galão', '1.40'], ['Chocolate quente', '2.20'], ['Chá preto', '1.30'],
          ['Chá verde', '1.30'], ['Chá de camomila', '1.30'], ['Chá de menta', '1.30'],
          ['Chá de frutos vermelhos', '1.40'], ['Infusão', '1.30'], ['Café com gelo', '1.20']
        ],
        'Águas' => [
          ['Água mineral 33cl', '0.80'], ['Água mineral 50cl', '1.00'],
          ['Água com gás 25cl', '1.10'], ['Água tónica', '1.50']
        ],
        'Sumos' => [
          ['Sumo de laranja natural', '2.50'], ['Sumo de limão', '2.20'],
          ['Sumo de ananás', '1.80'], ['Sumo de maçã', '1.80'], ['Sumo de laranja', '1.80'],
          ['Sumo de pêssego', '1.80'], ['Sumo de manga', '2.00'],
          ['Sumo de frutos vermelhos', '2.20'], ['Sumo de morango', '2.20'],
          ['Limonada', '1.80'], ['Limonada com hortelã', '2.00'],
          ['Ice Tea Limão', '1.60'], ['Ice Tea Pêssego', '1.60'], ['Ice Tea Manga', '1.60']
        ],
        'Cerveja' => [
          ['Fino', '1.30'], ['Caneca', '2.20'], ['Cerveja 20cl', '1.20'],
          ['Cerveja 25cl', '1.40'], ['Cerveja 33cl', '1.80'], ['Cerveja 50cl', '2.50'],
          ['Cerveja preta', '2.00'], ['Cerveja sem álcool', '1.80'],
          ['Cerveja artesanal', '3.00'], ['Panaché', '1.50'], ['Radler', '1.80']
        ],
        'Vinhos' => [
          ['Vinho tinto — copo', '1.80'], ['Vinho tinto — garrafa', '8.00'],
          ['Vinho branco — copo', '1.80'], ['Vinho branco — garrafa', '8.00'],
          ['Vinho verde — copo', '2.00'], ['Vinho verde — garrafa', '9.00'],
          ['Vinho rosé — copo', '2.00'], ['Vinho rosé — garrafa', '9.00'],
          ['Espumante — copo', '2.50'], ['Espumante — garrafa', '12.00'],
          ['Sangria', '3.50'], ['Sangria de frutos vermelhos', '4.00'],
          ['Sangria de maracujá', '4.00'], ['Sangria branca', '3.50']
        ],
        'Bebidas brancas' => [
          ['Whisky', '3.50'], ['Vodka', '3.00'], ['Gin', '3.00'], ['Rum', '3.00'],
          ['Brandy', '2.50'], ['Aguardente', '2.50'], ['Tequila', '3.00'],
          ['Licor Beirão', '2.50'], ['Amêndoa Amarga', '2.50'], ['Moscatel', '2.50'],
          ['Porto', '2.50'], ['Martini', '2.50'], ['Baileys', '3.50'],
          ['Jägermeister', '3.50'], ['Gin Tónico', '6.00'], ['Whisky Cola', '5.00'],
          ['Cuba Libre', '5.00'], ['Caipirinha', '6.00'], ['Caipiroska', '6.00'],
          ['Mojito', '6.50'], ['Margarita', '6.50'], ['Aperol Spritz', '6.50']
        ]
      },
      'Comidas' => {
        'Padaria' => [
          ['Pão', '0.25'], ['Pão bijou', '0.35'], ['Pão de mistura', '0.40'],
          ['Pão integral', '0.40'], ['Pão de cereais', '0.50'], ['Pão rústico', '0.60'],
          ['Pão alentejano', '0.60'], ['Pão de água', '0.35'], ['Pão de milho', '0.40'],
          ['Pão de sementes', '0.50'], ['Baguete', '1.00'], ['Pão de hambúrguer', '1.00'],
          ['Pão de cachorro', '1.00'], ['Broa de milho', '0.60'], ['Croissant brioche', '1.50']
        ],
        'Pastelaria' => [
          ['Pastel de nata', '1.20'], ['Croissant simples', '1.30'],
          ['Croissant de chocolate', '1.60'], ['Croissant brioche', '1.50'],
          ['Croissant misto', '2.20'], ['Croissant com queijo', '1.80'],
          ['Croissant com fiambre', '1.80'], ['Bola de Berlim', '1.50'],
          ['Pão de Deus', '1.50'], ['Queque', '1.30'], ['Muffin', '1.80'],
          ['Napolitana', '1.80'], ['Jesuíta', '1.80'], ['Limonete', '1.80'],
          ['Mil-folhas', '2.20'], ['Palmier', '1.30'], ['Eclair', '2.20'],
          ['Tarte de maçã', '2.20'], ['Tarte de amêndoa', '2.40'],
          ['Tarte de nata', '2.20'], ['Tarte de limão', '2.20'],
          ['Bolo de chocolate', '2.50'], ['Bolo de laranja', '2.20'],
          ['Bolo de cenoura', '2.20'], ['Bolo de iogurte', '2.20'],
          ['Bolo de bolacha', '2.50'], ['Cheesecake', '3.00'], ['Pudim', '2.20']
        ],
        'Sandes' => [
          ['Pão com manteiga', '0.80'], ['Pão com queijo', '1.50'], ['Pão com fiambre', '1.50'],
          ['Pão misto', '2.20'], ['Sandes de queijo', '2.00'], ['Sandes de fiambre', '2.00'],
          ['Sandes de presunto', '2.80'], ['Sandes de chouriço', '2.50'],
          ['Sandes de frango', '3.50'], ['Sandes de atum', '3.20'], ['Sandes de ovo', '2.50'],
          ['Sandes de delícias do mar', '3.20'], ['Sandes de leitão', '4.50'],
          ['Sandes de pasta de atum', '3.00'], ['Sandes de pasta de frango', '3.00'],
          ['Tosta mista', '3.00'], ['Tosta de queijo', '2.20'], ['Tosta de fiambre', '2.20'],
          ['Tosta de frango', '3.50'], ['Tosta de atum', '3.50'], ['Tosta de presunto', '3.80'],
          ['Baguete de frango', '4.00'], ['Baguete de atum', '3.80'],
          ['Baguete de presunto', '4.20'], ['Baguete mista', '3.80'], ['Prego no pão', '4.50']
        ]
      }
    }

    created_categories = 0
    created_items = 0

    ActiveRecord::Base.transaction do
      existing_items = establishment.menu_items.to_a
      existing_categories = establishment.categories.to_a
      archived_at = Time.current

      existing_items.each { |item| item.update!(available: false, archived_at: archived_at) }
      existing_categories.each { |category| category.update!(available: false, archived_at: archived_at) }

      menu.each do |root_name, subcategories|
        root = establishment.categories.create!(name: root_name, available: true)
        created_categories += 1

        subcategories.each do |subcategory_name, products|
          category = establishment.categories.create!(name: subcategory_name, parent: root, available: true)
          created_categories += 1

          products.each do |name, price|
            category.menu_items.create!(name: name, price: price, available: true)
            created_items += 1
          end
        end
      end
    end

    puts "Menu do Café Teste atualizado: #{created_categories} categorias e #{created_items} produtos criados."
    puts 'Os produtos e categorias anteriores foram arquivados para preservar o histórico de pedidos.'
  end
end
