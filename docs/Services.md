# Services

The services for Soundscape consist of:
* An ingester that ingests OSM data and injects into a PostGIS database
* A tile service that constructs GeoJSON tiles on demand from the PostGIS database
* Additional services which could not be released to open source.

The current local service stack is orchestrated with Docker Compose. See
[`svcs/data/docker-compose.yml`](../svcs/data/docker-compose.yml).

# Ingester automation

Much of the automation for the OSM ingestion is missing from this
release.  The released version used IMPOSM3 for injestion.  OSM2PGSQL
was tested as an alternative.
