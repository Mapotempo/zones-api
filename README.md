# Zones API

[![Build Status](https://api.travis-ci.org/frodrigo/zones-api.svg?branch=master)](https://travis-ci.org/frodrigo/zones-api)

Backend API to store and retrieve zone polygons based on arbitrary geometry like administrative or survey data.

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

* `with_geom`: include or not the geometries in the geojson.
* `children_level`: recursively include children of the zone and how much level.

The fetch multiple also have the following parameters:

* `bbox`: restrict zones selection this bounding box. Affect the recessive children.
* `intersect`: restrict zones selection to ones intersecting the GeoJSON geometry. Default no limit.'
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
curl -X GET "http://localhost:3000/v1/zones/5" -d with_geom=false -d children_level=1 -H  "accept: application/json"
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

Using filter `bbox=5.9718,49.8113,5.9718,49.8113` (in Luxembourg) reduced to one point and `property_filters={"admin_level": 6}`.

```
curl -X GET "http://localhost:3000/v1/zones" -d bbox=5.9718,49.8113,5.9718,49.8113 -d with_geom=false -d 'property_filters={"admin_level": 6}' -H  "accept: application/json"
```

```json
{
  "type": "Feature",
  "properties": {
    "id": 89,
    "ancestor_id": 181,
    "name": "Canton Redange",
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

## Install

### Build

From the Zones API project directory.

Build Zones API Docker image:
```
docker-compose build
```

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

### Setup

Initialize the Zones API database:
```
docker-compose up -d postgres && sleep 20
docker-compose run --rm web rake db:setup
```

## Load data from OpenStreetMap with Cosmogony

### Extract data from OpenStreetMap

Download an OpenStreetMap extract:
```
mkdir -p cosmogony_data
# Luxembourg +28 Mo
# France +4 Go
wget http://download.openstreetmap.fr/extracts/europe/luxembourg-latest.osm.pbf -O cosmogony_data/luxembourg-latest.osm.pbf
```

Compute zones hierarchy with Cosmogony from `.osm.pbf`, save the result as `.json`:
```
# Luxembourg 4 cpu, 40 s, +12 Mo
# France 4 cpu, 68 min, +390 Mo
docker run -v `pwd`/cosmogony_data:/data osmwithoutborders/cosmogony -i /data/luxembourg-latest.osm.pbf -o /data/luxembourg-latest.json
```

Import the `.json` into Postgres:
```
docker-compose -p cosmogony -f docker-compose.cosmogony.yaml up -d cosmogony_postgres
sleep 60 # Cool, Waiting for postgres to be ready
# Luxembourg 1 cpu, 11 s
# France 1 cpu, 14 min
docker-compose -p cosmogony -f docker-compose.cosmogony.yaml run --rm importer ./import.py import_data /data/luxembourg-latest.json
```

Export dump from Postgres, simplify using Lamber 93 projection (France, 2154):
```
docker-compose -p cosmogony -f docker-compose.cosmogony.yaml exec cosmogony_postgres psql -c "
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
    ST_Transform(
      ST_SimplifyPreserveTopology(
        ST_Transform(geometry, 2154),
        ST_MaxDistance(ST_Transform(geometry, 2154), ST_Transform(geometry, 2154)) / 500
      ),
      4326
    ) AS geometry,
    now() AS created_at,
    now() AS updated_at
  FROM import.zones
) TO stdout" cosmogony cosmogony > cosmogony_data/luxembourg_cosmogony.tsv
```

Stop the Cosmogony part:
```
docker-compose -p cosmogony -f docker-compose.cosmogony.yaml stop cosmogony_postgres
```

Load the dump into the Zones API:
```
docker-compose run --rm web bash -c "cat ./cosmogony_data/luxembourg_cosmogony.tsv | psql -h postgres -c \"
  COPY zones(id, ancestor_id, name, properties, source, geom, created_at, updated_at) FROM stdin;
  SELECT setval('zones_id_seq', (SELECT max(id) FROM zones));
\" zone_api_development postgres"
```

## Load adresses

Load adresses in Addok ndjson format. Download the French [BAN](https://adresse.data.gouv.fr/donnees-nationales) adresses data base.

```
# + 500 MB
wget https://adresse.data.gouv.fr/data/ban/adresses/latest/addok/adresses-addok-france.ndjson.gz -P addok_data/
```

Import an adresses file.
```
docker-compose -f docker-compose.yaml -f docker-compose.addok.yaml run --rm import_addok rake ban_addresses:import[/addok_data/adresses-addok-france.ndjson.gz]
```

Delete the imported addresses data.
```
docker-compose -f docker-compose.yaml -f docker-compose.addok.yaml run --rm import_addok rake ban_addresses:delete
```
