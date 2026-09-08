# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_09_08_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "available", default: true, null: false
    t.bigint "establishment_id", null: false
    t.index ["establishment_id"], name: "index_categories_on_establishment_id"
  end

  create_table "establishments", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "table_limit", default: 50, null: false
    t.integer "monthly_fee_cents", default: 10000, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_establishments_on_slug", unique: true
    t.check_constraint "table_limit >= 0 AND monthly_fee_cents >= 0", name: "establishment_limits_positive"
  end

  create_table "menu_items", force: :cascade do |t|
    t.string "name"
    t.decimal "price"
    t.boolean "available", default: true, null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_menu_items_on_category_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "menu_item_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending", null: false
    t.decimal "unit_price", precision: 10, scale: 2, default: "0.0", null: false
    t.string "denial_reason"
    t.text "note"
    t.string "name_snapshot"
    t.string "proposed_description"
    t.decimal "original_unit_price", precision: 10, scale: 2
    t.index ["menu_item_id"], name: "index_order_items_on_menu_item_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["status"], name: "index_order_items_on_status"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
    t.text "note"
    t.string "denial_reason"
    t.datetime "served_at"
    t.string "customer_token"
    t.string "submission_token"
    t.index ["customer_token"], name: "index_orders_on_customer_token"
    t.index ["table_id", "customer_token", "submission_token"], name: "unique_customer_submission", unique: true
    t.index ["table_id"], name: "index_orders_on_table_id"
  end

  create_table "service_calls", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.bigint "assigned_user_id"
    t.string "status", default: "pending", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_user_id"], name: "index_service_calls_on_assigned_user_id"
    t.index ["table_id"], name: "index_service_calls_on_table_id"
    t.index ["table_id"], name: "one_open_call_per_table", unique: true, where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'claimed'::character varying])::text[]))"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'claimed'::character varying, 'resolved'::character varying]::text[])", name: "valid_service_call_status"
  end

  create_table "tables", force: :cascade do |t|
    t.integer "number"
    t.string "qr_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "establishment_id", null: false
    t.boolean "active", default: true, null: false
    t.index ["establishment_id", "number"], name: "index_tables_on_establishment_id_and_number", unique: true
    t.index ["establishment_id"], name: "index_tables_on_establishment_id"
    t.index ["qr_token"], name: "index_tables_on_qr_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "staff_sound_enabled", default: true, null: false
    t.bigint "establishment_id"
    t.boolean "active", default: true, null: false
    t.index ["establishment_id"], name: "index_users_on_establishment_id"
  end

  add_foreign_key "categories", "establishments"
  add_foreign_key "menu_items", "categories"
  add_foreign_key "order_items", "menu_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "tables"
  add_foreign_key "service_calls", "tables"
  add_foreign_key "service_calls", "users", column: "assigned_user_id"
  add_foreign_key "tables", "establishments"
  add_foreign_key "users", "establishments"
end
