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

ActiveRecord::Schema[7.1].define(version: 2026_10_09_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "establishment_id", null: false
    t.bigint "user_id"
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.string "action", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["establishment_id", "created_at"], name: "index_audit_events_on_establishment_id_and_created_at"
    t.index ["establishment_id"], name: "index_audit_events_on_establishment_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "cash_closures", force: :cascade do |t|
    t.bigint "establishment_id", null: false
    t.bigint "user_id", null: false
    t.date "business_date", null: false
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "payments_count", default: 0, null: false
    t.jsonb "payment_breakdown", default: {}, null: false
    t.datetime "closed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "reopened_at"
    t.bigint "reopened_by_user_id"
    t.string "reopen_reason"
    t.index ["establishment_id", "business_date"], name: "one_active_cash_closure_per_day", unique: true, where: "(reopened_at IS NULL)"
    t.index ["establishment_id"], name: "index_cash_closures_on_establishment_id"
    t.index ["reopened_by_user_id"], name: "index_cash_closures_on_reopened_by_user_id"
    t.index ["user_id"], name: "index_cash_closures_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "available", default: true, null: false
    t.bigint "establishment_id", null: false
    t.bigint "parent_id"
    t.datetime "archived_at"
    t.index ["archived_at"], name: "index_categories_on_archived_at"
    t.index ["establishment_id"], name: "index_categories_on_establishment_id"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "establishments", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "table_limit", default: 50, null: false
    t.integer "monthly_fee_cents", default: 10000, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "production_areas_limit", default: 0, null: false
    t.string "plan", default: "essential", null: false
    t.boolean "accepting_orders", default: true, null: false
    t.datetime "service_paused_at"
    t.bigint "service_paused_by_user_id"
    t.boolean "google_reviews_enabled", default: false, null: false
    t.string "google_review_url"
    t.datetime "google_review_tracking_started_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "deleted_at"
    t.boolean "service_division_enabled", default: false, null: false
    t.index ["service_paused_by_user_id"], name: "index_establishments_on_service_paused_by_user_id"
    t.index ["slug"], name: "index_establishments_on_slug", unique: true
    t.check_constraint "plan::text = ANY (ARRAY['essential'::character varying::text, 'management'::character varying::text])", name: "valid_establishment_plan"
    t.check_constraint "production_areas_limit >= 0", name: "production_areas_limit_positive"
    t.check_constraint "table_limit >= 0 AND monthly_fee_cents >= 0", name: "establishment_limits_positive"
  end

  create_table "google_review_clicks", force: :cascade do |t|
    t.bigint "establishment_id", null: false
    t.string "visitor_digest", limit: 64, null: false
    t.datetime "created_at", null: false
    t.index ["establishment_id", "created_at", "visitor_digest"], name: "index_review_clicks_on_venue_date_visitor"
  end

  create_table "landing_requests", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "business_email", null: false
    t.string "phone", null: false
    t.string "region", null: false
    t.string "business_type", null: false
    t.string "status", default: "new", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "created_at"], name: "index_landing_requests_on_status_and_created_at"
  end

  create_table "lunch_menus", force: :cascade do |t|
    t.bigint "establishment_id", null: false
    t.boolean "active", default: false, null: false
    t.jsonb "weekdays", default: [1, 2, 3, 4, 5], null: false
    t.time "starts_at", default: "2000-01-01 12:00:00", null: false
    t.time "ends_at", default: "2000-01-01 15:00:00", null: false
    t.boolean "individual_enabled", default: true, null: false
    t.boolean "combo_enabled", default: false, null: false
    t.decimal "combo_price", precision: 8, scale: 2, default: "12.0", null: false
    t.jsonb "individual_offers", default: [], null: false
    t.jsonb "combo_groups", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "menu_kind", default: "lunch", null: false
    t.string "title"
    t.jsonb "group_definitions", default: [], null: false
    t.boolean "groups_configured", default: false, null: false
    t.index ["establishment_id", "menu_kind"], name: "index_lunch_menus_on_establishment_id_and_menu_kind", unique: true
  end

  create_table "menu_item_recommendations", force: :cascade do |t|
    t.bigint "menu_item_id", null: false
    t.bigint "recommended_menu_item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_item_id", "recommended_menu_item_id"], name: "unique_menu_item_recommendation", unique: true
    t.index ["menu_item_id"], name: "index_menu_item_recommendations_on_menu_item_id"
    t.index ["recommended_menu_item_id"], name: "index_menu_item_recommendations_on_recommended_menu_item_id"
    t.check_constraint "menu_item_id <> recommended_menu_item_id", name: "recommendation_cannot_reference_itself"
  end

  create_table "menu_items", force: :cascade do |t|
    t.string "name"
    t.decimal "price"
    t.boolean "available", default: true, null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.datetime "archived_at"
    t.bigint "production_area_id"
    t.jsonb "allergens", default: [], null: false
    t.string "allergen_notes", limit: 500
    t.boolean "nutrition_enabled", default: false, null: false
    t.string "nutrition_basis", default: "100g", null: false
    t.string "nutrition_portion", limit: 100
    t.decimal "nutrition_energy", precision: 8, scale: 2
    t.decimal "nutrition_fat", precision: 8, scale: 2
    t.decimal "nutrition_saturated", precision: 8, scale: 2
    t.decimal "nutrition_carbs", precision: 8, scale: 2
    t.decimal "nutrition_sugar", precision: 8, scale: 2
    t.decimal "nutrition_protein", precision: 8, scale: 2
    t.decimal "nutrition_fibre", precision: 8, scale: 2
    t.decimal "nutrition_salt", precision: 8, scale: 2
    t.string "product_kind", default: "unclassified", null: false
    t.boolean "normal_menu_visible", default: true, null: false
    t.string "preparation_key", default: "counter", null: false
    t.index ["archived_at"], name: "index_menu_items_on_archived_at"
    t.index ["category_id"], name: "index_menu_items_on_category_id"
    t.index ["production_area_id"], name: "index_menu_items_on_production_area_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "menu_item_id"
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
    t.integer "paid_quantity", default: 0, null: false
    t.jsonb "lunch_selection", default: {}, null: false
    t.index ["menu_item_id"], name: "index_order_items_on_menu_item_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["paid_quantity"], name: "index_order_items_on_paid_quantity"
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
    t.datetime "paid_at"
    t.bigint "paid_by_user_id"
    t.datetime "cancelled_at"
    t.string "cancellation_reason"
    t.datetime "voided_at"
    t.bigint "voided_by_user_id"
    t.bigint "table_visit_id"
    t.index ["cancelled_at"], name: "index_orders_on_cancelled_at"
    t.index ["customer_token"], name: "index_orders_on_customer_token"
    t.index ["paid_by_user_id"], name: "index_orders_on_paid_by_user_id"
    t.index ["table_id", "customer_token", "submission_token"], name: "unique_customer_submission", unique: true
    t.index ["table_id", "paid_at"], name: "index_orders_on_table_id_and_paid_at"
    t.index ["table_id"], name: "index_orders_on_table_id"
    t.index ["table_visit_id"], name: "index_orders_on_table_visit_id"
    t.index ["voided_at"], name: "index_orders_on_voided_at"
    t.index ["voided_by_user_id"], name: "index_orders_on_voided_by_user_id"
  end

  create_table "payment_items", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.bigint "order_item_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_item_id"], name: "index_payment_items_on_order_item_id"
    t.index ["payment_id"], name: "index_payment_items_on_payment_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "user_id", null: false
    t.string "payment_method", default: "cash", null: false
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "paid_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "voided_at"
    t.bigint "voided_by_user_id"
    t.string "void_reason"
    t.index ["order_id", "paid_at"], name: "index_payments_on_order_id_and_paid_at"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["user_id"], name: "index_payments_on_user_id"
    t.index ["voided_at"], name: "index_payments_on_voided_at"
    t.index ["voided_by_user_id"], name: "index_payments_on_voided_by_user_id"
    t.check_constraint "payment_method::text = ANY (ARRAY['cash'::character varying::text, 'card'::character varying::text, 'mbway'::character varying::text, 'other'::character varying::text])", name: "valid_payment_method"
  end

  create_table "preparation_tasks", force: :cascade do |t|
    t.bigint "order_item_id", null: false
    t.bigint "production_area_id"
    t.string "name", null: false
    t.string "component_key", null: false
    t.string "state", default: "preparing", null: false
    t.integer "quantity", null: false
    t.datetime "ready_at"
    t.datetime "delivered_at"
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_item_id", "component_key"], name: "index_preparation_tasks_on_order_item_id_and_component_key", unique: true
    t.index ["order_item_id"], name: "index_preparation_tasks_on_order_item_id"
    t.index ["production_area_id"], name: "index_preparation_tasks_on_production_area_id"
    t.index ["updated_by_id"], name: "index_preparation_tasks_on_updated_by_id"
  end

  create_table "production_area_users", id: false, force: :cascade do |t|
    t.bigint "production_area_id", null: false
    t.bigint "user_id", null: false
    t.index ["production_area_id", "user_id"], name: "index_production_area_users_on_production_area_id_and_user_id", unique: true
    t.index ["production_area_id"], name: "index_production_area_users_on_production_area_id"
    t.index ["user_id"], name: "index_production_area_users_on_user_id"
  end

  create_table "production_areas", force: :cascade do |t|
    t.bigint "establishment_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "preparation_key", default: "counter", null: false
    t.index ["establishment_id", "name"], name: "index_production_areas_on_establishment_id_and_name", unique: true
    t.index ["establishment_id"], name: "index_production_areas_on_establishment_id"
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
    t.index ["table_id"], name: "one_open_call_per_table", unique: true, where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('claimed'::character varying)::text]))"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'claimed'::character varying::text, 'resolved'::character varying::text])", name: "valid_service_call_status"
  end

  create_table "service_zones", force: :cascade do |t|
    t.bigint "establishment_id", null: false
    t.string "name", null: false
    t.jsonb "routing", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["establishment_id", "name"], name: "index_service_zones_on_establishment_id_and_name", unique: true
    t.index ["establishment_id"], name: "index_service_zones_on_establishment_id"
  end

  create_table "staff_push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "endpoint", null: false
    t.text "p256dh", null: false
    t.text "auth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_staff_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_staff_push_subscriptions_on_user_id"
  end

  create_table "support_sessions", force: :cascade do |t|
    t.bigint "platform_admin_id", null: false
    t.bigint "establishment_id", null: false
    t.bigint "support_ticket_id"
    t.text "reason"
    t.datetime "started_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["establishment_id"], name: "index_support_sessions_on_establishment_id"
    t.index ["platform_admin_id", "ended_at"], name: "index_support_sessions_on_platform_admin_id_and_ended_at"
    t.index ["platform_admin_id"], name: "index_support_sessions_on_platform_admin_id"
    t.index ["support_ticket_id"], name: "index_support_sessions_on_support_ticket_id"
  end

  create_table "support_ticket_messages", force: :cascade do |t|
    t.bigint "support_ticket_id", null: false
    t.bigint "author_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_support_ticket_messages_on_author_id"
    t.index ["support_ticket_id"], name: "index_support_ticket_messages_on_support_ticket_id"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.bigint "establishment_id", null: false
    t.bigint "created_by_id", null: false
    t.bigint "assigned_to_id"
    t.string "subject", null: false
    t.string "category", default: "other", null: false
    t.string "priority", default: "normal", null: false
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_support_tickets_on_assigned_to_id"
    t.index ["created_by_id"], name: "index_support_tickets_on_created_by_id"
    t.index ["establishment_id", "status"], name: "index_support_tickets_on_establishment_id_and_status"
    t.index ["establishment_id"], name: "index_support_tickets_on_establishment_id"
    t.check_constraint "priority::text = ANY (ARRAY['normal'::character varying::text, 'urgent'::character varying::text])", name: "valid_support_ticket_priority"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'in_analysis'::character varying::text, 'waiting_establishment'::character varying::text, 'resolved'::character varying::text])", name: "valid_support_ticket_status"
  end

  create_table "table_visits", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.datetime "requested_at"
    t.datetime "opened_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["table_id"], name: "index_table_visits_on_table_id"
    t.index ["table_id"], name: "one_current_visit_per_table", unique: true, where: "(closed_at IS NULL)"
  end

  create_table "tables", force: :cascade do |t|
    t.integer "number"
    t.string "qr_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "establishment_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.bigint "service_zone_id"
    t.index ["deleted_at"], name: "index_tables_on_deleted_at"
    t.index ["establishment_id", "number"], name: "index_tables_on_establishment_id_and_number", unique: true, where: "(deleted_at IS NULL)"
    t.index ["establishment_id"], name: "index_tables_on_establishment_id"
    t.index ["qr_token"], name: "index_tables_on_qr_token", unique: true
    t.index ["service_zone_id"], name: "index_tables_on_service_zone_id"
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
    t.string "username"
    t.boolean "must_change_password", default: false, null: false
    t.datetime "deleted_at"
    t.string "service_role", default: "floor", null: false
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["establishment_id"], name: "index_users_on_establishment_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "establishments"
  add_foreign_key "audit_events", "users"
  add_foreign_key "cash_closures", "establishments"
  add_foreign_key "cash_closures", "users"
  add_foreign_key "cash_closures", "users", column: "reopened_by_user_id"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "establishments"
  add_foreign_key "establishments", "users", column: "service_paused_by_user_id"
  add_foreign_key "google_review_clicks", "establishments"
  add_foreign_key "lunch_menus", "establishments"
  add_foreign_key "menu_item_recommendations", "menu_items"
  add_foreign_key "menu_item_recommendations", "menu_items", column: "recommended_menu_item_id"
  add_foreign_key "menu_items", "categories"
  add_foreign_key "menu_items", "production_areas"
  add_foreign_key "order_items", "menu_items", on_delete: :nullify
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "table_visits"
  add_foreign_key "orders", "tables"
  add_foreign_key "orders", "users", column: "paid_by_user_id"
  add_foreign_key "orders", "users", column: "voided_by_user_id"
  add_foreign_key "payment_items", "order_items"
  add_foreign_key "payment_items", "payments"
  add_foreign_key "payments", "orders"
  add_foreign_key "payments", "users"
  add_foreign_key "payments", "users", column: "voided_by_user_id"
  add_foreign_key "preparation_tasks", "order_items"
  add_foreign_key "preparation_tasks", "production_areas"
  add_foreign_key "preparation_tasks", "users", column: "updated_by_id"
  add_foreign_key "production_area_users", "production_areas"
  add_foreign_key "production_area_users", "users"
  add_foreign_key "production_areas", "establishments"
  add_foreign_key "service_calls", "tables"
  add_foreign_key "service_calls", "users", column: "assigned_user_id"
  add_foreign_key "service_zones", "establishments"
  add_foreign_key "staff_push_subscriptions", "users"
  add_foreign_key "support_sessions", "establishments"
  add_foreign_key "support_sessions", "support_tickets"
  add_foreign_key "support_sessions", "users", column: "platform_admin_id"
  add_foreign_key "support_ticket_messages", "support_tickets"
  add_foreign_key "support_ticket_messages", "users", column: "author_id"
  add_foreign_key "support_tickets", "establishments"
  add_foreign_key "support_tickets", "users", column: "assigned_to_id"
  add_foreign_key "support_tickets", "users", column: "created_by_id"
  add_foreign_key "table_visits", "tables"
  add_foreign_key "tables", "establishments"
  add_foreign_key "tables", "service_zones"
  add_foreign_key "users", "establishments"
end
