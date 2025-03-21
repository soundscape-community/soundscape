## Loading non-OSM data into the backend

Drop CSV files matching the format of test_data.csv into the non_osm_data directory. The ingest service will pick up and load these during its next update. To trigger an immediate load, invoke the ingest_non_osm.py script manually within the ingest container, like so:

    $ docker-compose exec ingest python3 /ingest/ingest_non_osm.py
