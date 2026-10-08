require 'application_system_test_case'

class LiveMenuSystemTest < ApplicationSystemTestCase
  test 'availability updates over Turbo without navigation and preserves customer choices' do
    venue, table, product = build_venue
    product.update!(name: 'Baguete')
    drinks = venue.categories.create!(name: 'Bebidas')
    juice = drinks.menu_items.create!(name: 'Sumo de laranja', price: 2)
    juice.image.attach(io: File.open(Rails.root.join('app/assets/images/bocato-icon.png')), filename: 'test-product.png', content_type: 'image/png')
    water = drinks.menu_items.create!(name: 'Água', price: 1)
    visit new_table_order_path(table)
    assert_selector 'turbo-cable-stream-source[channel="MenuChannel"][connected]', visible: :all
    page.execute_script('window.liveMenuNavigationMarker = "same-page"')
    find('.menu-root-tab', text: 'Bebidas').click
    within('.customer-product-card', text: 'Sumo de laranja') { find('.customer-add-button').click }
    within('.customer-product-card', text: 'Água') { find('.customer-add-button').click }
    fill_in 'Pesquisar no menu', with: 'Sumo'

    juice.update!(available: false)
    assert_no_selector '.customer-product-card', text: 'Sumo de laranja', visible: :all
    assert_field 'Pesquisar no menu', with: 'Sumo'
    assert_text 'Um produto selecionado deixou de estar disponível'
    assert_equal '1', find("#quantity_#{water.id}", visible: :all).value
    assert_selector '.customer-cart-bar', text: '1 artigo'
    assert_selector '.menu-root-tab.is-active', text: 'Bebidas'
    assert_equal 'same-page', page.evaluate_script('window.liveMenuNavigationMarker')

    juice.update!(available: true)
    assert_selector '.customer-product-card', text: 'Sumo de laranja'
    assert_equal '0', find("#quantity_#{juice.id}", visible: :all).value
    assert_equal '1', find("#quantity_#{water.id}", visible: :all).value
    fill_in 'Pesquisar no menu', with: ''
    juice.update!(price: 3)
    within('.customer-product-card', text: 'Sumo de laranja') do
      assert_text '3,00 €'
      image = find('img[src^="/rails/active_storage/"]')
      assert page.evaluate_async_script(<<~JS, image)
        const image = arguments[0], done = arguments[arguments.length - 1];
        if (image.complete) done(image.naturalWidth > 0);
        else { image.onload = () => done(image.naturalWidth > 0); image.onerror = () => done(false); }
      JS
    end
    drinks.update!(available: false)
    assert_no_selector '.menu-root-tab', text: 'Bebidas'
    assert_selector '.customer-product-card', text: 'Baguete'
    assert_no_selector '.customer-cart-bar'
    assert_equal 'same-page', page.evaluate_script('window.liveMenuNavigationMarker')
  end
end
