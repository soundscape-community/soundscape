# Copyright (c) Soundscape Community Contributors.
# Licensed under the MIT License.

import importlib.util
import io
import json
import os
import subprocess
import sys
import time
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace

import pytest


INGEST_PATH = Path(__file__).resolve().parents[1] / "ingest.py"
NON_OSM_PATH = Path(__file__).resolve().parents[1] / "ingest_non_osm.py"
DATA_DIR = INGEST_PATH.parent


def load_ingest(module_name="ingest_under_test"):
    if str(DATA_DIR) not in sys.path:
        sys.path.insert(0, str(DATA_DIR))
    spec = importlib.util.spec_from_file_location(module_name, INGEST_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def load_non_osm(module_name="non_osm_under_test"):
    spec = importlib.util.spec_from_file_location(module_name, NON_OSM_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


class FakeAsyncCursor:
    def __init__(self):
        self.commands = []

    async def execute(self, sql, params=None):
        self.commands.append((sql, params))


class FakeAiopgConnection:
    def __init__(self, cursor):
        self.cursor_instance = cursor

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        pass

    async def cursor(self):
        return self.cursor_instance


def sql_texts(cursor):
    return [" ".join(sql.split()) for sql, _ in cursor.commands]


def base_config(ingest, tmp_path, **overrides):
    config = ingest.IngestConfig(
        ingest_mode=ingest.INGEST_MODE_WEEKLY_PBF,
        skipimport=False,
        sourceupdate=True,
        telemetry=False,
        interval_days=7,
        retry_days=1,
        pbf_reuse_days=5,
        extracts=str(tmp_path / "extracts.json"),
        mapping="mapping.yml",
        imposm="imposm",
        where=["district-of-columbia"],
        cachedir=str(tmp_path / "cache"),
        diffdir=str(tmp_path / "diff"),
        pbfdir=str(tmp_path),
        expiredir=str(tmp_path / "expired"),
        extradatadir=None,
        config="config.json",
        provision=False,
        dsn_init="host=postgis dbname=postgres",
        dsn="host=postgis dbname=osm",
        verbose=False,
        run_once=False,
        ntfy_topic=None,
        ntfy_server="https://ntfy.sh",
        ntfy_token=None,
        ntfy_priority="high",
    )
    return replace(config, **overrides)


def extract(name="district-of-columbia", url="https://example.test/district.osm.pbf"):
    return {
        "name": name,
        "url": url,
        "replication_url": "https://example.test/updates/",
        "replication_interval": "24h",
        "bbox": [0, 0, 0, 0],
    }


def write_extracts(path, extracts):
    path.write_text(json.dumps(extracts), encoding="utf8")


def test_import_is_safe(monkeypatch):
    monkeypatch.setattr(sys, "argv", ["ingest.py", "--invalid-argument"])

    load_ingest("ingest_import_safe")


def test_single_region_validation(tmp_path):
    ingest = load_ingest("ingest_region_validation")
    extracts_file = tmp_path / "extracts.json"
    write_extracts(extracts_file, [extract("a"), extract("b")])

    assert ingest.load_selected_extract(base_config(ingest, tmp_path, extracts=str(extracts_file), where=["a"]))["name"] == "a"

    with pytest.raises(ValueError, match="matched 0"):
        ingest.load_selected_extract(base_config(ingest, tmp_path, extracts=str(extracts_file), where=["missing"]))

    with pytest.raises(ValueError, match="matched 2"):
        ingest.load_selected_extract(base_config(ingest, tmp_path, extracts=str(extracts_file), where=["a", "b"]))


def test_region_env_prefers_singular_with_legacy_fallback(monkeypatch):
    ingest = load_ingest("ingest_region_env")

    monkeypatch.delenv("GEN_REGION", raising=False)
    monkeypatch.setenv("GEN_REGIONS", "legacy")
    assert ingest.env_regions() == ["legacy"]

    monkeypatch.setenv("GEN_REGION", "current")
    assert ingest.env_regions() == ["current"]


def test_pbf_reuse_days_defaults_to_env_and_cli_overrides(monkeypatch):
    ingest = load_ingest("ingest_pbf_reuse_days")

    monkeypatch.delenv("INGEST_PBF_REUSE_DAYS", raising=False)
    assert ingest.parse_args(["--where", "district-of-columbia"]).pbf_reuse_days == 14

    monkeypatch.setenv("INGEST_PBF_REUSE_DAYS", "3.5")
    assert ingest.parse_args(["--where", "district-of-columbia"]).pbf_reuse_days == 3.5
    assert ingest.parse_args(["--where", "district-of-columbia", "--pbf-reuse-days", "2"]).pbf_reuse_days == 2

    with pytest.raises(SystemExit):
        ingest.parse_args(["--where", "district-of-columbia", "--pbf-reuse-days", "0"])


def test_ingest_mode_defaults_to_weekly_and_env_can_select_imposm_run(monkeypatch):
    ingest = load_ingest("ingest_mode")

    monkeypatch.delenv("INGEST_MODE", raising=False)
    assert ingest.parse_args(["--where", "district-of-columbia"]).ingest_mode == ingest.INGEST_MODE_WEEKLY_PBF

    monkeypatch.setenv("INGEST_MODE", ingest.INGEST_MODE_IMPOSM_RUN)
    assert ingest.parse_args(["--where", "district-of-columbia"]).ingest_mode == ingest.INGEST_MODE_IMPOSM_RUN

    assert (
        ingest.parse_args(["--where", "district-of-columbia", "--ingest-mode", ingest.INGEST_MODE_WEEKLY_PBF]).ingest_mode
        == ingest.INGEST_MODE_WEEKLY_PBF
    )

    monkeypatch.setenv("INGEST_MODE", "invalid")
    with pytest.raises(SystemExit):
        ingest.parse_args(["--where", "district-of-columbia"])


def fake_osmium_module(sequence):
    class Reader:
        def __init__(self, path):
            self.path = path
            self.closed = False

        def header(self):
            return {"osmosis_replication_sequence_number": sequence}

        def close(self):
            self.closed = True

    return SimpleNamespace(io=SimpleNamespace(Reader=Reader))


def test_pbf_replication_sequence_reads_pyosmium_header(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_pbf_header")
    path = tmp_path / "region.osm.pbf"
    path.write_text("pbf", encoding="utf8")
    monkeypatch.setitem(sys.modules, "osmium", fake_osmium_module("12345"))

    assert ingest.pbf_replication_sequence(path) == 12345


@pytest.mark.parametrize("sequence", [None, "", "not-a-number", "-1"])
def test_pbf_replication_sequence_rejects_missing_or_invalid_sequence(tmp_path, monkeypatch, sequence):
    ingest = load_ingest(f"ingest_pbf_bad_header_{sequence}")
    path = tmp_path / "region.osm.pbf"
    path.write_text("pbf", encoding="utf8")
    monkeypatch.setitem(sys.modules, "osmium", fake_osmium_module(sequence))

    with pytest.raises(ingest.PbfSyncError):
        ingest.pbf_replication_sequence(path)


def test_seed_download_uses_temp_file_and_atomic_rename(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_seed")
    destination = tmp_path / "region.osm.pbf"
    seen = {}

    class Response(io.BytesIO):
        def close(self):
            seen["closed"] = True
            super().close()

    def fake_urlopen(url, timeout):
        seen["url"] = url
        seen["timeout"] = timeout
        assert not destination.exists()
        return Response(b"pbf")

    monkeypatch.setattr(ingest.urllib.request, "urlopen", fake_urlopen)

    ingest.download_seed("https://example.test/region.osm.pbf", destination)

    assert seen["url"] == "https://example.test/region.osm.pbf"
    assert seen["timeout"] == 60
    assert seen["closed"] is True
    assert destination.read_bytes() == b"pbf"
    assert not (tmp_path / ".region.osm.pbf.download").exists()


def test_seed_download_removes_temp_file_on_failure(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_seed_failure")
    destination = tmp_path / "region.osm.pbf"

    class BrokenResponse:
        def read(self, size=-1):
            tmp = tmp_path / ".region.osm.pbf.download"
            assert tmp.exists()
            raise TimeoutError("timed out")

        def close(self):
            pass

    monkeypatch.setattr(
        ingest.urllib.request,
        "urlopen",
        lambda url, timeout: BrokenResponse(),
    )

    with pytest.raises(TimeoutError):
        ingest.download_seed("https://example.test/region.osm.pbf", destination)

    assert not destination.exists()
    assert not (tmp_path / ".region.osm.pbf.download").exists()


def test_pyosmium_up_to_date_loops_until_fully_current(tmp_path):
    ingest = load_ingest("ingest_pyosmium_loop")
    path = tmp_path / "region.osm.pbf"
    calls = []
    results = [1, 1, 0]

    def fake_run(command, check=False):
        calls.append((command, check))
        return SimpleNamespace(returncode=results.pop(0))

    ingest.run_pyosmium_up_to_date(path, runner=fake_run)

    command = ["pyosmium-up-to-date", "--format", "pbf,add_metadata=false", "--size", "5000", str(path)]
    assert calls == [
        (command, False),
        (command, False),
        (command, False),
    ]


def test_pyosmium_up_to_date_fails_on_non_retryable_exit(tmp_path):
    ingest = load_ingest("ingest_pyosmium_non_retryable")
    path = tmp_path / "region.osm.pbf"

    with pytest.raises(ingest.PbfSyncError, match="status 2"):
        ingest.run_pyosmium_up_to_date(path, runner=lambda command, check=False: SimpleNamespace(returncode=2))


def test_bootstrap_import_runs_imposm_import(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_imposm_import")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    calls = []

    def fake_download(url, destination, sha256=None):
        destination.write_text("pbf", encoding="utf8")

    def fake_run(cmd, check=False, **kwargs):
        calls.append(cmd)
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(ingest, "download_seed", fake_download)
    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: None)
    monkeypatch.setattr(ingest.subprocess, "run", fake_run)

    assert ingest.bootstrap(cfg, ext) is True
    assert calls == [
        [
            "imposm",
            "import",
            "-config",
            str(tmp_path / "imposm.json"),
            "-read",
            str(ingest.pbf_path(cfg, ext)),
            "-write",
            "-diff",
            "-deployproduction",
            "-overwritecache",
        ]
    ]


def test_generated_imposm_config_includes_daily_replication(tmp_path):
    ingest = load_ingest("ingest_config_generation")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()

    path = ingest.write_imposm_config(cfg, ext)
    generated = json.loads(path.read_text(encoding="utf8"))

    assert generated["cachedir"] == cfg.cachedir
    assert generated["diffdir"] == cfg.diffdir
    assert generated["connection"] == "postgis://postgis/osm"
    assert generated["mapping"] == cfg.mapping
    assert generated["srid"] == 4326
    assert generated["replication_url"] == "https://example.test/updates/"
    assert generated["replication_interval"] == "24h"
    assert generated["expiretiles_dir"] == cfg.expiredir
    assert generated["schemas"] == {
        "import": "import",
        "production": "public",
        "backup": "backup",
    }


def test_imposm_dsn_is_url_encoded():
    ingest = load_ingest("ingest_imposm_dsn")

    assert (
        ingest.build_imposm_dsn("host=postgis port=5432 user=postgres password=secret dbname=osm")
        == "postgis://postgres:secret@postgis:5432/osm"
    )
    assert (
        ingest.build_imposm_dsn("postgresql://user:pass@db.example:5432/osm")
        == "postgis://user:pass@db.example:5432/osm"
    )
    assert ingest.build_imposm_dsn("host=postgis dbname=osm") == "postgis://postgis/osm"
    assert ingest.build_imposm_dsn("dbname=osm") == "postgis:///osm"


def test_dsn_dbname_uses_psycopg_parser(monkeypatch):
    ingest = load_ingest("ingest_dsn_dbname")

    assert ingest.dsn_dbname("host=postgis dbname='my osm db'") == "my osm db"
    assert ingest.dsn_dbname("postgresql://user:pass@db.example:5432/url_db") == "url_db"

    monkeypatch.setenv("POSTGIS_DBNAME", "env_osm")
    assert ingest.dsn_dbname("host=postgis") == "env_osm"


def test_import_state_matches_region_and_sequence_only():
    ingest = load_ingest("ingest_marker_compare")
    marker = {
        "region": "district-of-columbia",
        "sequence_number": 42,
        "url": "https://example.test/new.osm.pbf",
        "pbf": "new.osm.pbf",
    }

    assert ingest.import_state_matches({"region": "district-of-columbia", "sequence_number": 42}, marker) is True
    assert ingest.import_state_matches({"region": "district-of-columbia", "sequence_number": 43}, marker) is False
    assert ingest.import_state_matches({"region": "world", "sequence_number": 42}, marker) is False
    assert ingest.import_state_matches(None, marker) is False


def test_weekly_unchanged_region_sequence_skips_osm_import(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_weekly_skip")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")
    events = []

    monkeypatch.setattr(ingest, "sync_pbf", lambda config, selected: events.append(("sync", selected["name"])))
    monkeypatch.setattr(ingest, "pbf_replication_sequence", lambda path: 42)
    monkeypatch.setattr(
        ingest,
        "read_import_state",
        lambda config, region, sequence_number: {"region": "district-of-columbia", "sequence_number": 42},
    )
    monkeypatch.setattr(ingest, "import_database", lambda *args: pytest.fail("OSM import should be skipped"))
    monkeypatch.setattr(ingest, "run_startup_imports", lambda config: events.append("startup"))

    assert ingest.run_weekly_cycle(cfg, ext) is True
    assert events == [("sync", "district-of-columbia"), "startup"]


def test_weekly_changed_sequence_imports_and_updates_db_state(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_weekly_changed_sequence")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")
    written = []

    monkeypatch.setattr(ingest, "sync_pbf", lambda config, selected: None)
    monkeypatch.setattr(ingest, "pbf_replication_sequence", lambda path: 43)
    monkeypatch.setattr(
        ingest,
        "read_import_state",
        lambda config, region, sequence_number: {"region": "district-of-columbia", "sequence_number": 42},
    )
    monkeypatch.setattr(ingest, "import_extracts_and_write", lambda config, selected, incremental=False: None)
    monkeypatch.setattr(ingest, "write_import_state", lambda config, marker: written.append(marker))
    monkeypatch.setattr(ingest, "run_startup_imports", lambda config: None)

    assert ingest.run_weekly_cycle(cfg, ext) is True
    assert written[0]["region"] == "district-of-columbia"
    assert written[0]["sequence_number"] == 43


def test_weekly_changed_region_imports_even_with_same_sequence(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_weekly_changed_region")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), where=["world"])
    ext = extract("world", "https://example.test/world.osm.pbf")
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")
    imported = []

    monkeypatch.setattr(ingest, "sync_pbf", lambda config, selected: None)
    monkeypatch.setattr(ingest, "pbf_replication_sequence", lambda path: 42)
    monkeypatch.setattr(
        ingest,
        "read_import_state",
        lambda config, region, sequence_number: None,
    )
    monkeypatch.setattr(
        ingest,
        "import_extracts_and_write",
        lambda config, selected, incremental=False: imported.append(selected["name"]),
    )
    monkeypatch.setattr(ingest, "write_import_state", lambda config, marker: None)
    monkeypatch.setattr(ingest, "run_startup_imports", lambda config: None)

    assert ingest.run_weekly_cycle(cfg, ext) is True
    assert imported == ["world"]


def test_weekly_skipimport_does_not_update_db_state(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_weekly_skipimport")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), skipimport=True)
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")

    monkeypatch.setattr(ingest, "sync_pbf", lambda config, selected: None)
    monkeypatch.setattr(ingest, "pbf_replication_sequence", lambda path: 42)
    monkeypatch.setattr(ingest, "read_import_state", lambda config, region, sequence_number: None)
    monkeypatch.setattr(ingest, "import_extracts_and_write", lambda *args: pytest.fail("skipimport must not import OSM"))
    monkeypatch.setattr(ingest, "write_import_state", lambda *args: pytest.fail("skipimport must not update state"))
    monkeypatch.setattr(ingest, "run_startup_imports", lambda config: None)

    assert ingest.run_weekly_cycle(cfg, ext) is True


def test_weekly_import_state_is_written_before_non_osm_failure(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_weekly_state_before_non_osm")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), extradatadir="/non-osm")
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")
    events = []

    monkeypatch.setattr(ingest, "sync_pbf", lambda config, selected: None)
    monkeypatch.setattr(ingest, "pbf_replication_sequence", lambda path: 44)
    monkeypatch.setattr(ingest, "read_import_state", lambda config, region, sequence_number: None)
    monkeypatch.setattr(
        ingest,
        "import_extracts_and_write",
        lambda config, selected, incremental=False: events.append("osm"),
    )
    monkeypatch.setattr(
        ingest,
        "write_import_state",
        lambda config, marker: events.append(("state", marker["sequence_number"])),
    )
    monkeypatch.setattr(
        ingest,
        "import_non_osm",
        lambda config: (_ for _ in ()).throw(ingest.NonOsmIngestError("non-osm failed")),
    )

    with pytest.raises(ingest.NonOsmIngestError):
        ingest.run_weekly_cycle(cfg, ext)

    assert events == ["osm", ("state", 44)]


def test_weekly_import_uses_three_phase_imposm_without_diff(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_weekly_imposm_commands")
    cfg = base_config(ingest, tmp_path)
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")
    calls = []

    monkeypatch.setattr(
        ingest.subprocess,
        "run",
        lambda cmd, check=False, **kwargs: calls.append(cmd) or SimpleNamespace(returncode=0),
    )

    ingest.import_extracts_and_write(cfg, ext, incremental=False)

    assert len(calls) == 3
    assert "-read" in calls[0]
    assert "-write" in calls[1]
    assert "-deployproduction" in calls[2]
    assert all("-diff" not in cmd for cmd in calls)


def write_diff_state(ingest, cfg):
    Path(cfg.cachedir).mkdir(parents=True)
    (Path(cfg.cachedir) / "coords").write_text("cache", encoding="utf8")
    Path(cfg.diffdir).mkdir(parents=True)
    (Path(cfg.diffdir) / ingest.IMPOSM_LAST_STATE).write_text("sequenceNumber=1\n", encoding="utf8")


def write_ingest_state(ingest, cfg, ext):
    seed_path = ingest.pbf_path(cfg, ext)
    seed_path.write_text("pbf", encoding="utf8")
    ingest.write_state(ingest.state_path(cfg), ingest.legacy_pbf_marker(seed_path, ext))


def test_existing_diff_state_starts_imposm_run_without_seed_download(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_existing_diff")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    write_diff_state(ingest, cfg)
    write_ingest_state(ingest, cfg, ext)
    events = []

    monkeypatch.setattr(ingest, "download_seed", lambda *args: pytest.fail("seed should not be downloaded"))
    monkeypatch.setattr(ingest, "import_extract_for_imposm_run", lambda *args: pytest.fail("import should be skipped"))
    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: events.append("soundscape"))
    monkeypatch.setattr(ingest, "run_imposm", lambda config, selected: events.append(("run", selected["name"])) or 7)

    assert ingest.run_ingest(cfg, ext) == 7
    assert events == ["soundscape", ("run", "district-of-columbia")]


def test_region_change_downloads_seed_even_with_existing_diff_state(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_region_change")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    previous = extract("united-kingdom", "https://example.test/uk.osm.pbf")
    selected = extract("world", "https://example.test/world.osm.pbf")
    write_diff_state(ingest, cfg)
    write_ingest_state(ingest, cfg, previous)
    events = []

    def fake_download(url, destination, sha256=None):
        events.append(("download", url, destination.name))
        destination.write_text("world pbf", encoding="utf8")

    def fake_import(config, selected_extract):
        events.append(("import", selected_extract["name"]))

    monkeypatch.setattr(ingest, "download_seed", fake_download)
    monkeypatch.setattr(ingest, "import_extract_for_imposm_run", fake_import)
    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: events.append("soundscape"))

    assert ingest.bootstrap(cfg, selected) is True
    assert events == [
        ("download", "https://example.test/world.osm.pbf", "world.osm.pbf"),
        ("import", "world"),
        "soundscape",
    ]

    state = ingest.read_state(ingest.state_path(cfg))
    assert state["region"] == "world"
    assert state["url"] == "https://example.test/world.osm.pbf"
    assert state["pbf"] == "world.osm.pbf"


def test_recent_pbf_skips_download_but_still_imports(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_recent_pbf")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    seed_path = ingest.pbf_path(cfg, ext)
    seed_path.write_text("recent pbf", encoding="utf8")
    events = []

    def fake_import(config, selected):
        events.append(("import", selected["name"]))

    monkeypatch.setattr(ingest, "download_seed", lambda *args: pytest.fail("recent seed should not be downloaded"))
    monkeypatch.setattr(ingest, "import_extract_for_imposm_run", fake_import)
    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: events.append("soundscape"))

    assert ingest.bootstrap(cfg, ext) is True
    assert events == [
        ("import", "district-of-columbia"),
        "soundscape",
    ]

    state = ingest.read_state(ingest.state_path(cfg))
    assert state["region"] == "district-of-columbia"
    assert state["url"] == "https://example.test/district.osm.pbf"
    assert state["pbf"] == "district.osm.pbf"


def test_stale_pbf_downloads_seed_and_imports(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_missing_diff")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    seed_path = ingest.pbf_path(cfg, ext)
    seed_path.write_text("stale pbf", encoding="utf8")
    stale_time = time.time() - ingest.seconds_from_days(cfg.pbf_reuse_days + 1)
    os.utime(seed_path, (stale_time, stale_time))
    events = []

    def fake_download(url, destination, sha256=None):
        events.append(("download", url, destination.name))
        destination.write_text("pbf", encoding="utf8")

    def fake_import(config, selected):
        events.append(("import", selected["name"]))

    monkeypatch.setattr(ingest, "download_seed", fake_download)
    monkeypatch.setattr(ingest, "import_extract_for_imposm_run", fake_import)
    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: events.append("soundscape"))

    assert ingest.bootstrap(cfg, ext) is True
    assert events == [
        ("download", "https://example.test/district.osm.pbf", "district.osm.pbf"),
        ("import", "district-of-columbia"),
        "soundscape",
    ]


def test_lock_wraps_bootstrap(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_lock")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    events = []

    def fake_flock(fd, operation):
        events.append(("lock", operation))

    def fake_download(url, destination, sha256=None):
        destination.write_text("pbf", encoding="utf8")

    monkeypatch.setattr(ingest.fcntl, "flock", fake_flock)
    monkeypatch.setattr(ingest, "download_seed", fake_download)
    monkeypatch.setattr(ingest, "import_extract_for_imposm_run", lambda config, selected: events.append(("import", None)))
    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: None)

    ingest.bootstrap(cfg, ext)

    assert events[0] == ("lock", ingest.fcntl.LOCK_EX)
    assert events[1] == ("import", None)
    assert events[-1] == ("lock", ingest.fcntl.LOCK_UN)


def test_no_sourceupdate_skips_imposm_run(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_no_sourceupdate")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), sourceupdate=False)
    ext = extract()
    write_diff_state(ingest, cfg)
    write_ingest_state(ingest, cfg, ext)

    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: None)
    monkeypatch.setattr(ingest, "run_imposm", lambda *args: pytest.fail("imposm run should be skipped"))

    assert ingest.run_ingest(cfg, ext) == 0


def test_weekly_no_sourceupdate_exits_after_first_cycle(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_weekly_no_sourceupdate")
    cfg = base_config(ingest, tmp_path, sourceupdate=False)
    ext = extract()
    cycles = []

    monkeypatch.setattr(ingest, "load_selected_extract", lambda config: ext)
    monkeypatch.setattr(ingest, "run_weekly_ingest", lambda config, selected: cycles.append(selected) or 0)

    status = ingest.supervise_weekly_ingest(
        cfg,
        sleeper=lambda delay: pytest.fail("weekly ingest should not schedule another cycle"),
    )

    assert status == 0
    assert cycles == [ext]


def test_run_once_skips_imposm_run(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_run_once")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), run_once=True)
    ext = extract()
    write_diff_state(ingest, cfg)
    write_ingest_state(ingest, cfg, ext)

    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: None)
    monkeypatch.setattr(ingest, "run_imposm", lambda *args: pytest.fail("imposm run should be skipped"))

    assert ingest.run_ingest(cfg, ext) == 0


def test_imposm_run_skipimport_without_diff_state_fails_fast(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_skipimport_missing_diff")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), skipimport=True)
    ext = extract()
    notifications = []

    monkeypatch.setattr(ingest, "run_imposm", lambda *args: pytest.fail("imposm run should not start"))
    monkeypatch.setattr(ingest, "run_startup_imports", lambda *args: pytest.fail("startup imports should not run"))
    monkeypatch.setattr(ingest, "send_ntfy_notification", lambda *args: notifications.append(args))

    assert ingest.run_ingest(cfg, ext) == 1
    assert notifications[0][2] == "bootstrap"
    assert isinstance(notifications[0][3], ingest.BootstrapIngestError)


def test_supervise_ingest_retries_failed_service_cycle(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_supervise_retry")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), retry_days=0.25)
    ext = extract()
    attempts = []
    sleeps = []

    def fake_load(selected_config):
        assert selected_config is cfg
        return ext

    def fake_run(selected_config, selected_extract):
        assert selected_config is cfg
        assert selected_extract is ext
        attempts.append(len(attempts))
        return 1 if len(attempts) == 1 else 0

    monkeypatch.setattr(ingest, "load_selected_extract", fake_load)
    monkeypatch.setattr(ingest, "run_ingest", fake_run)

    assert ingest.supervise_ingest(cfg, sleeper=sleeps.append) == 0
    assert attempts == [0, 1]
    assert sleeps == [ingest.seconds_from_days(0.25)]


def test_supervise_ingest_run_once_returns_failed_cycle(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_supervise_run_once_failure")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), run_once=True)
    ext = extract()
    sleeps = []

    monkeypatch.setattr(ingest, "load_selected_extract", lambda config: ext)
    monkeypatch.setattr(ingest, "run_ingest", lambda config, selected: 1)

    assert ingest.supervise_ingest(cfg, sleeper=sleeps.append) == 1
    assert sleeps == []


def test_ntfy_payload_and_disabled_mode(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_ntfy")
    cfg = base_config(
        ingest,
        tmp_path,
        ntfy_topic="soundscape-alerts",
        ntfy_token="secret",
        ntfy_priority="urgent",
    )
    captured = {}

    class Response:
        def close(self):
            captured["closed"] = True

    def fake_urlopen(request, timeout):
        captured["url"] = request.full_url
        captured["headers"] = request.header_items()
        captured["body"] = request.data.decode("utf8")
        captured["timeout"] = timeout
        return Response()

    monkeypatch.setattr(ingest.urllib.request, "urlopen", fake_urlopen)
    ingest.send_ntfy_notification(cfg, "dc", "pbf_sync", RuntimeError("boom"), 3600)

    assert captured["url"] == "https://ntfy.sh/soundscape-alerts"
    assert ("Authorization", "Bearer secret") in captured["headers"]
    assert ("Priority", "urgent") in captured["headers"]
    assert "region: dc" in captured["body"]
    assert "stage: pbf_sync" in captured["body"]
    assert "next_retry_hours: 1.00" in captured["body"]

    captured.clear()
    ingest.send_ntfy_notification(replace(cfg, ntfy_topic=None), "dc", "cycle", RuntimeError("boom"), 3600)
    assert captured == {}


def test_imposm_output_alerts_on_fatal_and_throttles_errors(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_imposm_alerts")
    cfg = base_config(ingest, tmp_path, ntfy_topic="topic")
    notifications = []
    clock = SimpleNamespace(now=0.0)
    alerted = {}

    monkeypatch.setattr(ingest, "send_ntfy_notification", lambda *args: notifications.append(args))

    ingest.maybe_alert_imposm_output(cfg, "dc", "[fatal] unable to read last.state.txt", alerted, lambda: clock.now)
    ingest.maybe_alert_imposm_output(cfg, "dc", "[error] transient replication failure", alerted, lambda: clock.now)
    ingest.maybe_alert_imposm_output(cfg, "dc", "[error] transient replication failure", alerted, lambda: clock.now)
    clock.now += ingest.NTFY_ERROR_THROTTLE_SECONDS + 1
    ingest.maybe_alert_imposm_output(cfg, "dc", "[error] transient replication failure", alerted, lambda: clock.now)

    assert [call[2] for call in notifications] == ["imposm_run", "imposm_run", "imposm_run"]
    assert "[fatal]" in str(notifications[0][3])
    assert "[error]" in str(notifications[1][3])


def test_imposm_run_nonzero_exit_notifies_and_returns_status(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_imposm_exit")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), ntfy_topic="topic")
    ext = extract()
    notifications = []
    captured = {}

    class Process:
        def __init__(self):
            self.stdout = io.StringIO("[info] starting\n")
            self.stderr = io.StringIO("")

        def wait(self):
            return 2

    def fake_popen(command, **kwargs):
        captured["command"] = command
        captured["kwargs"] = kwargs
        return Process()

    monkeypatch.setattr(ingest, "send_ntfy_notification", lambda *args: notifications.append(args))

    assert ingest.run_imposm(cfg, ext, popen_factory=fake_popen) == 2
    assert captured["command"] == ["imposm", "run", "-config", str(tmp_path / "imposm.json")]
    assert captured["kwargs"]["stdout"] == subprocess.PIPE
    assert captured["kwargs"]["stderr"] == subprocess.PIPE
    assert notifications[-1][2] == "imposm_run_exit"
    assert "status 2" in str(notifications[-1][3])


def test_imposm_run_zero_exit_returns_success_without_notification(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_imposm_clean_exit")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), ntfy_topic="topic")
    ext = extract()
    notifications = []

    class Process:
        def __init__(self):
            self.stdout = io.StringIO("")
            self.stderr = io.StringIO("")

        def wait(self):
            return 0

    monkeypatch.setattr(ingest, "send_ntfy_notification", lambda *args: notifications.append(args))

    assert ingest.run_imposm(cfg, ext, popen_factory=lambda command, **kwargs: Process()) == 0
    assert notifications == []


def test_daily_non_osm_import_runs_once_per_interval_and_alerts_on_failure(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_daily_non_osm")
    cfg = base_config(ingest, tmp_path, extradatadir="/non-osm", ntfy_topic="topic")
    imports = []
    notifications = []

    class StopEvent:
        def __init__(self):
            self.waits = 0

        def wait(self, seconds):
            self.waits += 1
            assert seconds == ingest.NON_OSM_IMPORT_INTERVAL_SECONDS
            return self.waits > 2

    def fake_import(config):
        imports.append(config.extradatadir)
        if len(imports) == 2:
            raise ingest.NonOsmIngestError("daily import failed")

    monkeypatch.setattr(ingest, "import_non_osm", fake_import)
    monkeypatch.setattr(ingest, "send_ntfy_notification", lambda *args: notifications.append(args))

    ingest.run_daily_non_osm_imports(cfg, "dc", StopEvent())

    assert imports == ["/non-osm", "/non-osm"]
    assert notifications[0][2] == "non_osm_import"
    assert notifications[0][4] == ingest.NON_OSM_IMPORT_INTERVAL_SECONDS


def test_imposm_run_starts_daily_non_osm_scheduler_when_configured(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_imposm_daily_non_osm")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"), extradatadir="/non-osm")
    ext = extract()
    scheduler_calls = []

    class Process:
        def __init__(self):
            self.stdout = io.StringIO("")
            self.stderr = io.StringIO("")

        def wait(self):
            return 2

    def fake_scheduler(config, region, stop_event):
        scheduler_calls.append((config.extradatadir, region, stop_event.is_set()))

    monkeypatch.setattr(ingest, "run_daily_non_osm_imports", fake_scheduler)
    monkeypatch.setattr(ingest, "send_ntfy_notification", lambda *args: None)

    assert ingest.run_imposm(cfg, ext, popen_factory=lambda command, **kwargs: Process()) == 2
    assert scheduler_calls == [("/non-osm", "district-of-columbia", False)]


def test_non_osm_direct_dsn_uses_compose_env(monkeypatch):
    module = load_non_osm("non_osm_direct_dsn")

    monkeypatch.setenv("POSTGIS_HOST", "postgis")
    monkeypatch.setenv("POSTGIS_PORT", "5432")
    monkeypatch.setenv("POSTGIS_USER", "postgres")
    monkeypatch.setenv("POSTGIS_PASSWORD", "secret")
    monkeypatch.setenv("POSTGIS_DBNAME", "osm")

    assert module.build_postgres_dsn() == "host=postgis port=5432 user=postgres password=secret dbname=osm"


def test_non_osm_direct_dsn_escapes_libpq_values(monkeypatch):
    module = load_non_osm("non_osm_direct_dsn_escaped")

    monkeypatch.setenv("POSTGIS_HOST", "post gis")
    monkeypatch.setenv("POSTGIS_PORT", "5432")
    monkeypatch.setenv("POSTGIS_USER", "post gres")
    monkeypatch.setenv("POSTGIS_PASSWORD", "sec ret'\\")
    monkeypatch.setenv("POSTGIS_DBNAME", "os m")

    parsed = module.psycopg2.extensions.parse_dsn(module.build_postgres_dsn())

    assert parsed == {
        "user": "post gres",
        "password": "sec ret'\\",
        "dbname": "os m",
        "host": "post gis",
        "port": "5432",
    }


def test_non_osm_provisioning_creates_schema_without_truncating(monkeypatch):
    module = load_non_osm("non_osm_provision_schema")
    cursor = FakeAsyncCursor()

    monkeypatch.setattr(
        module.aiopg,
        "connect",
        lambda dsn: FakeAiopgConnection(cursor),
    )

    module.asyncio.run(module.provision_non_osm_data_async("host=postgis dbname=osm"))

    texts = sql_texts(cursor)
    assert len(texts) == 1
    assert "CREATE TABLE IF NOT EXISTS non_osm_data" in texts[0]
    assert all("TRUNCATE non_osm_data" not in text for text in texts)


def test_non_osm_import_reloads_data_in_transaction(tmp_path, monkeypatch):
    module = load_non_osm("non_osm_import_transaction")
    cursor = FakeAsyncCursor()
    csv_path = tmp_path / "stops.csv"
    csv_path.write_text(
        "feature_type,feature_value,longitude,latitude,name\n"
        "transit,stop,-122.1,47.6,Stop A\n",
        encoding="utf8",
    )

    monkeypatch.setattr(
        module.aiopg,
        "connect",
        lambda dsn: FakeAiopgConnection(cursor),
    )

    module.asyncio.run(module.import_non_osm_data_async(tmp_path, "host=postgis dbname=osm", module.logger))

    texts = sql_texts(cursor)
    assert texts[0] == "BEGIN"
    assert "CREATE TABLE IF NOT EXISTS non_osm_data" in texts[1]
    assert texts[2] == "TRUNCATE non_osm_data"
    assert texts[3] == "SAVEPOINT non_osm_file"
    assert "INSERT INTO non_osm_data" in texts[4]
    assert texts[5] == "RELEASE SAVEPOINT non_osm_file"
    assert texts[-1] == "COMMIT"
    assert all("ROLLBACK" not in text for text in texts)
    assert cursor.commands[4][1] == (
        10**17 + 1,
        "transit",
        "stop",
        {"name": "Stop A"},
        -122.1,
        47.6,
    )


def test_non_osm_import_skips_non_csv_entries(tmp_path, monkeypatch):
    module = load_non_osm("non_osm_import_csv_filter")
    cursor = FakeAsyncCursor()
    csv_path = tmp_path / "stops.CSV"
    csv_path.write_text(
        "feature_type,feature_value,longitude,latitude,name\n"
        "transit,stop,-122.1,47.6,Stop A\n",
        encoding="utf8",
    )
    (tmp_path / ".DS_Store").write_text("not,csv\n", encoding="utf8")
    (tmp_path / "nested.csv").mkdir()

    monkeypatch.setattr(
        module.aiopg,
        "connect",
        lambda dsn: FakeAiopgConnection(cursor),
    )

    module.asyncio.run(module.import_non_osm_data_async(tmp_path, "host=postgis dbname=osm", module.logger))

    texts = sql_texts(cursor)
    assert sum("INSERT INTO non_osm_data" in text for text in texts) == 1
    assert texts[-1] == "COMMIT"


def test_non_osm_import_reports_bad_file_after_committing_other_files(tmp_path, monkeypatch):
    module = load_non_osm("non_osm_import_partial_failure")
    cursor = FakeAsyncCursor()
    bad_path = tmp_path / "bad.csv"
    bad_path.write_text(
        "feature_type,feature_value,longitude,latitude\n"
        "transit,stop,not-a-number,47.6\n",
        encoding="utf8",
    )
    good_path = tmp_path / "good.csv"
    good_path.write_text(
        "feature_type,feature_value,longitude,latitude,name\n"
        "transit,stop,-122.1,47.6,Stop A\n",
        encoding="utf8",
    )

    monkeypatch.setattr(
        module.aiopg,
        "connect",
        lambda dsn: FakeAiopgConnection(cursor),
    )

    with pytest.raises(RuntimeError, match="successful files were committed.*bad.csv.*ValueError"):
        module.asyncio.run(module.import_non_osm_data_async(tmp_path, "host=postgis dbname=osm", module.logger))

    texts = sql_texts(cursor)
    assert texts[0] == "BEGIN"
    assert "CREATE TABLE IF NOT EXISTS non_osm_data" in texts[1]
    assert texts[2] == "TRUNCATE non_osm_data"
    assert texts[3] == "SAVEPOINT non_osm_file"
    assert texts[4] == "ROLLBACK TO SAVEPOINT non_osm_file"
    assert texts[5] == "RELEASE SAVEPOINT non_osm_file"
    assert texts[6] == "SAVEPOINT non_osm_file"
    assert "INSERT INTO non_osm_data" in texts[7]
    assert texts[8] == "RELEASE SAVEPOINT non_osm_file"
    assert texts[-1] == "COMMIT"
    assert all(text != "ROLLBACK" for text in texts)


def test_import_database_wraps_subprocess_failures_as_db_errors(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_db_failure")
    cfg = base_config(ingest, tmp_path)
    ext = extract()

    def fail_import(config, selected, incremental=False):
        raise subprocess.CalledProcessError(1, ["imposm"])

    monkeypatch.setattr(ingest, "import_extracts_and_write", fail_import)

    with pytest.raises(ingest.DbIngestError):
        ingest.import_database(cfg, ext)
