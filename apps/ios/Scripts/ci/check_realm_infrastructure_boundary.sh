#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly CODE_DIR="${IOS_DIR}/GuideDogs/Code"
readonly REALM_IMPORT_PATTERN='^\s*import\s+RealmSwift\b'

declare -ra ALLOWED_NON_INFRA_REALM_IMPORT_CALLERS=(
  "GuideDogs/Code/Visual UI/Views/Location/Detail/LocationDetailLabelView.swift"
  "GuideDogs/Code/Visual UI/Views/Markers & Routes/MarkersAndRoutesList.swift"
  "GuideDogs/Code/Visual UI/Views/Markers & Routes/MarkerCell.swift"
  "GuideDogs/Code/Visual UI/Views/Markers & Routes/MarkersList.swift"
  "GuideDogs/Code/Visual UI/Views/Markers & Routes/RoutesList.swift"
  "GuideDogs/Code/Visual UI/Views/Markers & Routes/RouteCell.swift"
  "GuideDogs/Code/Visual UI/Views/Markers & Routes/Add & Update Routes/RouteEditView.swift"
  "GuideDogs/Code/Visual UI/Views/Markers & Routes/Add & Update Routes/WaypointAddList.swift"
)

realm_import_output="$(
  rg --line-number --no-heading \
    --glob '*.swift' \
    --regexp "${REALM_IMPORT_PATTERN}" \
    "${CODE_DIR}" \
    | cut -d: -f1 \
    | sort -u \
    || true
)"

declare -a disallowed_callers=()

while IFS= read -r caller; do
  [[ -z "${caller}" ]] && continue

  relative_caller="${caller#${IOS_DIR}/}"

  if [[ "${relative_caller}" == GuideDogs/Code/Data/Infrastructure/Realm/* ]]; then
    continue
  fi

  allowed=0
  for allowed_caller in "${ALLOWED_NON_INFRA_REALM_IMPORT_CALLERS[@]:-}"; do
    [[ -z "${allowed_caller}" ]] && continue
    if [[ "${relative_caller}" == "${allowed_caller}" ]]; then
      allowed=1
      break
    fi
  done

  if [[ ${allowed} -eq 0 ]]; then
    disallowed_callers+=("${relative_caller}")
  fi
done <<< "${realm_import_output}"

if [[ ${#disallowed_callers[@]} -gt 0 ]]; then
  echo "RealmSwift import found outside infrastructure/allowlist boundary." >&2
  echo "Disallowed callers:" >&2
  printf "  %s\n" "${disallowed_callers[@]}" >&2
  echo "Allowed path prefix:" >&2
  echo "  GuideDogs/Code/Data/Infrastructure/Realm/" >&2
  echo "Staged non-infrastructure allowlist:" >&2
  if [[ ${#ALLOWED_NON_INFRA_REALM_IMPORT_CALLERS[@]} -gt 0 ]]; then
    printf "  %s\n" "${ALLOWED_NON_INFRA_REALM_IMPORT_CALLERS[@]}" >&2
  else
    echo "  (none)" >&2
  fi
  exit 1
fi

echo "RealmSwift imports are confined to Data/Infrastructure/Realm or staged allowlist."
