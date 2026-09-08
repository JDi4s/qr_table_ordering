ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  include ActionCable::TestHelper
  parallelize(workers: 1)

  def build_venue(slug = SecureRandom.hex(6), limit: 50)
    venue = Establishment.create!(name: "Café #{slug}", slug: slug, table_limit: limit)
    table = venue.tables.create!(number: 1)
    category = venue.categories.create!(name: 'Comida', available: true)
    product = category.menu_items.create!(name: "Produto #{slug}", price: 10, available: true)
    [venue, table, product]
  end

  def venue_user(venue, role: 'manager')
    User.create!(establishment: venue, role: role, email: "#{SecureRandom.hex(6)}@example.com", password: 'Test-password-123', name: role)
  end

  def build_order(table, product, customer: 'customer-a')
    table.orders.create!(customer_token: customer, status: 'pending', total: 30) do |order|
      order.order_items.build(menu_item: product, quantity: 1, unit_price: 10, status: 'pending')
      order.order_items.build(menu_item: product, quantity: 2, unit_price: 10, status: 'pending')
    end
  end
end

class ActionDispatch::IntegrationTest
  def sign_in(user)
    post login_path, params: { email: user.email, password: 'Test-password-123' }
    assert_response :redirect
  end
end
