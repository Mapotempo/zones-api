class CreateZones < ActiveRecord::Migration[6.0]
  def change
    create_table :zones do |t|
      t.references :ancestor, null: true, foreign_key: {to_table: :zones}
      t.string :name
      t.jsonb :properties, null: false, default: '{}'
      t.string :source
      t.geometry :geom, srid: 4326

      t.timestamps
    end

    add_index :zones, :geom, using: :gist
    add_index :zones, :properties, using: :gin
  end
end
