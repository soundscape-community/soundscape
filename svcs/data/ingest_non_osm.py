# Copyright (c) Soundscape Community.
# Licensed under the MIT License.
"""
Defines methods used by ingest.py to populate the non_osm_data table.

If invoked directly, the script will rebuild the non_osm_data table without
reimporting the whole planet. This still needs to run inside an ingest
container, e.g.

  $ docker-compose exec ingest python3 /ingest/ingest_non_osm.py
"""
import os
import csv
import asyncio
import logging

import aiopg

from kubescape import SoundscapeKube

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s:%(levelname)s:%(message)s')
logger = logging.getLogger()


async def provision_non_osm_data_async(osm_dsn):
    # Create a table into which we can load extra (non-OSM) data from CSV.
    async with aiopg.connect(dsn=osm_dsn) as conn:
        cursor = await conn.cursor()
        await cursor.execute(
            """CREATE TABLE IF NOT EXISTS non_osm_data (
                id BIGSERIAL PRIMARY KEY,
                osm_id BIGINT,
                feature_type TEXT,
                feature_value TEXT,
                properties HSTORE,
                geom GEOMETRY(Point, 4326)
            )"""
        )
        # Remove any existing data
        await cursor.execute("TRUNCATE non_osm_data")


async def import_non_osm_data_async(csv_dir, osm_dsn, logger):
    # The client expects OSM IDs for every point, but this is not OSM data.
    # Assign large positive OSM IDs, which will not conflict with real values.
    # Discussion: https://github.com/soundscape-community/soundscape/pull/135#issuecomment-2665868581
    osm_id = 10**17

    async with aiopg.connect(dsn=osm_dsn) as conn:
        cursor = await conn.cursor()

        # Remove any existing data
        await cursor.execute("TRUNCATE non_osm_data")

        for csv_path in os.listdir(csv_dir):
            with open(os.path.join(csv_dir, csv_path), encoding="utf8") as f:
                rowcount = 0
                for row in csv.DictReader(f):
                    rowcount += 1
                    osm_id += 1

                    # After removing required columns, the remaining fields in
                    # the row will be stored in the item's properties field.
                    feat_type = row.pop("feature_type")
                    feat_value = row.pop('feature_value')
                    long = float(row.pop("longitude"))
                    lat = float(row.pop("latitude"))
                    props = row

                    await cursor.execute(
                        """INSERT INTO non_osm_data
                        (osm_id, feature_type, feature_value, properties, geom)
                        VALUES
                        (%s, %s, %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326))""", (
                            osm_id, feat_type, feat_value, props, long, lat
                        )
                    )

                logger.info(
                    "Loaded {0} rows from {1}".format(rowcount, csv_path))


def import_non_osm_data(csv_dir, osm_dsn, logger):
    loop = asyncio.get_event_loop()
    loop.run_until_complete(import_non_osm_data_async(csv_dir, osm_dsn, logger))


if __name__ == "__main__":
    namespace = os.environ['NAMESPACE']
    kube = SoundscapeKube(None, namespace)
    import_non_osm_data(
        csv_dir="/non_osm_data",
        osm_dsn=kube.databases["osm"]["dsn2"],
        logger=logger
    )