require 'test_helper'

class MenuImportTest < ActiveSupport::TestCase
  setup do
    @source, _, @product = build_venue
    @destination = Establishment.create!(name: 'Café Novo', slug: "novo-#{SecureRandom.hex(4)}")
    @admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
    @child = @source.categories.create!(name: 'Padaria', parent: @product.category)
    @bread = @child.menu_items.create!(name: 'Pão', price: 1, available: false, description: 'Pão fresco', allergens: ['gluten'],
      nutrition_enabled: true, nutrition_energy: 220)
    @bread.image.attach(io: File.open(Rails.root.join('app/assets/images/bocato-icon.png')), filename: 'bread.png', content_type: 'image/png')
    @product.recommendations.create!(recommended_menu_item: @bread)
    @source.create_lunch_menu!(active: true, combo_enabled: true, individual_offers: [{ 'menu_item_id' => @bread.id, 'price' => '0.80' }],
      combo_groups: LunchMenu::GROUPS.keys.to_h { |key| [key, [{ 'menu_item_id' => @product.id, 'supplement' => '0' }]] })
  end

  def copy(plan)
    MenuImport.copy!(source_id: @source.id, destination_id: @destination.id,
      category_ids: plan.selected_categories.map(&:id), product_ids: plan.selected_products.map(&:id), expected_digest: plan.digest, user: @admin)
  end

  test 'full copy preserves hierarchy information photos suggestions and remaps lunch products' do
    plan = MenuImport.new(source: @source, destination: @destination)
    assert_broadcasts(CustomerMenuBroadcast.stream_name(@destination), 1) { copy(plan) }
    @destination.reload
    imported = @destination.menu_items.find_by!(name: 'Pão')
    assert_equal @product.category.name, imported.category.parent.name
    assert_equal @bread.description, imported.description
    assert_equal ['gluten'], imported.allergens
    assert_equal 220, imported.nutrition_energy
    assert_not imported.available?
    assert_equal @bread.image.download, imported.image.download
    assert_not_equal @bread.id, imported.id
    assert_equal imported.id, @destination.lunch_menu.individual_offers.first['menu_item_id']
    copied_product = @destination.menu_items.find_by!(name: @product.name)
    assert_equal [imported.id], copied_product.recommended_menu_item_ids
    assert_equal copied_product.id, @destination.lunch_menu.combo_groups['soup'].first['menu_item_id']
    assert_equal @bread.id, @source.lunch_menu.individual_offers.first['menu_item_id']
    @bread.update!(name: 'Pão alterado', price: 2)
    @bread.image.attach(io: StringIO.new(@bread.image.download), filename: 'replacement.png', content_type: 'image/png')
    assert_equal 'Pão', imported.reload.name
    assert_equal 1, imported.price
    assert_equal 'bread.png', imported.image.filename.to_s
    assert AuditEvent.where(establishment: @destination, action: 'menu_imported').exists?
  end

  test 'selecting one product retains ancestors and excludes unselected recommendations and archived branches' do
    archived = @source.categories.create!(name: 'Antigos', archived_at: Time.current)
    child = @source.categories.create!(name: 'Filhos antigos', parent: archived)
    child.menu_items.create!(name: 'Produto antigo', price: 1)
    plan = MenuImport.new(source: @source, destination: @destination, category_ids: [], product_ids: [@bread.id])
    assert_equal 2, plan.selected_categories.size
    assert_equal 0, plan.counts[:suggestions]
    assert plan.incomplete_lunch?
    copy(plan)
    @destination.reload
    assert_equal ['Pão'], @destination.menu_items.pluck(:name)
    assert_not @destination.lunch_menu.combo_enabled?
    assert @destination.lunch_menu.individual_enabled?
    assert_not @destination.categories.exists?(name: 'Antigos')
  end

  test 'stale preview foreign product and populated destination are rejected without partial writes' do
    _, _, foreign = build_venue
    assert_raises(MenuImport::Invalid) { MenuImport.new(source: @source, destination: @destination, product_ids: [foreign.id]) }
    plan = MenuImport.new(source: @source, destination: @destination)
    digest = plan.digest
    @bread.update!(price: 2)
    assert_raises(MenuImport::Invalid) do
      MenuImport.copy!(source_id: @source.id, destination_id: @destination.id, category_ids: plan.selected_categories.map(&:id),
        product_ids: plan.selected_products.map(&:id), expected_digest: digest, user: @admin)
    end
    assert @destination.menu_empty?
    @destination.categories.create!(name: 'Já existe')
    assert_raises(MenuImport::Invalid) { copy(plan) }
  end

  test 'validation failure rolls back all categories products attachments and audit' do
    @bread.update_columns(description: 'x' * 501)
    plan = MenuImport.new(source: @source, destination: @destination)
    assert_no_difference(['Category.count', 'MenuItem.count', 'ActiveStorage::Attachment.count', 'AuditEvent.count']) do
      assert_raises(MenuImport::Invalid) { copy(plan) }
    end
    assert @destination.menu_empty?
  end
end
