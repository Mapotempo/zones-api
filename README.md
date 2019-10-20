# Zones API

[![Build Status](https://api.travis-ci.org/frodrigo/zones-api.svg?branch=master)](https://travis-ci.org/frodrigo/zones-api)

Backend API to store and retrieve zone polygons based on arbitrary geometry like administrative or survey data.

## Install

```
rails db:create
rails db:setup
```

## Usage

Start the web server with:
```
bundle exec rails server
```
The service is now available at http://localhost:3000 and the Swagger UI at http://localhost:3000/api-docs/index.html.


### API

The only two API endpoints are:

* Fetch zone by id
* Fetch multiple zones selected by parameters

The returns are always geojson.

On all the endpoint the commons parameters are:

* `with_geom`: include of not the geometries in the geojson.
* `children_level`: recursively include children of the zone and how much level.

The fetch multiple also have the following parameters:

* `bbox`: restrict zones selection this bounding box. Does not affect the recessive children.
* `property_filters`: restrict zones selection the one having all this properties. Does not affect the recessive children.

### Examples

#### Fetch one zone by id without geometry

```
curl -X GET "http://localhost:3000/v1/zones/5?with_geom=false" -H  "accept: application/json"
```

```json
{
  "type": "Feature",
  "properties": {
    "id": 5,
    "ancestor_id": 37666,
    "name": "Marne",
    "source": "OpenStreetMap",
    "nature": "state_district",
    "admin_level": 6
  },
  "geometry": null
}
```

#### Fetch one zone by id without geometry, but with first level children

```
curl -X GET "http://localhost:3000/v1/zones/5?with_geom=false&children_level=1" -H  "accept: application/json"
```

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "id": 5,
        "ancestor_id": 37666,
        "name": "Marne",
        "source": "OpenStreetMap",
        "nature": "state_district",
        "admin_level": 6
      },
      "geometry": null
    },
    {
      "type": "Feature",
      "properties": {
        "id": 344,
        "ancestor_id": 5,
        "name": "Cormontreuil",
        "source": "OpenStreetMap",
        "nature": "city",
        "admin_level": 8
      },
      "geometry": null
    },
    {
      "type": "Feature",
      "properties": {
        "id": 345,
        "ancestor_id": 5,
        "name": "Reims",
        "source": "OpenStreetMap",
        "nature": "city",
        "admin_level": 8
      },
      "geometry": null
    },
    ...
  ]
}
```

### Fetch one zone filter by location and property

Using filter `bbox=1.8471,48.7531,1.8471,48.7531` reduced to one point and `property_filters={"admin_level": 6}`.

```
curl -X GET "http://localhost:3000/v1/zones?bbox=1.8471%2C48.7531%2C1.8471%2C48.7531&with_geom=false&property_filters=%7B%22admin_level%22%3A%206%7D" -H  "accept: application/json"
```

```json
{
  "type": "Feature",
  "properties": {
    "id": 78,
    "ancestor_id": 90,
    "name": "Yvelines",
    "source": "OpenStreetMap",
    "nature": "state_district",
    "admin_level": 6
  },
  "geometry": null
}
```

## Dev

### Regenerated the spec API

Generate the OpenAPI spec
```
RAILS_ENV=test rake rswag:specs:swaggerize
```

### Tests

Test the models and API controllers
```
bundle exec rails test
```

Test the OpenAPI Spec
```
bundle exec rspec
```

## Load data from OpenStreetMap with Cosmogony

### Build Docker

Build Cosmogony Docker
```
git clone https://github.com/osm-without-borders/cosmogony.git
cd cosmogony
git submodule update --init
docker build -t osmwithoutborders/cosmogony .
```

Build Cosmogony Explorer Docker importer
```
git clone https://github.com/osm-without-borders/cosmogony_explorer.git
cd cosmogony_explorer
docker-compose -f docker-compose.yml -f docker-compose.build.yml build importer
```

### Extract data from OpenStreetMap

Download an OpenStreetMap extract:
```
mkdir data
# +4Go
wget http://download.openstreetmap.fr/extracts/europe/france-latest.osm.pbf -O data/france-latest.osm.pbf
```

Compute zones hierarchy with Cosmogony from `.osm.pbf`, save the result as `.json`:
```
# 4cpu, 68min, +390Mo
docker run -v `pwd`/data:/data osmwithoutborders/cosmogony -i /data/france-latest.osm.pbf -o /data/france-latest.json
```

Import the `.json` into Postgres:
```
docker-compose -f docker-compose.cosmogony.yml start postgres
sleep 60 # Cool, Waiting for postgres to be ready
# 14 min, 1cpu
docker-compose -f docker-compose.cosmogony.yml run --rm importer ./import.py import_data /data/france-latest.json
```

Export dump from Postgres:
```
docker-compose -f docker-compose.cosmogony.yml exec postgres psql -c "
COPY (
  SELECT
    id,
    parent AS ancestor_id,
    name AS name,
    json_build_object(
      'admin_level', admin_level,
      'nature', zone_type
    ) AS properties,
    'OpenStreetMap' AS source,
    ST_Transform(geometry, 4326) AS geometry,
    now() AS created_at,
    now() AS updated_at
  FROM import.zones
) TO stdout" cosmogony cosmogony | lz4 -3 > cosmogony.tsv.lz4
```

Load the dump into the Zones API:
```
lz4 -c cosmogony.tsv.lz4 | psql -c "COPY zones(id, ancestor_id, name, properties, source, geom, created_at, updated_at) FROM stdin" zone_api_development
```

## Docker

Build the docker image:
```
docker-compose build
```

Initialize the database:
```
docker-compose run web rake db:setup
```

Then load some data:
```
docker-compose exec web bash -c 'cat cosmogony.tsv | psql -c "COPY zones(id, ancestor_id, name, properties, source, geom, created_at, updated_at) FROM stdin" -h postgres zone_api_development postgres'
```
