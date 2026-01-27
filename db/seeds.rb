# -----------------------------
# Seed Categories
# -----------------------------
puts "Seeding categories..."
categories = %w[Pizza Pasta Drinks Appetizers].map do |name|
  Category.find_or_create_by!(name: name)
end

# Map categories by name for easier reference
categories_by_name = categories.index_by(&:name)

# -----------------------------
# Seed Menu Items
# -----------------------------
puts "Seeding menu items..."
menu_items_data = [
  { name: "Bruschetta", price: 5.5, category: "Appetizers" },
  { name: "Margherita Pizza", price: 10.0, category: "Pizza" },
  { name: "Pepperoni Pizza", price: 12.0, category: "Pizza" },
  { name: "Spaghetti Bolognese", price: 11.0, category: "Pasta" },
  { name: "Fettuccine Alfredo", price: 12.0, category: "Pasta" },
  { name: "Coca-Cola", price: 3.0, category: "Drinks" },
  { name: "Water", price: 1.5, category: "Drinks" }
]

menu_items_data.each do |item|
  MenuItem.find_or_create_by!(name: item[:name]) do |m|
    m.price = item[:price]
    m.category = categories_by_name[item[:category]]
  end
end

# -----------------------------
# Seed Tables
# -----------------------------
puts "Seeding tables..."
(1..5).each do |num|
  Table.find_or_create_by!(number: num)
end

# -----------------------------
# Seed Staff User
# -----------------------------
puts "Seeding staff user..."
User.find_or_create_by!(email: "staff@example.com") do |user|
  user.password = "password"
  user.role = "staff"
end

puts "Seeding complete!"
