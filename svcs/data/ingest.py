# Copyright (c) Microsoft Corporation.
# Copyright (c) Soundscape Community Contributors.
# Licensed under the MIT License.

import argparse
import asyncio
import contextlib
import fcntl
import json
import logging
import os
import subprocess
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import aiopg
import psycopg2
from prometheus_client import REGISTRY, Gauge, Histogram, start_http_server

from ingest_non_osm import import_non_osm_data, provision_non_osm_data_async


def existing_or_new_metric(factory, name: str, *args, **kwargs):
    try:
        return factory(name, *args, **kwargs)
    except ValueError:
        return REGISTRY._names_to_collectors[name]


event_duration = existing_or_new_metric(
    Histogram,
    "event_duration_seconds",
    "Duration of events",
    ["event_name"],
)
last_event_time = existing_or_new_metric(
    Gauge,
    "event_last_time",
    "Timestamp of last event occurrence",
    ["event_name"],
)

SECONDS_PER_DAY = 24 * 60 * 60
STATE_FILE = "ingest-state.json"
LOCK_FILE = "ingest.lock"

logger = logging.getLogger(__name__)


class PbfSyncError(RuntimeError):
    pass


class DbIngestError(RuntimeError):
    pass


class NonOsmIngestError(RuntimeError):
    pass


@dataclass
class IngestConfig:
    skipimport: bool
    sourceupdate: bool
    telemetry: bool
    interval_days: float
    retry_days: float
    extracts: str
    mapping: str
    imposm: str
    where: list[str]
    cachedir: str
    diffdir: str
    pbfdir: str
    expiredir: str
    extradatadir: str | None
    config: str
    provision: bool
    dsn_init: str
    dsn: str
    verbose: bool
    run_once: bool
    ntfy_topic: str | None
    ntfy_server: str
    ntfy_token: str | None
    ntfy_priority: str


def build_postgres_dsn(dbname: str) -> str:
    host = os.environ.get("POSTGIS_HOST", "localhost")
    port = os.environ.get("POSTGIS_PORT", "5432")
    user = os.environ.get("POSTGIS_USER", "osm")
    password = os.environ.get("POSTGIS_PASSWORD", "osm")
    return f"host={host} port={port} user={user} password={password} dbname={dbname}"


def default_osm_dsn() -> str:
    return build_postgres_dsn(os.environ.get("POSTGIS_DBNAME", "osm"))


def default_init_dsn() -> str:
    return build_postgres_dsn("postgres")


def env_float(name: str, default: float) -> float:
    value = os.environ.get(name)
    if value is None or value == "":
        return default
    return float(value)


def env_regions() -> list[str] | None:
    value = os.environ.get("GEN_REGION") or os.environ.get("GEN_REGIONS")
    if not value:
        return None
    return value.split()


def parse_args(argv=None) -> IngestConfig:
    parser = argparse.ArgumentParser(description="ingestion engine for Soundscape")

    parser.add_argument("--skipimport", action="store_true", help="skips import task", default=False)
    parser.add_argument("--sourceupdate", action="store_true", help="update source data", default=True)
    parser.add_argument("--no-sourceupdate", dest="sourceupdate", action="store_false", help="skip source data updates")
    parser.add_argument("--telemetry", action="store_true", help="generate telemetry")
    parser.add_argument("--interval-days", type=float, default=env_float("INGEST_INTERVAL_DAYS", 7))
    parser.add_argument("--retry-days", type=float, default=env_float("INGEST_RETRY_DAYS", 1))
    parser.add_argument("--run-once", action="store_true", help="run one ingest cycle and exit")

    parser.add_argument("--extracts", type=str, default="extracts.json", help="extracts file")
    parser.add_argument("--mapping", type=str, help="mapping file path", default="mapping.yml")
    parser.add_argument("--imposm", type=str, help="imposm executable", default="imposm")
    parser.add_argument("--where", metavar="region", nargs="+", type=str, default=env_regions(), help="area name")
    parser.add_argument("--cachedir", type=str, help="imposm temp directory", default="/tmp/imposm3")
    parser.add_argument("--diffdir", type=str, help="imposm diff directory", default="/tmp/imposm3_diffdir")
    parser.add_argument("--pbfdir", type=str, help="pbf directory", default=".")
    parser.add_argument("--expiredir", type=str, help="expired tiles directory", default="/tmp/imposm3_expiredir")
    parser.add_argument("--extradatadir", type=str, help="CSV containing extra data to import")
    parser.add_argument("--config", type=str, help="config file", default="config.json")
    parser.add_argument("--provision", help="provision the database", action="store_true", default=False)
    parser.add_argument("--dsn-init", dest="dsn_init", type=str, help="postgres dsn init", default=None)
    parser.add_argument("--dsn", type=str, help="postgres dsn", default=None)
    parser.add_argument("--verbose", action="store_true", help="verbose")

    parser.add_argument("--ntfy-topic", default=os.environ.get("NTFY_TOPIC"))
    parser.add_argument("--ntfy-server", default=os.environ.get("NTFY_SERVER", "https://ntfy.sh"))
    parser.add_argument("--ntfy-token", default=os.environ.get("NTFY_TOKEN"))
    parser.add_argument("--ntfy-priority", default=os.environ.get("NTFY_PRIORITY", "high"))

    args = parser.parse_args(argv)
    if args.interval_days <= 0:
        parser.error("--interval-days must be greater than zero")
    if args.retry_days <= 0:
        parser.error("--retry-days must be greater than zero")

    return IngestConfig(
        skipimport=args.skipimport,
        sourceupdate=args.sourceupdate,
        telemetry=args.telemetry,
        interval_days=args.interval_days,
        retry_days=args.retry_days,
        extracts=args.extracts,
        mapping=args.mapping,
        imposm=args.imposm,
        where=args.where or [],
        cachedir=args.cachedir,
        diffdir=args.diffdir,
        pbfdir=args.pbfdir,
        expiredir=args.expiredir,
        extradatadir=args.extradatadir,
        config=args.config,
        provision=args.provision,
        dsn_init=args.dsn_init or os.environ.get("DSN_INIT") or default_init_dsn(),
        dsn=args.dsn or os.environ.get("DSN") or default_osm_dsn(),
        verbose=args.verbose,
        run_once=args.run_once,
        ntfy_topic=args.ntfy_topic,
        ntfy_server=args.ntfy_server,
        ntfy_token=args.ntfy_token,
        ntfy_priority=args.ntfy_priority,
    )


def configure_logging(verbose: bool):
    loglevel = logging.INFO if verbose else logging.WARNING
    logging.basicConfig(level=loglevel, format="%(asctime)s:%(levelname)s:%(message)s")


def telemetry_log(config: IngestConfig, event_name: str, start: datetime, end: datetime):
    if config.telemetry:
        duration = end - start
        event_duration.labels(event_name).observe(duration.total_seconds())
        last_event_time.labels(event_name).set(end.timestamp())


def load_selected_extract(config: IngestConfig) -> dict:
    with open(config.extracts, encoding="utf8") as extracts_f:
        extracts = json.load(extracts_f)

    selected = [extract for extract in extracts if extract["name"] in config.where]
    if len(selected) != 1:
        names = ", ".join(config.where) if config.where else "<none>"
        raise ValueError(
            f"GEN_REGION/--where must resolve to exactly one extract; "
            f"matched {len(selected)} for {names}"
        )
    return selected[0]


def pbf_name(extract: dict) -> str:
    urlbits = urllib.parse.urlsplit(extract["url"])
    return os.path.basename(urlbits.path)


def pbf_path(config: IngestConfig, extract: dict) -> Path:
    return Path(config.pbfdir) / pbf_name(extract)


def state_path(config: IngestConfig) -> Path:
    return Path(config.pbfdir) / STATE_FILE


def lock_path(config: IngestConfig) -> Path:
    return Path(config.pbfdir) / LOCK_FILE


@contextlib.contextmanager
def ingest_lock(config: IngestConfig):
    Path(config.pbfdir).mkdir(parents=True, exist_ok=True)
    lock_file = lock_path(config)
    with open(lock_file, "w", encoding="utf8") as lock:
        logger.info("Waiting for ingest lock at %s", lock_file)
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        logger.info("Acquired ingest lock at %s", lock_file)
        try:
            yield
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            logger.info("Released ingest lock at %s", lock_file)


def pbf_marker(path: Path, extract: dict) -> dict:
    stat = path.stat()
    return {
        "region": extract["name"],
        "url": extract["url"],
        "pbf": path.name,
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
    }


def read_state(path: Path) -> dict | None:
    try:
        with open(path, encoding="utf8") as state_file:
            return json.load(state_file)
    except FileNotFoundError:
        return None


def write_state(path: Path, marker: dict):
    payload = dict(marker)
    payload["ingested_at"] = datetime.now(timezone.utc).isoformat()
    tmp = path.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf8") as state_file:
        json.dump(payload, state_file, sort_keys=True, indent=2)
        state_file.write("\n")
    os.replace(tmp, path)


def download_seed(url: str, destination: Path):
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_name(f".{destination.name}.download")
    logger.info("Initial seed download from %s to %s", url, destination)
    try:
        urllib.request.urlretrieve(url, tmp)
        os.replace(tmp, destination)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)


def sync_pbf(config: IngestConfig, extract: dict) -> bool:
    path = pbf_path(config, extract)
    if not path.exists():
        download_seed(extract["url"], path)
        return True

    if not config.sourceupdate:
        logger.info("Source updates disabled; keeping existing PBF")
        return False

    updated = False
    while True:
        result = subprocess.run(["pyosmium-up-to-date", str(path)], check=False)
        if result.returncode == 0:
            return updated
        if result.returncode == 1:
            updated = True
            logger.info("pyosmium applied diffs to %s; checking again", path)
            continue
        raise PbfSyncError(f"pyosmium-up-to-date failed with return code {result.returncode}")


def import_extract(config: IngestConfig, extract: dict, cache: str, incremental: bool):
    pbf = pbf_name(extract)
    logger.info("Import of %s: START", pbf)
    start = datetime.now(timezone.utc)
    imposm_args = [
        config.imposm,
        "import",
        "-mapping",
        config.mapping,
        "-read",
        str(Path(config.pbfdir) / pbf),
        "-srid",
        "4326",
        cache,
        "-cachedir",
        config.cachedir,
    ]
    if incremental:
        imposm_args.extend(["-diff", "-diffdir", config.diffdir])
    subprocess.run(imposm_args, check=True)
    end = datetime.now(timezone.utc)
    telemetry_log(config, "import_extract", start, end)
    logger.info("Import of %s: DONE", pbf)


def import_write(config: IngestConfig, incremental: bool):
    logger.info("Writing OSM tables: START")
    start = datetime.now(timezone.utc)
    imposm_args = [
        config.imposm,
        "import",
        "-mapping",
        config.mapping,
        "-write",
        "-connection",
        config.dsn,
        "-srid",
        "4326",
        "-cachedir",
        config.cachedir,
    ]
    if incremental:
        imposm_args.extend(["-diff", "-diffdir", config.diffdir])
    subprocess.run(imposm_args, check=True)
    end = datetime.now(timezone.utc)
    telemetry_log(config, "import_write", start, end)
    logger.info("Writing OSM tables: DONE")


def import_rotate(config: IngestConfig, incremental: bool):
    logger.info("Table rotation: START")
    start = datetime.now(timezone.utc)
    imposm_args = [
        config.imposm,
        "import",
        "-mapping",
        config.mapping,
        "-connection",
        config.dsn,
        "-srid",
        "4326",
        "-deployproduction",
        "-cachedir",
        config.cachedir,
    ]
    if incremental:
        imposm_args.extend(["-diff", "-diffdir", config.diffdir])
    subprocess.run(imposm_args, check=True)
    end = datetime.now(timezone.utc)
    telemetry_log(config, "import_rotate", start, end)
    logger.info("Table rotation: DONE")


def import_extracts_and_write(config: IngestConfig, extract: dict, incremental: bool):
    import_extract(config, extract, "-overwritecache", incremental)
    import_write(config, incremental)
    import_rotate(config, incremental)


def dsn_dbname(dsn: str) -> str:
    for part in dsn.split():
        if part.startswith("dbname="):
            return part.split("=", 1)[1]
    return os.environ.get("POSTGIS_DBNAME", "osm")


async def provision_database_async(postgres_dsn: str, osm_dsn: str, dbname: str):
    async with aiopg.connect(dsn=postgres_dsn) as conn:
        cursor = await conn.cursor()
        try:
            escaped_dbname = dbname.replace('"', '""')
            await cursor.execute(f'CREATE DATABASE "{escaped_dbname}"')
        except psycopg2.ProgrammingError:
            logger.warning('Database already existed at "%s"', postgres_dsn)
    async with aiopg.connect(dsn=osm_dsn) as conn:
        cursor = await conn.cursor()
        await cursor.execute("CREATE EXTENSION IF NOT EXISTS postgis")
        await cursor.execute("CREATE EXTENSION IF NOT EXISTS hstore")
        await provision_non_osm_data_async(osm_dsn)


async def provision_database_soundscape_async(osm_dsn: str):
    ingest_path = os.environ["INGEST"]
    async with aiopg.connect(dsn=osm_dsn) as conn:
        cursor = await conn.cursor()
        with open(Path(ingest_path) / "postgis-vt-util.sql", encoding="utf8") as sql:
            await cursor.execute(sql.read())
        with open(Path(ingest_path) / "tilefunc.sql", encoding="utf8") as sql:
            await cursor.execute(sql.read())


def run_async(coro):
    return asyncio.run(coro)


def provision_database(config: IngestConfig):
    start = datetime.now(timezone.utc)
    run_async(provision_database_async(config.dsn_init, config.dsn, dsn_dbname(config.dsn)))
    end = datetime.now(timezone.utc)
    telemetry_log(config, "provision_database", start, end)


def provision_database_soundscape(config: IngestConfig):
    run_async(provision_database_soundscape_async(config.dsn))


def import_database(config: IngestConfig, extract: dict):
    try:
        if config.provision:
            logger.info("Provisioning database: START")
            provision_database(config)
            logger.info("Provisioning database: DONE")

        if not config.skipimport:
            import_extracts_and_write(config, extract, incremental=False)

        if config.extradatadir:
            try:
                logger.info("Importing non-OSM data: START")
                import_non_osm_data(config.extradatadir, config.dsn, logger)
                logger.info("Importing non-OSM data: DONE")
            except Exception as exc:
                raise NonOsmIngestError(str(exc)) from exc

        provision_database_soundscape(config)
    except NonOsmIngestError:
        raise
    except Exception as exc:
        raise DbIngestError(str(exc)) from exc


def ntfy_url(config: IngestConfig) -> str:
    server = config.ntfy_server.rstrip("/")
    topic = urllib.parse.quote(config.ntfy_topic or "", safe="")
    return f"{server}/{topic}"


def send_ntfy_notification(config: IngestConfig, region: str, stage: str, exc: Exception, next_retry_seconds: float):
    if not config.ntfy_topic:
        return

    retry_hours = next_retry_seconds / 3600
    body = (
        f"Soundscape ingest failed\n"
        f"region: {region}\n"
        f"stage: {stage}\n"
        f"error: {type(exc).__name__}: {exc}\n"
        f"next_retry_hours: {retry_hours:.2f}"
    ).encode("utf8")
    request = urllib.request.Request(ntfy_url(config), data=body, method="POST")
    request.add_header("Title", f"Soundscape ingest failed: {region}")
    request.add_header("Priority", config.ntfy_priority)
    request.add_header("Tags", "warning")
    if config.ntfy_token:
        request.add_header("Authorization", f"Bearer {config.ntfy_token}")

    try:
        urllib.request.urlopen(request, timeout=10).close()
    except Exception:
        logger.warning("Failed to send ntfy notification", exc_info=True)


def run_cycle(config: IngestConfig, extract: dict) -> bool:
    start = datetime.now(timezone.utc)
    with ingest_lock(config):
        try:
            pbf_changed = sync_pbf(config, extract)
        except Exception as exc:
            raise PbfSyncError(str(exc)) from exc

        marker = pbf_marker(pbf_path(config, extract), extract)
        prior_state = read_state(state_path(config))
        should_import = pbf_changed or prior_state is None or any(
            prior_state.get(key) != marker[key] for key in ("region", "url", "pbf", "size", "mtime_ns")
        )

        if should_import:
            logger.info("PBF state changed or missing; importing database")
            import_database(config, extract)
            write_state(state_path(config), marker)
        else:
            logger.info("PBF state unchanged; skipping database import")

    end = datetime.now(timezone.utc)
    telemetry_log(config, "ingest_cycle", start, end)
    return True


def seconds_from_days(days: float) -> float:
    return days * SECONDS_PER_DAY


def run_scheduler(config: IngestConfig, extract: dict, sleep=time.sleep, monotonic=time.monotonic):
    interval_seconds = seconds_from_days(config.interval_days)
    retry_seconds = seconds_from_days(config.retry_days)
    next_run = monotonic()

    while True:
        now = monotonic()
        if now < next_run:
            sleep(next_run - now)

        cycle_due = next_run
        success = False
        try:
            success = run_cycle(config, extract)
        except PbfSyncError as exc:
            logger.exception("PBF sync failed")
            send_ntfy_notification(config, extract["name"], "pbf_sync", exc, retry_seconds)
        except NonOsmIngestError as exc:
            logger.exception("Non-OSM import failed")
            send_ntfy_notification(config, extract["name"], "non_osm_import", exc, retry_seconds)
        except DbIngestError as exc:
            logger.exception("Database ingest failed")
            send_ntfy_notification(config, extract["name"], "database_ingest", exc, retry_seconds)
        except Exception as exc:
            logger.exception("Unexpected ingest cycle failure")
            send_ntfy_notification(config, extract["name"], "cycle", exc, retry_seconds)

        if config.run_once:
            return success

        delay = interval_seconds if success else retry_seconds
        next_run = cycle_due + delay
        if next_run <= monotonic():
            next_run = monotonic()


def main(argv=None) -> int:
    config = parse_args(argv)
    configure_logging(config.verbose)

    if config.telemetry:
        start_http_server(8000)

    try:
        extract = load_selected_extract(config)
        success = run_scheduler(config, extract)
        return 0 if success else 1
    finally:
        logging.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
