# Copyright (c) Soundscape Community Contributors.
# Licensed under the MIT License.

import importlib.util
import json
import subprocess
import sys
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


def base_config(ingest, tmp_path, **overrides):
    config = ingest.IngestConfig(
        skipimport=False,
        sourceupdate=True,
        telemetry=False,
        interval_days=7,
        retry_days=1,
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
        run_once=True,
        ntfy_topic=None,
        ntfy_server="https://ntfy.sh",
        ntfy_token=None,
        ntfy_priority="high",
    )
    return replace(config, **overrides)


def extract(name="district-of-columbia", url="https://example.test/district.osm.pbf"):
    return {"name": name, "url": url, "bbox": [0, 0, 0, 0]}


def write_extracts(path, extracts):
    path.write_text(json.dumps(extracts), encoding="utf8")


def test_import_is_safe(monkeypatch):
    called = False

    def fail_if_called(*args, **kwargs):
        nonlocal called
        called = True

    monkeypatch.setattr(sys, "argv", ["ingest.py"])
    ingest = load_ingest("ingest_import_safe")
    monkeypatch.setattr(ingest, "main", fail_if_called)
    assert called is False


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


def test_seed_download_uses_temp_file_and_atomic_rename(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_seed")
    destination = tmp_path / "region.osm.pbf"
    seen = {}

    def fake_urlretrieve(url, tmp):
        seen["url"] = url
        seen["tmp"] = Path(tmp)
        assert not destination.exists()
        Path(tmp).write_text("pbf", encoding="utf8")

    monkeypatch.setattr(ingest.urllib.request, "urlretrieve", fake_urlretrieve)

    ingest.download_seed("https://example.test/region.osm.pbf", destination)

    assert seen["url"] == "https://example.test/region.osm.pbf"
    assert seen["tmp"].name == ".region.osm.pbf.download"
    assert destination.read_text(encoding="utf8") == "pbf"
    assert not seen["tmp"].exists()


def test_pyosmium_return_codes(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_pyosmium")
    cfg = base_config(ingest, tmp_path)
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")

    calls = []

    def fake_run(cmd, check=False):
        calls.append(cmd)
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(ingest.subprocess, "run", fake_run)
    assert ingest.sync_pbf(cfg, ext) is False
    assert calls == [["pyosmium-up-to-date", str(ingest.pbf_path(cfg, ext))]]

    returns = [1, 1, 0]

    def fake_run_updates(cmd, check=False):
        return SimpleNamespace(returncode=returns.pop(0))

    monkeypatch.setattr(ingest.subprocess, "run", fake_run_updates)
    assert ingest.sync_pbf(cfg, ext) is True
    assert returns == []

    monkeypatch.setattr(ingest.subprocess, "run", lambda cmd, check=False: SimpleNamespace(returncode=2))
    with pytest.raises(ingest.PbfSyncError):
        ingest.sync_pbf(cfg, ext)


def test_unchanged_state_skips_database_import(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_skip_import")
    cfg = base_config(ingest, tmp_path)
    ext = extract()
    path = ingest.pbf_path(cfg, ext)
    path.write_text("pbf", encoding="utf8")
    ingest.write_state(ingest.state_path(cfg), ingest.pbf_marker(path, ext))

    monkeypatch.setattr(ingest, "sync_pbf", lambda config, selected: False)
    monkeypatch.setattr(ingest, "import_database", lambda config, selected: pytest.fail("import should be skipped"))

    assert ingest.run_cycle(cfg, ext) is True


def test_missing_or_changed_state_imports_database(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_import_needed")
    cfg = base_config(ingest, tmp_path)
    ext = extract()
    path = ingest.pbf_path(cfg, ext)
    path.write_text("pbf", encoding="utf8")
    imported = []

    monkeypatch.setattr(ingest, "sync_pbf", lambda config, selected: False)
    monkeypatch.setattr(ingest, "import_database", lambda config, selected: imported.append(selected["name"]))

    assert ingest.run_cycle(cfg, ext) is True
    assert imported == ["district-of-columbia"]
    assert json.loads(ingest.state_path(cfg).read_text(encoding="utf8"))["pbf"] == path.name


def test_lock_wraps_update_and_import(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_lock")
    cfg = base_config(ingest, tmp_path)
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("pbf", encoding="utf8")
    events = []

    def fake_flock(fd, operation):
        events.append(("lock", operation))

    def fake_sync(config, selected):
        events.append(("sync", None))
        return True

    def fake_import(config, selected):
        events.append(("import", None))

    monkeypatch.setattr(ingest.fcntl, "flock", fake_flock)
    monkeypatch.setattr(ingest, "sync_pbf", fake_sync)
    monkeypatch.setattr(ingest, "import_database", fake_import)

    ingest.run_cycle(cfg, ext)

    assert events[0] == ("lock", ingest.fcntl.LOCK_EX)
    assert events[1:3] == [("sync", None), ("import", None)]
    assert events[-1] == ("lock", ingest.fcntl.LOCK_UN)


def test_scheduler_runs_immediately_and_coalesces_missed_interval(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_scheduler")
    cfg = base_config(ingest, tmp_path, run_once=False, interval_days=10 / ingest.SECONDS_PER_DAY)
    ext = extract()
    clock = SimpleNamespace(now=0.0)
    sleeps = []
    calls = []

    def fake_run_cycle(config, selected):
        calls.append(clock.now)
        if len(calls) == 1:
            clock.now += 20
        else:
            config.run_once = True
        return True

    def fake_sleep(seconds):
        sleeps.append(seconds)
        clock.now += seconds

    monkeypatch.setattr(ingest, "run_cycle", fake_run_cycle)

    assert ingest.run_scheduler(cfg, ext, sleep=fake_sleep, monotonic=lambda: clock.now) is True
    assert calls == [0.0, 20.0]
    assert sleeps == []


def test_scheduler_retries_after_failure_and_notifies(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_scheduler_failure")
    cfg = base_config(ingest, tmp_path, run_once=True, retry_days=2, ntfy_topic="topic")
    ext = extract()
    notifications = []

    def fake_run_cycle(config, selected):
        raise ingest.DbIngestError("write failed")

    monkeypatch.setattr(ingest, "run_cycle", fake_run_cycle)
    monkeypatch.setattr(ingest, "send_ntfy_notification", lambda *args: notifications.append(args))

    assert ingest.run_scheduler(cfg, ext) is False
    assert notifications[0][2] == "database_ingest"
    assert notifications[0][4] == 2 * ingest.SECONDS_PER_DAY


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


def test_non_osm_direct_dsn_uses_compose_env(monkeypatch):
    spec = importlib.util.spec_from_file_location("non_osm_under_test", NON_OSM_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["non_osm_under_test"] = module
    spec.loader.exec_module(module)

    monkeypatch.setenv("POSTGIS_HOST", "postgis")
    monkeypatch.setenv("POSTGIS_PORT", "5432")
    monkeypatch.setenv("POSTGIS_USER", "postgres")
    monkeypatch.setenv("POSTGIS_PASSWORD", "secret")
    monkeypatch.setenv("POSTGIS_DBNAME", "osm")

    assert module.build_postgres_dsn() == "host=postgis port=5432 user=postgres password=secret dbname=osm"


def test_import_database_wraps_subprocess_failures_as_db_errors(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_db_failure")
    cfg = base_config(ingest, tmp_path)
    ext = extract()

    def fail_import(config, selected, incremental):
        raise subprocess.CalledProcessError(1, ["imposm"])

    monkeypatch.setattr(ingest, "import_extracts_and_write", fail_import)

    with pytest.raises(ingest.DbIngestError):
        ingest.import_database(cfg, ext)
