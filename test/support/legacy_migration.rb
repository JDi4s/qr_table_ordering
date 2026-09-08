# Used by CI against an isolated database at the previous schema version.
connection = ActiveRecord::Base.connection
if ARGV.first == 'seed'
  table_id = connection.select_value("INSERT INTO tables (number, qr_token, created_at, updated_at) VALUES (1, 'legacy-qr-kept', NOW(), NOW()) RETURNING id")
  category_id = connection.select_value("INSERT INTO categories (name, available, created_at, updated_at) VALUES ('Legacy', TRUE, NOW(), NOW()) RETURNING id")
  product_id = connection.select_value("INSERT INTO menu_items (name, price, available, category_id, created_at, updated_at) VALUES ('Original product', 10, TRUE, #{category_id}, NOW(), NOW()) RETURNING id")
  connection.execute("INSERT INTO users (email, role, created_at, updated_at) VALUES ('legacy@example.com', 'admin', NOW(), NOW())")
  order_id = connection.select_value("INSERT INTO orders (table_id, status, total, created_at, updated_at) VALUES (#{table_id}, 'needs_customer_action', 16, NOW(), NOW()) RETURNING id")
  connection.execute("INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, status, created_at, updated_at) VALUES (#{order_id}, #{product_id}, 1, 10, 'pending', NOW(), NOW()), (#{order_id}, #{product_id}, 2, 3, 'denied', NOW(), NOW())")
else
  table = Table.find_by!(qr_token: 'legacy-qr-kept')
  order = table.orders.first!
  raise 'Lost table identity' unless table.number == 1 && table.establishment.present?
  raise 'Legacy review not recoverable' unless order.pending? && order.total == 10
  raise 'Customer identity missing' unless order.customer_token.present?
  raise 'Staff role not preserved' unless User.find_by!(email: 'legacy@example.com').manager?
  raise 'Ordered price/name lost' unless order.order_items.first.original_unit_price == 10 && order.order_items.first.name_snapshot == 'Original product'
  puts 'Legacy migration: data and QR preserved, pending review and total repaired.'
end
