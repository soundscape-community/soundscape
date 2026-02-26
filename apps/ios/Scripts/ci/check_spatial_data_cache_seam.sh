#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DATA_DIR="${IOS_DIR}/GuideDogs/Code/Data"
readonly CODE_DIR="${IOS_DIR}/GuideDogs/Code"
readonly PATTERN='SpatialDataCache\.'
readonly STORE_REGISTRY_PATTERN='SpatialDataStoreRegistry\.store\.'

# Direct SpatialDataCache usage is allowed only in:
# the cache implementation itself
if rg --line-number --no-heading \
  --glob '*.swift' \
  --glob '!**/SpatialDataCache.swift' \
  --regexp "${PATTERN}" \
  "${DATA_DIR}"; then
  echo "Direct SpatialDataCache usage found outside allowed seam files." >&2
  echo "Allowed files:" >&2
  echo "  GuideDogs/Code/Data/Infrastructure/Realm/SpatialDataCache.swift" >&2
  exit 1
fi

echo "No direct SpatialDataCache usage found outside allowed seam files."

store_registry_output="$(
  rg --line-number --no-heading \
    --glob '*.swift' \
    --glob '!**/Data/Infrastructure/Realm/**' \
    --regexp "${STORE_REGISTRY_PATTERN}" \
    "${CODE_DIR}" \
    | cut -d: -f1 \
    | sort -u \
    || true
)"

declare -a store_registry_callers=()
while IFS= read -r caller; do
  [[ -z "${caller}" ]] && continue
  store_registry_callers+=("${caller}")
done <<< "${store_registry_output}"

if [[ ${#store_registry_callers[@]} -gt 0 ]]; then
  echo "SpatialDataStoreRegistry.store usage found outside infrastructure boundary." >&2
  echo "Disallowed callers:" >&2
  printf "  %s\n" "${store_registry_callers[@]}" >&2
  echo "Allowed path prefix:" >&2
  echo "  GuideDogs/Code/Data/Infrastructure/Realm/" >&2
  exit 1
fi

echo "SpatialDataStoreRegistry.store usage is confined to Data/Infrastructure/Realm."
