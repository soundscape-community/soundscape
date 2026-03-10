#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DATA_DIR="${IOS_DIR}/GuideDogs/Code/Data"
readonly CODE_DIR="${IOS_DIR}/GuideDogs/Code"
readonly UNIT_TESTS_DIR="${IOS_DIR}/UnitTests"
readonly PATTERN='SpatialDataCache\.'
readonly RETIRED_SYNC_STORE_PATTERN='\b(SpatialDataStoreRegistry|DefaultSpatialDataStore|SpatialDataStore)\b'

spatial_data_cache_output="$(
  rg --line-number --no-heading \
    --glob '*.swift' \
    --regexp "${PATTERN}" \
    "${CODE_DIR}" \
    | cut -d: -f1 \
    | sort -u \
    || true
)"

declare -a disallowed_spatial_data_cache_callers=()

while IFS= read -r caller; do
  [[ -z "${caller}" ]] && continue

  relative_caller="${caller#${IOS_DIR}/}"

  if [[ "${relative_caller}" == GuideDogs/Code/Data/Infrastructure/Realm/* ]]; then
    continue
  fi

  disallowed_spatial_data_cache_callers+=("${relative_caller}")
done <<< "${spatial_data_cache_output}"

if [[ ${#disallowed_spatial_data_cache_callers[@]} -gt 0 ]]; then
  echo "SpatialDataCache usage found outside the Realm infrastructure boundary." >&2
  echo "Disallowed callers:" >&2
  printf "  %s\n" "${disallowed_spatial_data_cache_callers[@]}" >&2
  echo "Allowed path prefix:" >&2
  echo "  GuideDogs/Code/Data/Infrastructure/Realm/" >&2
  exit 1
fi

echo "SpatialDataCache usage is confined to Data/Infrastructure/Realm."

retired_sync_store_output="$(
  rg --line-number --no-heading \
    --glob '*.swift' \
    --regexp "${RETIRED_SYNC_STORE_PATTERN}" \
    "${CODE_DIR}" \
    "${UNIT_TESTS_DIR}" \
    || true
)"

declare -a retired_sync_store_callers=()
while IFS= read -r caller; do
  [[ -z "${caller}" ]] && continue
  retired_sync_store_callers+=("${caller#${IOS_DIR}/}")
done <<< "${retired_sync_store_output}"

if [[ ${#retired_sync_store_callers[@]} -gt 0 ]]; then
  echo "Retired sync-store seam symbols found in app or unit-test Swift sources." >&2
  echo "Disallowed matches:" >&2
  printf "  %s\n" "${retired_sync_store_callers[@]}" >&2
  exit 1
fi

echo "Retired sync-store seam symbols remain absent from GuideDogs/Code and UnitTests."
