# Copyright (c) Soundscape Community Contributors.
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
import contextlib
import logging

import aiopg
import psycopg2.extensions

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s:%(levelname)s:%(message)s')
logger = logging.getLogger()


async def create_non_osm_data_table_async(cursor):
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


async def provision_non_osm_data_async(osm_dsn):
    # Create a table into which we can load extra (non-OSM) data from CSV.
    async with aiopg.connect(dsn=osm_dsn) as conn:
        cursor = await conn.cursor()
        await create_non_osm_data_table_async(cursor)


async def import_non_osm_data_async(csv_dir, osm_dsn, logger):
    # The client expects OSM IDs for every point, but this is not OSM data.
    # Assign large positive OSM IDs, which will not conflict with real values.
    # Discussion: https://github.com/soundscape-community/soundscape/pull/135#issuecomment-2665868581
    osm_id = 10**17
    failures = []

    async with aiopg.connect(dsn=osm_dsn) as conn:
        cursor = await conn.cursor()
        await cursor.execute("BEGIN")
        try:
            await create_non_osm_data_table_async(cursor)
            await cursor.execute("TRUNCATE non_osm_data")

            for csv_path in sorted(os.listdir(csv_dir)):
                full_path = os.path.join(csv_dir, csv_path)
                if not os.path.isfile(full_path) or not csv_path.lower().endswith(".csv"):
                    continue

                await cursor.execute("SAVEPOINT non_osm_file")
                try:
                    with open(full_path, encoding="utf8") as f:
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

                    await cursor.execute("RELEASE SAVEPOINT non_osm_file")
                    logger.info(
                        "Loaded {0} rows from {1}".format(rowcount, csv_path))
                except Exception as exc:
                    with contextlib.suppress(Exception):
                        await cursor.execute("ROLLBACK TO SAVEPOINT non_osm_file")
                    with contextlib.suppress(Exception):
                        await cursor.execute("RELEASE SAVEPOINT non_osm_file")
                    failures.append((csv_path, exc))
                    logger.exception("Failed to load non-OSM data from %s", csv_path)

            await cursor.execute("COMMIT")
        except Exception:
            with contextlib.suppress(Exception):
                await cursor.execute("ROLLBACK")
            raise

    if failures:
        details = "; ".join(
            f"{path}: {type(exc).__name__}: {exc}"
            for path, exc in failures
        )
        raise RuntimeError(
            f"Failed to import {len(failures)} non-OSM CSV file(s); "
            f"successful files were committed. {details}"
        )


def import_non_osm_data(csv_dir, osm_dsn, logger):
    asyncio.run(import_non_osm_data_async(csv_dir, osm_dsn, logger))


def build_postgres_dsn():
    host = os.environ.get("POSTGIS_HOST", "localhost")
    port = os.environ.get("POSTGIS_PORT", "5432")
    user = os.environ.get("POSTGIS_USER", "osm")
    password = os.environ.get("POSTGIS_PASSWORD", "osm")
    dbname = os.environ.get("POSTGIS_DBNAME", "osm")
    return psycopg2.extensions.make_dsn(
        host=host,
        port=port,
        user=user,
        password=password,
        dbname=dbname,
    )


if __name__ == "__main__":
    import_non_osm_data(
        csv_dir="/non_osm_data",
        osm_dsn=os.environ.get("DSN") or build_postgres_dsn(),
        logger=logger
    )
