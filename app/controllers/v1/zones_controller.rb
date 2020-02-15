class V1::ZonesController < ApplicationController
  before_action :validate_params

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveModel::ValidationError, with: :validation_error

  def index
    zones = Zone.where(nil)
    zones = zones.intersects(@query.bbox)
    zones = zones.intersects(@query.intersect)
    zones = zones.property_filters(@query.property_filters) unless @query.property_filters.empty?

    zones = apply_query(zones, @query.bbox, @query.intersect)
    render json: to_geojson(zones)
  end

  def show
    zone = Zone.find(params[:id])

    zones = apply_query([zone])
    render json: to_geojson(zones)
  end

  ActionController::Parameters.action_on_unpermitted_parameters = :raise

  rescue_from(ActionController::UnpermittedParameters) do |pme|
    render status: :bad_request, json: {
      error: { unknown_parameters: pme.params }
    }
  end

  private

  def validate_params
    params.permit(:id, :bbox, :intersect, :with_geom, :children_level, :property_filters)

    @query = Validate::Query.new(params)
    @query.validate!
  end

  def apply_query(zones, bbox = nil, intersect = nil)
    if @query.children_level.positive?
      zones += Zone.recursive_children_level(zones, @query.children_level, bbox, intersect)
      zones.uniq!
    end

    zones.each { |z| z.geom = nil } unless @query.with_geom

    zones
  end

  def to_geojson(zones)
    if zones.size == 1
      zones[0]
    else
      {
        'type': 'FeatureCollection',
        'features': zones.collect do |z|
          ActiveModelSerializers::SerializableResource.new(z)
        end
      }
    end
  end

  def record_not_found(error)
    render json: { error: error.message }, status: :not_found
  end

  def validation_error(error)
    render json: { error: error.message }, status: :bad_request
  end
end

module Validate
  # Validate and convert URL query pramters.
  class Query
    include ActiveModel::Validations

    attr_accessor :bbox, :intersect, :with_geom, :children_level, :property_filters

    validate :bbox_validation
    validate :intersect_validation
    validate :property_filters_validation
    validates :with_geom, inclusion: [true, false]
    validates :children_level, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 3
    }

    def initialize(params = {})
      @bbox = params[:bbox]
      @intersect = params[:intersect]
      @with_geom = !params[:with_geom].present? || params[:with_geom] == 'true'
      @children_level = params[:children_level].to_i
      @property_filters = params[:property_filters] || {}
    end

    private

    def bbox_validation
      return unless @bbox.is_a?(String)

      coords = @bbox.split(',')
      if coords.size != 4
        errors.add(:bbox, 'should be 4 floating numbers, comma separated')
        return
      else
        all_float = coords.all? do |c|
          true if Float(c) rescue false
        end
        if !all_float
          errors.add(:bbox, 'should be 4 floating numbers, comma separated')
          return
        end
      end

      x1, y1, x2, y2 = coords.collect(&:to_f)
      @bbox = RGeo::Cartesian::BoundingBox.create_from_points(
        RGeo::Cartesian.factory(srid: 4326).point(x1, y1),
        RGeo::Cartesian.factory(srid: 4326).point(x2, y2)
      ).to_geometry
    end

    def intersect_validation
      return unless @intersect.is_a?(String)

      factory = RGeo::Cartesian.factory(srid: 4326)
      geojson = RGeo::GeoJSON.decode(@intersect, geo_factory: factory)

      @intersect = if geojson.is_a?(RGeo::GeoJSON::FeatureCollection)
        factory.collection(geojson.map{ |feature| feature.geometry })
      else
        geojson.geometry
      end
    rescue JSON::ParserError
      errors.add(:intersect, 'should be a valid geojson')
    end

    def property_filters_validation
      return unless @property_filters.is_a?(String)

      @property_filters = JSON.parse(@property_filters)
    rescue JSON::ParserError
      errors.add(:property_filters, 'should be a valid json dictionary')
    end
  end
end
