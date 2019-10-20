require 'swagger_helper'

describe 'Zones V1 API', type: :request do
  path '/v1/zones' do
    get 'Retrieves Zones' do
      tags 'Zone'
      produces 'application/json'
      parameter name: :bbox, in: :query, type: :string, description: 'Result limited to bbox defined by four float numbers coma delimited (longitude, latitude). Default no limit.'
      parameter name: :with_geom, in: :query, type: :boolean, description: 'Include or not the geometry part in the result. Default: true'
      parameter name: :children_level, in: :query, type: :integer, description: 'Recursive level of children included. Default 0.'
      parameter name: :property_filters, in: :query, type: :json, description: 'Select zones matching all the filters. Default none'

      response '200', 'Zone found' do
        schema type: :object,
               properties: {
                 type: { type: :string }
               },
               required: %w[type]

        Zone.create.id
        run_test!
      end
    end
  end

  path '/v1/zones/{id}' do
    get 'Retrieves a Zone' do
      tags 'Zone'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer
      parameter name: :with_geom, in: :query, type: :boolean, description: 'Include or not the geometry part in the result. Default: true'
      parameter name: :children_level, in: :query, type: :integer, description: 'Recursive level of children included,. Default 0.'

      response '200', 'Zone found' do
        schema type: :object,
               properties: {
                 type: { type: :string }
               },
               required: %w[type]

        let(:id) { Zone.create.id }
        run_test!
      end

      response '404', 'Zone not found' do
        let(:id) { 666 }
        run_test!
      end
    end
  end
end
