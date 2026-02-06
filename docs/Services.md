# Services

The open-source services in this repository are under [`svcs/data`](../svcs/data/).

They include:
- an ingestion pipeline that imports OSM and related datasets into PostGIS,
- tooling to generate and serve GeoJSON tile data used by the iOS client,
- supporting Docker, SQL, and utility scripts.

Some production services used by the community deployment are not part of this repository.

## Deployment Assets

- Docker and compose assets: [`svcs/data/docker-compose.yml`](../svcs/data/docker-compose.yml)
- Helm chart assets: [`svcs/data/soundscape`](../svcs/data/soundscape)

## Ingester Notes

Historically, the ingestion flow used IMPOSM3; OSM2PGSQL has also been evaluated as an alternative.
