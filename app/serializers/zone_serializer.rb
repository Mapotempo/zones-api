class ZoneSerializer < ActiveModel::Serializer
    attributes :type, :properties, :geometry

    def type
        'Feature'
    end

    def properties
        object.attributes.except('created_at', 'updated_at', 'properties', 'geom').merge(object.properties)
    end

    def geometry
        RGeo::GeoJSON.encode(object.geom) if object.geom
    end
end
