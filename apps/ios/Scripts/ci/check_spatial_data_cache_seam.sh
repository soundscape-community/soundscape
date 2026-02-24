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

# Staged allowlist while non-infrastructure callers are migrated to
# DataContractRegistry contracts.
readonly ALLOWED_SPATIAL_DATA_STORE_CALLERS=(
  "${CODE_DIR}/Behaviors/Default/AutoCalloutGenerator.swift"
  "${CODE_DIR}/Behaviors/Default/Callouts/POICallout.swift"
  "${CODE_DIR}/Data/Models/Helpers/Roundabout.swift"
  "${CODE_DIR}/Data/Models/Protocols/Road.swift"
  "${CODE_DIR}/Data/Preview/RoadAdjacentDataView.swift"
  "${CODE_DIR}/Data/Serialization/LocationParameters.swift"
  "${CODE_DIR}/Data/Serialization/MarkerParameters.swift"
  "${CODE_DIR}/Data/Serialization/Routes/Extensions/RouteParameters+Codable.swift"
  "${CODE_DIR}/Data/Spatial Data/SpatialDataView.swift"
  "${CODE_DIR}/Visual UI/Helpers/Location/Location Detail/LocationDetail.swift"
)

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

declare -a disallowed_callers=()

for caller in "${store_registry_callers[@]}"; do
  allowed=0
  for allowed_caller in "${ALLOWED_SPATIAL_DATA_STORE_CALLERS[@]}"; do
    if [[ "${caller}" == "${allowed_caller}" ]]; then
      allowed=1
      break
    fi
  done

  if [[ ${allowed} -eq 0 ]]; then
    disallowed_callers+=("${caller}")
  fi
done

if [[ ${#disallowed_callers[@]} -gt 0 ]]; then
  echo "SpatialDataStoreRegistry.store usage found outside staged allowlist." >&2
  echo "Disallowed callers:" >&2
  printf "  %s\n" "${disallowed_callers[@]}" >&2
  echo "Staged allowlist callers:" >&2
  printf "  %s\n" "${ALLOWED_SPATIAL_DATA_STORE_CALLERS[@]}" >&2
  exit 1
fi

echo "SpatialDataStoreRegistry.store usage outside infrastructure is confined to staged allowlist."
