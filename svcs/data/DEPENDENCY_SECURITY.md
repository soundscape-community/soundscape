# Dependency security review — 2026-10-26

This review covers the Python requirements and the ingest/tile server container
images. It also checks the locally cached PostGIS image; it is not a security
assessment of the deployed database or host Caddy installation.

## Updates and compatibility

- `aiohttp` 3.14.1 → 3.14.5 fixes 11 distinct advisories reported by pip-audit,
  including request smuggling, resource exhaustion, and a C parser out-of-bounds
  read. The [upstream changelog](https://docs.aiohttp.org/en/v3.14.5/changes.html)
  describes stricter HTTP/form/cookie limits and internal WebSocket/writer changes.
  The service uses ordinary GET routes and does not use those internal APIs.
- `pytest` 8.4.0 → 9.0.3 fixes
  [CVE-2025-71176](https://docs.pytest.org/en/stable/changelog.html#pytest-9-0-3-2026-04-07).
  This is the first patched release. Version 9 drops Python 3.9, changes duplicate
  test-path handling, and treats deprecated APIs as errors. CI uses Python 3.12
  and one test directory; all 52 existing tests pass without suppression.
- `psycopg2-binary` 2.9.9 → 2.9.13 refreshes the bundled native libraries while
  retaining the psycopg2 API used by aiopg. The Linux amd64 wheel reports libpq
  17.11. This is a client library update, not a database server upgrade. See the
  [release notes](https://www.psycopg.org/docs/news.html).
- Both images keep Python 3.12 and Debian Bookworm, apply available Debian package
  updates, and install with pip 26.2.2. After installation and `pip check`, pip and
  the ensurepip bootstrap wheel are removed: even current pip vendors vulnerable
  msgpack, setuptools, and urllib3 versions. Installing packages interactively
  with pip in these runtime images is therefore no longer supported; rebuild the
  image to change dependencies.

## Validation

- pip-audit of runtime and development requirements: 12 distinct advisories before
  the update, zero known vulnerabilities in the newly resolved requirements after.
- All 52 ingest tests pass on local Python 3.12 and inside the rebuilt ingest image.
- Both Dockerfiles build successfully with a freshly pulled base image.
- Smoke checks against a disposable PostgreSQL 15 instance exercise psycopg2,
  aiopg pooling, both tile URL formats, an unsupported zoom returning 404, health,
  and metrics. Tile checks pass using the rebuilt tile server image. A stub SQL
  tile function provided the initial database/HTTP integration check; a subsequent
  full region test also passed (below).
- The ingest image passes CLI checks for ingest, Imposm, and pyosmium, plus writing
  and reading replication metadata in a tiny PBF.
- Trivy 0.76.1 reports zero Python package vulnerabilities and zero Debian
  vulnerabilities with available fixes in both final images. This does **not**
  mean the images have no remaining vulnerabilities (see below). Scanner coverage
  also does not establish that all native libraries bundled in wheels are safe.

## Remaining findings

- **Imposm:** the checksum-verified upstream 0.14.2 executable embeds Go 1.24.0.
  Trivy reports 68 findings (including one critical and 26 high) in its Go runtime
  and `golang.org/x/sys`. [0.14.2 is still the latest upstream release](https://github.com/omniscale/imposm3/releases/tag/v0.14.2).
  Applying Go/module fixes requires a maintained source build and validation of
  bootstrap imports, replication, and existing cache/database compatibility.
  These package findings have not been assessed for code-path reachability.
- **Debian:** Trivy still reports 283 OS findings in ingest and 270 in tilesrv,
  with no fixed Bookworm package versions in the scanner database at review time.
  These include critical findings against sqlite and zlib; assess applicability
  and distribution guidance separately rather than assuming every finding is
  reachable. Continue rebuilding for distribution security updates.
- **PostGIS:** Compose uses `postgis/postgis` without a version. The cached image
  inspected here was built on 2026-06-08 and contains PostgreSQL 17, PostGIS 3.5.2,
  and Debian 11.11. Trivy reports 1,212 OS findings (142 with fixes), plus 126 Go
  findings in gosu. These counts describe that cached image, not today's registry
  tag or production. Choose a supported image with the deployed PostgreSQL major,
  verify backups and PostGIS extension upgrades, and pin its version before
  rollout. The separate `.github/workflows/generate_json_tiles.yml` workflow pins
  `postgis/postgis:10-2.5` (PostgreSQL 10 / PostGIS 2.5); that pin does not apply to
  Compose. A PostgreSQL minor/security update within the same major does not
  normally require a database migration. The migration concern applies only if
  an unpinned image update crosses PostgreSQL majors. This change does not replace
  the database image.

## Full region import and tile requests

A subsequent end-to-end test used both updated images and a fresh, disposable
PostgreSQL 17.5 / PostGIS 3.5.2 database from the cached PostGIS image described
above. It did not use a stub tile function or an existing application database.

- Ran the ingest container with `--where district-of-columbia --provision
  --run-once`, the default `weekly-pbf` mode, the real mapping, isolated cache/PBF
  directories, and the repository's sample non-OSM data.
- Downloaded the 21 MB Geofabrik PBF, ran `pyosmium-up-to-date`, imported and
  deployed tables with Imposm, installed `postgis-vt-util.sql` and `tilefunc.sql`,
  and recorded replication sequence 4952. The container exited successfully.
- Verified 94,728 roads, 216,129 places, 785 entrances, and one non-OSM row.
- Started the updated tile server and requested these real tiles:

| Location | Tile | Features |
| --- | --- | ---: |
| White House | `/16/18743/25070.json` | 1,116 |
| Capitol | `/16/18748/25072.json` | 1,197 |
| Georgetown | `/16/18737/25068.json` | 1,445 |
| National Mall | `/16/18744/25072.json` | 638 |

For every tile, both the plain and `/tiles/` URL returned HTTP 200 with identical
GeoJSON, valid feature/geometry/properties fields, and a feature count matching
`SELECT count(*) FROM soundscape_tile(...)`. Health and metrics returned 200;
unsupported zoom and unknown routes returned 404; a tile outside the extract
returned an empty feature collection. This validates fresh imports and serving
on PostgreSQL 17; it does not validate a PostgreSQL major upgrade, an existing
production database, continuous replication, or a full planet import.

## Repeating the checks

From the repository root, use pip-audit and Trivy installed outside the runtime
images:

```sh
pip-audit -r svcs/data/requirements.txt -r svcs/data/requirements-dev.txt
python3 -m pytest svcs/data/tests
# Rebuild to refresh both the base and the apt/pip installation layers.
docker build --pull --no-cache -f svcs/data/Dockerfile.ingest -t soundscape-ingest:audit svcs/data
docker build --pull --no-cache -f svcs/data/Dockerfile.tilesrv -t soundscape-tilesrv:audit svcs/data
trivy image --scanners vuln soundscape-ingest:audit
trivy image --scanners vuln soundscape-tilesrv:audit
```

Requirements pin direct dependencies but not their transitive dependencies;
results can change on a subsequent build and should be checked again before
rollout. No running application services or existing database volumes were changed
for this review.
