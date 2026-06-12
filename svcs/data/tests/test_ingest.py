# Copyright (c) Soundscape Community Contributors.
# Licensed under the MIT License.

import importlib.util
import io
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


def test_bootstrap_import_does_not_call_pyosmium(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_no_pyosmium")
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
    assert all(cmd[0] != "pyosmium-up-to-date" for cmd in calls)
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
    assert generated["connection"] == "postgis://@postgis/osm"
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


def write_diff_state(ingest, cfg):
    Path(cfg.cachedir).mkdir(parents=True)
    (Path(cfg.cachedir) / "coords").write_text("cache", encoding="utf8")
    Path(cfg.diffdir).mkdir(parents=True)
    (Path(cfg.diffdir) / ingest.IMPOSM_LAST_STATE).write_text("sequenceNumber=1\n", encoding="utf8")


def test_existing_diff_state_starts_imposm_run_without_seed_download(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_existing_diff")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    write_diff_state(ingest, cfg)
    events = []

    monkeypatch.setattr(ingest, "download_seed", lambda *args: pytest.fail("seed should not be downloaded"))
    monkeypatch.setattr(ingest, "import_extracts_and_write", lambda *args: pytest.fail("import should be skipped"))
    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: events.append("soundscape"))
    monkeypatch.setattr(ingest, "run_imposm", lambda config, selected: events.append(("run", selected["name"])) or 7)

    assert ingest.run_ingest(cfg, ext) == 7
    assert events == ["soundscape", ("run", "district-of-columbia")]


def test_missing_diff_state_downloads_seed_and_imports(tmp_path, monkeypatch):
    ingest = load_ingest("ingest_missing_diff")
    cfg = base_config(ingest, tmp_path, config=str(tmp_path / "imposm.json"))
    ext = extract()
    ingest.pbf_path(cfg, ext).write_text("stale pbf", encoding="utf8")
    events = []

    def fake_download(url, destination, sha256=None):
        events.append(("download", url, destination.name))
        destination.write_text("pbf", encoding="utf8")

    def fake_import(config, selected):
        events.append(("import", selected["name"]))

    monkeypatch.setattr(ingest, "download_seed", fake_download)
    monkeypatch.setattr(ingest, "import_extracts_and_write", fake_import)
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
    monkeypatch.setattr(ingest, "import_extracts_and_write", lambda config, selected: events.append(("import", None)))
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

    monkeypatch.setattr(ingest, "provision_database_soundscape", lambda config: None)
    monkeypatch.setattr(ingest, "run_imposm", lambda *args: pytest.fail("imposm run should be skipped"))

    assert ingest.run_ingest(cfg, ext) == 0


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

    def fail_import(config, selected):
        raise subprocess.CalledProcessError(1, ["imposm"])

    monkeypatch.setattr(ingest, "import_extracts_and_write", fail_import)

    with pytest.raises(ingest.DbIngestError):
        ingest.import_database(cfg, ext)
