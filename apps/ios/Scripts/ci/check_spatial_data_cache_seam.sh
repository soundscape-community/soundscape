#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DATA_DIR="${IOS_DIR}/GuideDogs/Code/Data"
readonly PATTERN='SpatialDataCache\.'

# Direct SpatialDataCache usage is allowed only in:
# the cache implementation itself
if rg --line-number --no-heading \
  --glob '*.swift' \
  --glob '!**/SpatialDataCache.swift' \
  --regexp "${PATTERN}" \
  "${DATA_DIR}"; then
  echo "Direct SpatialDataCache usage found outside allowed seam files." >&2
  echo "Allowed files:" >&2
  echo "  GuideDogs/Code/Data/Spatial Data/SpatialDataCache.swift" >&2
  exit 1
fi

echo "No direct SpatialDataCache usage found outside allowed seam files."
