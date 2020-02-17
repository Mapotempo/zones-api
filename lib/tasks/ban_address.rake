namespace :ban_addresses do
  desc "Import adresses from ndjson addok format"
  task :import, [:addok_ndjson_gz] => [:environment] do |task, args|
    # {"id":"01162_0062","type":"street","lon":5.736647,"lat":45.809157,"x":912489.14,"y":6526963.17,"importance":0.19356005054539455,
    # "housenumbers":{"9":{"id":"01162_0062_00009","x":912489.14,"y":6526963.17,"lon":5.736647,"lat":45.809157}}},
    # "name":"Che des Grands Hautains","postcode":"01350","citycode":["01162"],"city":["Flaxieu"],"context":"01, Ain, Auvergne-Rhône-Alpes"}
    sql = %{
      CREATE TEMP TABLE impost_json(j jsonb);
      COPY impost_json FROM STDIN;
      INSERT INTO zones(name, properties, source, created_at, updated_at, geom)
      SELECT
        (jsonb_each(j->'housenumbers')).key::text AS name,
        jsonb_build_object(
          'number', (jsonb_each(j->'housenumbers')).key,
          'street', j->'name',
          'postcode', j->'postcode',
          'city', j->'city'->>0,
          'citycode', j->'citycode'->>0
        ) AS properties,
        'BAN' AS source,
        now() AS created_at,
        now() AS updated_at,
        ST_SetSRID(ST_MakePoint(
          ((jsonb_each(j->'housenumbers')).value->'lon')::numeric,
          ((jsonb_each(j->'housenumbers')).value->'lat')::numeric
        ), 4326) AS geom
      FROM
        impost_json
      WHERE
        j->>'type' = 'street'
      ;
    }

    infile = open(args[:addok_ndjson_gz])
    # Use MultipleFilesGzipReader to support concatened gzip file from adresse.data.gouv.fr
    gz = MultipleFilesGzipReader.new(infile)

    dbconn = ActiveRecord::Base.connection
    raw = dbconn.raw_connection

    raw.copy_data(sql) do
      index = 0
      gz.each_line do |line|
        puts index if index % 100_000 == 0
        index += 1

        raw.put_copy_data line.gsub('\\"', '')
      end
      puts index
      puts "End of input file"
    end
  end

  desc "Make adresses children of city"
  task parenthood: :environment do |task, args|
    sql = %{
      UPDATE
        zones
      SET
        ancestor_id = p.id
      FROM
        zones AS p
      WHERE
        zones.ancestor_id IS NULL AND
        zones.source = 'BAN' AND
        ST_Intersects(p.geom, zones.geom)
        ;
    }
    ActiveRecord::Base.connection.execute(sql)
  end

  desc "Delete adresses with souce=BAN"
  task delete: :environment do |task, args|
    sql = "DELETE FROM zones WHERE source = 'BAN'"
    ActiveRecord::Base.connection.execute(sql)
  end
end
