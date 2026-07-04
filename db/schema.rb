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

ActiveRecord::Schema[8.1].define(version: 2026_07_04_121000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "ingredients", force: :cascade do |t|
    t.jsonb "aliases", default: [], null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "optional", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_ingredients_on_aliases", using: :gin
    t.index ["name"], name: "index_ingredients_on_name", unique: true
    t.index ["optional"], name: "index_ingredients_on_optional"
    t.check_constraint "jsonb_typeof(aliases) = 'array'::text", name: "ingredients_aliases_json_array"
  end

  create_table "maintenance_tasks_runs", force: :cascade do |t|
    t.text "arguments"
    t.text "backtrace"
    t.datetime "created_at", null: false
    t.string "cursor"
    t.boolean "cursor_is_json", default: false, null: false
    t.datetime "ended_at"
    t.string "error_class"
    t.string "error_message"
    t.string "job_id"
    t.integer "lock_version", default: 0, null: false
    t.text "metadata"
    t.datetime "started_at"
    t.string "status", default: "enqueued", null: false
    t.string "task_name", null: false
    t.bigint "tick_count", default: 0, null: false
    t.bigint "tick_total"
    t.float "time_running", default: 0.0, null: false
    t.datetime "updated_at", null: false
    t.index ["task_name", "status", "created_at"], name: "index_maintenance_tasks_runs", order: { created_at: :desc }
  end

  create_table "recipes", force: :cascade do |t|
    t.string "author", default: "", null: false
    t.string "category", default: "", null: false
    t.string "category_normalized", default: "", null: false
    t.integer "cook_time", null: false
    t.datetime "created_at", null: false
    t.string "cuisine", default: "", null: false
    t.text "image", null: false
    t.text "ingredient_names", default: [], null: false, array: true
    t.jsonb "ingredient_parse_data", default: [], null: false
    t.jsonb "ingredients", default: [], null: false
    t.vector "ingredients_vector", limit: 384
    t.integer "prep_time", null: false
    t.decimal "ratings", precision: 4, scale: 2, null: false
    t.string "source_key", null: false
    t.integer "source_position", null: false
    t.string "title", null: false
    t.virtual "title_search_vector", type: :tsvector, as: "to_tsvector('english'::regconfig, (COALESCE(title, ''::character varying))::text)", stored: true
    t.integer "total_time", null: false
    t.datetime "updated_at", null: false
    t.index ["category_normalized"], name: "index_recipes_on_category_normalized"
    t.index ["ingredient_names"], name: "index_recipes_on_ingredient_names", using: :gin
    t.index ["ingredients_vector"], name: "index_recipes_on_ingredients_vector", opclass: :vector_cosine_ops, where: "(ingredients_vector IS NOT NULL)", using: :hnsw
    t.index ["ratings"], name: "index_recipes_on_ratings"
    t.index ["source_key"], name: "index_recipes_on_source_key", unique: true
    t.index ["source_position"], name: "index_recipes_on_source_position", unique: true
    t.index ["title_search_vector"], name: "index_recipes_on_title_search_vector", using: :gin
    t.index ["total_time"], name: "index_recipes_on_total_time"
  end
end
