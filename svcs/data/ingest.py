# Copyright (c) Microsoft Corporation.
# Copyright (c) Soundscape Community Contributors.
# Licensed under the MIT License.

import argparse
import asyncio
import contextlib
import fcntl
import hashlib
import json
import logging
import os
import subprocess
import threading
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import aiopg
import psycopg2
import psycopg2.extensions
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
SEED_DOWNLOAD_TIMEOUT_SECONDS = 60
SEED_DOWNLOAD_PROGRESS_SECONDS = 5 * 60
IMPOSM_LAST_STATE = "last.state.txt"
NTFY_ERROR_THROTTLE_SECONDS = 60 * 60
NON_OSM_IMPORT_INTERVAL_SECONDS = SECONDS_PER_DAY
PYOSMIUM_UP_TO_DATE_MAX_ATTEMPTS = 100
INGEST_MODE_WEEKLY_PBF = "weekly-pbf"
INGEST_MODE_IMPOSM_RUN = "imposm-run"
INGEST_MODES = (INGEST_MODE_WEEKLY_PBF, INGEST_MODE_IMPOSM_RUN)
IMPORT_STATE_TABLE = "soundscape_osm_import_state"

logger = logging.getLogger(__name__)


class PbfSyncError(RuntimeError):
    pass


class DbIngestError(RuntimeError):
    pass


class NonOsmIngestError(RuntimeError):
    pass


@dataclass
class IngestConfig:
    ingest_mode: str
    skipimport: bool
    sourceupdate: bool
    telemetry: bool
    interval_days: float
    retry_days: float
    pbf_reuse_days: float
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


def build_imposm_dsn(dsn: str) -> str:
    if dsn.startswith("postgis://"):
        return dsn
    if dsn.startswith("postgres://") or dsn.startswith("postgresql://"):
        parsed = urllib.parse.urlsplit(dsn)
        return urllib.parse.urlunsplit(("postgis", parsed.netloc, parsed.path, parsed.query, parsed.fragment))

    args = psycopg2.extensions.parse_dsn(dsn)
    user = urllib.parse.quote(args.get("user", ""), safe="")
    password = urllib.parse.quote(args.get("password", ""), safe="")
    host = args.get("host", "")
    port = args.get("port", "")
    dbname = urllib.parse.quote(args.get("dbname", ""), safe="")
    auth = user
    if password:
        auth = f"{auth}:{password}"
    hostport = host
    if port:
        hostport = f"{hostport}:{port}"
    return f"postgis://{auth}@{hostport}/{dbname}"


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

    parser.add_argument(
        "--ingest-mode",
        choices=INGEST_MODES,
        default=os.environ.get("INGEST_MODE", INGEST_MODE_WEEKLY_PBF),
        help="ingest strategy",
    )
    parser.add_argument("--skipimport", action="store_true", help="skips import task", default=False)
    parser.add_argument("--sourceupdate", action="store_true", help="update source data", default=True)
    parser.add_argument("--no-sourceupdate", dest="sourceupdate", action="store_false", help="skip source data updates")
    parser.add_argument("--telemetry", action="store_true", help="generate telemetry")
    parser.add_argument("--interval-days", type=float, default=env_float("INGEST_INTERVAL_DAYS", 7))
    parser.add_argument("--retry-days", type=float, default=env_float("INGEST_RETRY_DAYS", 1))
    parser.add_argument("--pbf-reuse-days", type=float, default=env_float("INGEST_PBF_REUSE_DAYS", 5))
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
    if args.pbf_reuse_days <= 0:
        parser.error("--pbf-reuse-days must be greater than zero")

    return IngestConfig(
        ingest_mode=args.ingest_mode,
        skipimport=args.skipimport,
        sourceupdate=args.sourceupdate,
        telemetry=args.telemetry,
        interval_days=args.interval_days,
        retry_days=args.retry_days,
        pbf_reuse_days=args.pbf_reuse_days,
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


def imposm_config_path(config: IngestConfig) -> Path:
    return Path(config.config)


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
        "sequence_number": pbf_replication_sequence(path),
        "url": extract["url"],
        "pbf": path.name,
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
    }


def legacy_pbf_marker(path: Path, extract: dict) -> dict:
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
    except json.JSONDecodeError:
        logger.warning("Ignoring unreadable ingest state at %s", path)
        return None


def write_state(path: Path, marker: dict):
    payload = dict(marker)
    payload["ingested_at"] = datetime.now(timezone.utc).isoformat()
    tmp = path.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf8") as state_file:
        json.dump(payload, state_file, sort_keys=True, indent=2)
        state_file.write("\n")
    os.replace(tmp, path)


def response_content_length(response) -> int | None:
    headers = getattr(response, "headers", None)
    value = None
    if headers is not None:
        value = headers.get("Content-Length")
    if value is None and hasattr(response, "getheader"):
        value = response.getheader("Content-Length")
    if not value:
        return None
    return int(value)


def download_seed(url: str, destination: Path, sha256: str | None = None, monotonic=time.monotonic):
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_name(f".{destination.name}.download")
    logger.info("Initial seed download from %s to %s", url, destination)
    try:
        response = urllib.request.urlopen(url, timeout=SEED_DOWNLOAD_TIMEOUT_SECONDS)
        try:
            expected_length = response_content_length(response)
            actual_length = 0
            digest = hashlib.sha256()
            last_progress = monotonic()
            with open(tmp, "wb") as tmp_file:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    tmp_file.write(chunk)
                    actual_length += len(chunk)
                    if sha256:
                        digest.update(chunk)
                    now = monotonic()
                    if now - last_progress >= SEED_DOWNLOAD_PROGRESS_SECONDS:
                        logger.info("Downloaded %d bytes for %s", actual_length, destination)
                        last_progress = now
        finally:
            response.close()
        if expected_length is not None and actual_length != expected_length:
            raise PbfSyncError(
                f"seed download size mismatch for {destination}: expected {expected_length}, got {actual_length}"
            )
        if sha256 and digest.hexdigest().lower() != sha256.lower():
            raise PbfSyncError(f"seed download checksum mismatch for {destination}")
        os.replace(tmp, destination)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)


def run_pyosmium_up_to_date(path: Path, runner=subprocess.run):
    command = ["pyosmium-up-to-date", "--format", "pbf,add_metadata=false", "--size", "5000", str(path)]
    logger.info("Updating PBF with pyosmium: %s", command)
    for attempt in range(1, PYOSMIUM_UP_TO_DATE_MAX_ATTEMPTS + 1):
        try:
            result = runner(command, check=False)
        except Exception as exc:
            raise PbfSyncError(str(exc)) from exc
        if result.returncode == 0:
            return
        if result.returncode != 1:
            raise PbfSyncError(f"pyosmium-up-to-date exited with status {result.returncode}")
        logger.info(
            "pyosmium-up-to-date applied partial updates to %s; continuing sync attempt %d",
            path,
            attempt + 1,
        )

    raise PbfSyncError(
        f"pyosmium-up-to-date did not reach the latest state after "
        f"{PYOSMIUM_UP_TO_DATE_MAX_ATTEMPTS} attempts"
    )


def sync_pbf(config: IngestConfig, extract: dict):
    seed_path = pbf_path(config, extract)
    if pbf_is_recent(seed_path, config.pbf_reuse_days):
        logger.info(
            "Reusing recent PBF at %s before pyosmium sync; max age %.2f days",
            seed_path,
            config.pbf_reuse_days,
        )
    else:
        download_seed(extract["url"], seed_path, extract.get("sha256"))

    run_pyosmium_up_to_date(seed_path)

    pbf_replication_sequence(seed_path)


def pbf_replication_sequence(path: Path) -> int:
    try:
        import osmium
    except ImportError as exc:
        raise PbfSyncError("pyosmium is required to read PBF replication sequence metadata") from exc

    try:
        reader = osmium.io.Reader(str(path))
        try:
            raw_sequence = reader.header().get("osmosis_replication_sequence_number")
        finally:
            reader.close()
    except Exception as exc:
        raise PbfSyncError(f"unable to read PBF header metadata from {path}: {exc}") from exc

    if raw_sequence is None or raw_sequence == "":
        raise PbfSyncError(f"PBF header missing osmosis_replication_sequence_number: {path}")
    try:
        sequence = int(raw_sequence)
    except (TypeError, ValueError) as exc:
        raise PbfSyncError(
            f"invalid osmosis_replication_sequence_number in {path}: {raw_sequence!r}"
        ) from exc
    if sequence < 0:
        raise PbfSyncError(f"invalid osmosis_replication_sequence_number in {path}: {sequence}")
    return sequence


def pbf_is_recent(path: Path, max_age_days: float, now=time.time) -> bool:
    try:
        stat = path.stat()
    except FileNotFoundError:
        return False
    if not path.is_file():
        return False
    max_age_seconds = seconds_from_days(max_age_days)
    age_seconds = now() - stat.st_mtime
    return age_seconds <= max_age_seconds


def has_diff_state(config: IngestConfig) -> bool:
    cachedir = Path(config.cachedir)
    diff_state = Path(config.diffdir) / IMPOSM_LAST_STATE
    if not diff_state.is_file() or not cachedir.is_dir():
        return False
    try:
        next(cachedir.iterdir())
    except StopIteration:
        return False
    return True


def state_matches_extract(state: dict | None, extract: dict) -> bool:
    if state is None:
        return False
    return (
        state.get("region") == extract["name"]
        and state.get("url") == extract["url"]
        and state.get("pbf") == pbf_name(extract)
    )


def has_current_diff_state(config: IngestConfig, extract: dict) -> bool:
    if not has_diff_state(config):
        return False

    state_file = state_path(config)
    state = read_state(state_file)
    if state_matches_extract(state, extract):
        return True

    previous = state.get("region", "<unknown>") if state else "<missing>"
    logger.info(
        "Existing Imposm diff state is not for selected region %s; previous region: %s",
        extract["name"],
        previous,
    )
    return False


def build_imposm_config(config: IngestConfig, extract: dict) -> dict:
    return {
        "cachedir": config.cachedir,
        "diffdir": config.diffdir,
        "connection": build_imposm_dsn(config.dsn),
        "mapping": config.mapping,
        "srid": 4326,
        "replication_url": extract["replication_url"],
        "replication_interval": extract.get("replication_interval", "24h"),
        "expiretiles_dir": config.expiredir,
        "schemas": {
            "import": "import",
            "production": "public",
            "backup": "backup",
        },
    }


def write_imposm_config(config: IngestConfig, extract: dict) -> Path:
    path = imposm_config_path(config)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(f"{path.suffix}.tmp")
    with open(tmp, "w", encoding="utf8") as config_file:
        json.dump(build_imposm_config(config, extract), config_file, sort_keys=True, indent=2)
        config_file.write("\n")
    os.replace(tmp, path)
    return path


def import_extract(config: IngestConfig, extract: dict, cache="-overwritecache", incremental=False):
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


def import_write(config: IngestConfig, incremental=False):
    logger.info("Writing OSM tables: START")
    start = datetime.now(timezone.utc)
    imposm_args = [
        config.imposm,
        "import",
        "-mapping",
        config.mapping,
        "-write",
        "-connection",
        build_imposm_dsn(config.dsn),
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


def import_rotate(config: IngestConfig, incremental=False):
    logger.info("Table rotation: START")
    start = datetime.now(timezone.utc)
    imposm_args = [
        config.imposm,
        "import",
        "-mapping",
        config.mapping,
        "-connection",
        build_imposm_dsn(config.dsn),
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


def import_extracts_and_write(config: IngestConfig, extract: dict, incremental=False):
    import_extract(config, extract, "-overwritecache", incremental)
    import_write(config, incremental)
    import_rotate(config, incremental)


def import_extract_for_imposm_run(config: IngestConfig, extract: dict):
    pbf = pbf_name(extract)
    logger.info("Import of %s: START", pbf)
    start = datetime.now(timezone.utc)
    imposm_args = [
        config.imposm,
        "import",
        "-config",
        str(imposm_config_path(config)),
        "-read",
        str(Path(config.pbfdir) / pbf),
        "-write",
        "-diff",
        "-deployproduction",
        "-overwritecache",
    ]
    subprocess.run(imposm_args, check=True)
    end = datetime.now(timezone.utc)
    telemetry_log(config, "import_extract", start, end)
    logger.info("Import of %s: DONE", pbf)


def dsn_dbname(dsn: str) -> str:
    if dsn.startswith("postgres://") or dsn.startswith("postgresql://") or dsn.startswith("postgis://"):
        return urllib.parse.unquote(urllib.parse.urlsplit(dsn).path.lstrip("/"))
    for part in dsn.split():
        if part.startswith("dbname="):
            return part.split("=", 1)[1]
    return os.environ.get("POSTGIS_DBNAME", "osm")


async def provision_database_async(osm_dsn: str):
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
    dbname = dsn_dbname(config.dsn)
    conn = psycopg2.connect(config.dsn_init)
    conn.autocommit = True
    try:
        with conn.cursor() as cursor:
            try:
                escaped_dbname = dbname.replace('"', '""')
                cursor.execute(f'CREATE DATABASE "{escaped_dbname}"')
            except psycopg2.errors.DuplicateDatabase:
                logger.warning('Database "%s" already existed', dbname)
    finally:
        conn.close()
    run_async(provision_database_async(config.dsn))
    end = datetime.now(timezone.utc)
    telemetry_log(config, "provision_database", start, end)


def provision_database_soundscape(config: IngestConfig):
    run_async(provision_database_soundscape_async(config.dsn))


def ensure_import_state_table(cursor):
    cursor.execute(
        f"""
        CREATE TABLE IF NOT EXISTS {IMPORT_STATE_TABLE} (
            region text NOT NULL,
            sequence_number bigint NOT NULL,
            source_url text NOT NULL,
            pbf_filename text NOT NULL,
            imported_at timestamptz NOT NULL DEFAULT now(),
            file_size bigint,
            file_mtime_ns bigint,
            PRIMARY KEY (region, sequence_number)
        )
        """
    )


def read_import_state(config: IngestConfig, region: str, sequence_number: int) -> dict | None:
    conn = psycopg2.connect(config.dsn)
    try:
        with conn:
            with conn.cursor() as cursor:
                ensure_import_state_table(cursor)
                cursor.execute(
                    f"""
                    SELECT region, sequence_number, source_url, pbf_filename, imported_at, file_size, file_mtime_ns
                    FROM {IMPORT_STATE_TABLE}
                    WHERE region = %s AND sequence_number = %s
                    """,
                    (region, sequence_number),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        return {
            "region": row[0],
            "sequence_number": row[1],
            "url": row[2],
            "pbf": row[3],
            "imported_at": row[4],
            "size": row[5],
            "mtime_ns": row[6],
        }
    finally:
        conn.close()


def import_state_matches(state: dict | None, marker: dict) -> bool:
    if state is None:
        return False
    return state.get("region") == marker["region"] and state.get("sequence_number") == marker["sequence_number"]


def write_import_state(config: IngestConfig, marker: dict):
    conn = psycopg2.connect(config.dsn)
    try:
        with conn:
            with conn.cursor() as cursor:
                ensure_import_state_table(cursor)
                cursor.execute(
                    f"""
                    INSERT INTO {IMPORT_STATE_TABLE}
                        (region, sequence_number, source_url, pbf_filename, imported_at, file_size, file_mtime_ns)
                    VALUES (%s, %s, %s, %s, now(), %s, %s)
                    ON CONFLICT (region, sequence_number) DO UPDATE SET
                        source_url = EXCLUDED.source_url,
                        pbf_filename = EXCLUDED.pbf_filename,
                        imported_at = EXCLUDED.imported_at,
                        file_size = EXCLUDED.file_size,
                        file_mtime_ns = EXCLUDED.file_mtime_ns
                    """,
                    (
                        marker["region"],
                        marker["sequence_number"],
                        marker["url"],
                        marker["pbf"],
                        marker["size"],
                        marker["mtime_ns"],
                    ),
                )
    finally:
        conn.close()


def import_database(config: IngestConfig, extract: dict) -> bool:
    osm_imported = False
    try:
        if config.provision:
            logger.info("Provisioning database: START")
            provision_database(config)
            logger.info("Provisioning database: DONE")

        if not config.skipimport:
            import_extracts_and_write(config, extract, incremental=False)
            osm_imported = True

        if config.extradatadir:
            try:
                logger.info("Importing non-OSM data: START")
                import_non_osm_data(config.extradatadir, config.dsn, logger)
                logger.info("Importing non-OSM data: DONE")
            except Exception as exc:
                raise NonOsmIngestError(str(exc)) from exc

        provision_database_soundscape(config)
        return osm_imported
    except NonOsmIngestError:
        raise
    except Exception as exc:
        raise DbIngestError(str(exc)) from exc


def import_non_osm(config: IngestConfig):
    if not config.extradatadir:
        return
    try:
        logger.info("Importing non-OSM data: START")
        import_non_osm_data(config.extradatadir, config.dsn, logger)
        logger.info("Importing non-OSM data: DONE")
    except Exception as exc:
        raise NonOsmIngestError(str(exc)) from exc


def run_startup_imports(config: IngestConfig):
    import_non_osm(config)
    try:
        provision_database_soundscape(config)
    except Exception as exc:
        raise DbIngestError(str(exc)) from exc


def bootstrap(config: IngestConfig, extract: dict) -> bool:
    with ingest_lock(config):
        write_imposm_config(config, extract)
        if config.provision:
            try:
                logger.info("Provisioning database: START")
                provision_database(config)
                logger.info("Provisioning database: DONE")
            except Exception as exc:
                raise DbIngestError(str(exc)) from exc

        if not has_current_diff_state(config, extract):
            if config.skipimport:
                logger.info("Skipping initial OSM import because --skipimport is set")
            else:
                seed_path = pbf_path(config, extract)
                if pbf_is_recent(seed_path, config.pbf_reuse_days):
                    logger.info(
                        "Reusing recent bootstrap PBF at %s; max age %.2f days",
                        seed_path,
                        config.pbf_reuse_days,
                    )
                else:
                    download_seed(extract["url"], seed_path, extract.get("sha256"))
                try:
                    import_extract_for_imposm_run(config, extract)
                except Exception as exc:
                    raise DbIngestError(str(exc)) from exc
                write_state(state_path(config), legacy_pbf_marker(seed_path, extract))
        else:
            logger.info("Existing Imposm diff state found; skipping seed download and initial import")

        run_startup_imports(config)
    return True


def run_weekly_cycle(config: IngestConfig, extract: dict) -> bool:
    start = datetime.now(timezone.utc)
    with ingest_lock(config):
        write_imposm_config(config, extract)
        if config.provision:
            try:
                logger.info("Provisioning database: START")
                provision_database(config)
                logger.info("Provisioning database: DONE")
            except Exception as exc:
                raise DbIngestError(str(exc)) from exc

        sync_pbf(config, extract)
        marker = pbf_marker(pbf_path(config, extract), extract)
        try:
            prior_state = read_import_state(config, marker["region"], marker["sequence_number"])
        except Exception as exc:
            raise DbIngestError(str(exc)) from exc

        if import_state_matches(prior_state, marker):
            logger.info(
                "PBF sequence %s for %s is already imported; skipping OSM import",
                marker["sequence_number"],
                marker["region"],
            )
            try:
                run_startup_imports(config)
            except NonOsmIngestError:
                raise
            except Exception as exc:
                raise DbIngestError(str(exc)) from exc
        else:
            logger.info(
                "Importing %s PBF sequence %s",
                marker["region"],
                marker["sequence_number"],
            )
            osm_imported = import_database(config, extract)
            if osm_imported:
                try:
                    write_import_state(config, marker)
                except Exception as exc:
                    raise DbIngestError(str(exc)) from exc

    end = datetime.now(timezone.utc)
    telemetry_log(config, "ingest_cycle", start, end)
    return True


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


def seconds_from_days(days: float) -> float:
    return days * SECONDS_PER_DAY


def maybe_alert_imposm_output(config: IngestConfig, region: str, line: str, alerted_errors: dict[str, float], monotonic):
    if "[fatal]" in line:
        send_ntfy_notification(config, region, "imposm_run", RuntimeError(line), 0)
        return
    if "[error]" not in line:
        return
    now = monotonic()
    last_alert = alerted_errors.get(line)
    if last_alert is not None and now - last_alert < NTFY_ERROR_THROTTLE_SECONDS:
        return
    alerted_errors[line] = now
    send_ntfy_notification(config, region, "imposm_run", RuntimeError(line), 0)


def stream_process_output(config: IngestConfig, region: str, pipe, alerted_errors: dict[str, float], monotonic):
    for line in iter(pipe.readline, ""):
        message = line.rstrip()
        if not message:
            continue
        if "[fatal]" in message or "[error]" in message:
            logger.error("imposm run: %s", message)
        else:
            logger.info("imposm run: %s", message)
        maybe_alert_imposm_output(config, region, message, alerted_errors, monotonic)


def run_daily_non_osm_imports(
    config: IngestConfig,
    region: str,
    stop_event: threading.Event,
    interval_seconds: float = NON_OSM_IMPORT_INTERVAL_SECONDS,
):
    if not config.extradatadir:
        return

    while not stop_event.wait(interval_seconds):
        try:
            import_non_osm(config)
        except NonOsmIngestError as exc:
            logger.exception("Daily non-OSM import failed")
            send_ntfy_notification(config, region, "non_osm_import", exc, interval_seconds)


def run_imposm(config: IngestConfig, extract: dict, popen_factory=subprocess.Popen, monotonic=time.monotonic) -> int:
    command = [config.imposm, "run", "-config", str(imposm_config_path(config))]
    logger.info("Starting Imposm update supervisor: %s", command)
    process = popen_factory(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    alerted_errors: dict[str, float] = {}
    stop_event = threading.Event()
    threads = []
    if config.extradatadir:
        thread = threading.Thread(
            target=run_daily_non_osm_imports,
            args=(config, extract["name"], stop_event),
            daemon=True,
        )
        thread.start()
        threads.append(thread)
    for pipe in (process.stdout, process.stderr):
        if pipe is None:
            continue
        thread = threading.Thread(
            target=stream_process_output,
            args=(config, extract["name"], pipe, alerted_errors, monotonic),
            daemon=True,
        )
        thread.start()
        threads.append(thread)
    returncode = process.wait()
    stop_event.set()
    for thread in threads:
        thread.join()
    if returncode == 0:
        logger.info("imposm run exited cleanly")
        return 0
    exc = RuntimeError(f"imposm run exited with status {returncode}")
    send_ntfy_notification(config, extract["name"], "imposm_run_exit", exc, 0)
    return returncode


def run_ingest(config: IngestConfig, extract: dict) -> int:
    start = datetime.now(timezone.utc)
    try:
        bootstrap(config, extract)
    except NonOsmIngestError as exc:
        logger.exception("Non-OSM import failed")
        send_ntfy_notification(config, extract["name"], "non_osm_import", exc, seconds_from_days(config.retry_days))
        return 1
    except DbIngestError as exc:
        logger.exception("Database ingest failed")
        send_ntfy_notification(config, extract["name"], "database_ingest", exc, seconds_from_days(config.retry_days))
        return 1
    except Exception as exc:
        logger.exception("Unexpected bootstrap failure")
        send_ntfy_notification(config, extract["name"], "bootstrap", exc, seconds_from_days(config.retry_days))
        return 1
    finally:
        end = datetime.now(timezone.utc)
        telemetry_log(config, "ingest_bootstrap", start, end)

    if config.run_once:
        logger.info("Run-once mode enabled; not starting imposm run")
        return 0
    if not config.sourceupdate:
        logger.info("Source updates disabled; not starting imposm run")
        return 0
    return run_imposm(config, extract)


def run_weekly_ingest(config: IngestConfig, extract: dict) -> int:
    try:
        run_weekly_cycle(config, extract)
        return 0
    except PbfSyncError as exc:
        logger.exception("PBF sync failed")
        send_ntfy_notification(config, extract["name"], "pbf_sync", exc, seconds_from_days(config.retry_days))
        return 1
    except NonOsmIngestError as exc:
        logger.exception("Non-OSM import failed")
        send_ntfy_notification(config, extract["name"], "non_osm_import", exc, seconds_from_days(config.retry_days))
        return 1
    except DbIngestError as exc:
        logger.exception("Database ingest failed")
        send_ntfy_notification(config, extract["name"], "database_ingest", exc, seconds_from_days(config.retry_days))
        return 1
    except Exception as exc:
        logger.exception("Unexpected ingest cycle failure")
        send_ntfy_notification(config, extract["name"], "cycle", exc, seconds_from_days(config.retry_days))
        return 1


def supervise_weekly_ingest(config: IngestConfig, sleeper=time.sleep) -> int:
    extract = load_selected_extract(config)
    interval_seconds = seconds_from_days(config.interval_days)
    retry_seconds = seconds_from_days(config.retry_days)
    while True:
        status = run_weekly_ingest(config, extract)
        if config.run_once:
            return status
        delay = interval_seconds if status == 0 else retry_seconds
        logger.info("Next weekly PBF ingest cycle in %.2f hours", delay / 3600)
        sleeper(delay)


def supervise_ingest(config: IngestConfig, sleeper=time.sleep) -> int:
    extract = load_selected_extract(config)
    retry_seconds = seconds_from_days(config.retry_days)
    while True:
        status = run_ingest(config, extract)
        if status == 0 or config.run_once:
            return status
        logger.warning(
            "Ingest cycle failed with status %s; retrying in %.2f hours",
            status,
            retry_seconds / 3600,
        )
        sleeper(retry_seconds)


def main(argv=None) -> int:
    config = parse_args(argv)
    configure_logging(config.verbose)

    if config.telemetry:
        start_http_server(8000)

    try:
        if config.ingest_mode == INGEST_MODE_IMPOSM_RUN:
            return supervise_ingest(config)
        return supervise_weekly_ingest(config)
    finally:
        logging.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
