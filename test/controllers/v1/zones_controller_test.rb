require 'test_helper'

class V1::ZonesControllerTest < ActionDispatch::IntegrationTest
  test 'get zone' do
    zone = zones(:one)
    get v1_zone_url(zone)
    assert_response :success

    properties = zone.attributes.except('created_at', 'updated_at', 'properties', 'geom').merge(zone.properties)
    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert_equal properties, geojson['properties']
    assert !geojson['geometry']['coordinates'].empty?

    geom = RGeo::GeoJSON.decode(response.body)
    assert geom
    assert_equal zone.geom, geom.geometry
  end

  test 'get no zone' do
    get v1_zone_url(666)
    assert_response :not_found
  end

  test 'get zone without geom' do
    zone = zones(:one)
    get v1_zone_url(zone, with_geom: 'false')
    assert_response :success

    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert_nil geojson['geometry']

    geom = RGeo::GeoJSON.decode(response.body)
    assert geom
  end

  test 'index' do
    get v1_zones_url(with_geom: 'false')
    assert_response :success

    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert geojson['features'].size > 0

    geom = RGeo::GeoJSON.decode(response.body)
    assert geom
    assert geom.size > 0
  end

  test 'index without geom' do
    get v1_zones_url(with_geom: 'false')
    assert_response :success

    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert_nil geojson['features'][0]['geometry']

    geom = RGeo::GeoJSON.decode(response.body)
    assert geom
    assert geom.size > 0
  end

  test 'index recursive children' do
    get v1_zones_url(children_level: 99)
    assert_response :success

    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert_equal 2, geojson['features'].size, geojson['features']

    geom = RGeo::GeoJSON.decode(response.body)
    assert geom
    assert_equal 2, geom.size
  end

  test 'index bbox 1' do
    get v1_zones_url(bbox: '1,1,2,2')
    assert_response :success

    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert_equal 0, geojson['features'].size, geojson['features']
  end

  test 'index bbox 2' do
    get v1_zones_url(bbox: '1.3417,42.3093,1.8471,42.7531')
    assert_response :success

    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert_equal 2, geojson['features'].size, geojson['features']
  end

  test 'index invalid bbox' do
    get v1_zones_url(bbox: 'a,42.3093,1.8471,42.7531')
    assert_response :bad_request
  end

  test 'index property_filters' do
    get v1_zones_url(property_filters: { nature: :country }.to_json)
    assert_response :success

    geojson = ActiveSupport::JSON.decode(response.body)
    assert geojson, response.body
    assert_equal 'Feature', geojson['type'], geojson
  end

  test 'index invalid property_filters' do
    get v1_zones_url(property_filters: '{"plop')
    assert_response :bad_request
  end
end
