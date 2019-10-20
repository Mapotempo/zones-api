# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_10_08_201905) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "zones", force: :cascade do |t|
    t.bigint "ancestor_id"
    t.string "name"
    t.jsonb "properties", default: "{}", null: false
    t.string "source"
    t.geometry "geom", limit: {:srid=>4326, :type=>"geometry"}
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["ancestor_id"], name: "index_zones_on_ancestor_id"
    t.index ["geom"], name: "index_zones_on_geom", using: :gist
    t.index ["properties"], name: "index_zones_on_properties", using: :gin
  end

  add_foreign_key "zones", "zones", column: "ancestor_id"
end
