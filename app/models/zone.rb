class Zone < ApplicationRecord
  belongs_to :ancestor, class_name: Zone.name
  has_many :children, class_name: Zone.name, foreign_key: 'ancestor_id'

  scope :intersects, ->(geom) { where('ST_Intersects(geom, ?)', geom) }
  scope :property_filters, ->(filters) { where('properties @> ?::jsonb', filters.to_json) }

  def self.recursive_children_level(zones, levels)
    # TIP: loop directly with recursive SQL query to improve perf
    prev_zones = zones
    1.upto(levels).collect do |_|
      curr_zones = prev_zones.collect(&:children).flatten
      prev_zones = curr_zones
      curr_zones
    end.flatten.uniq(&:id)
  end
end
