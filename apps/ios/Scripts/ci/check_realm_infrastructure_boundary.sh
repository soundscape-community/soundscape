#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly CODE_DIR="${IOS_DIR}/GuideDogs/Code"
readonly REALM_IMPORT_PATTERN='^\s*import\s+RealmSwift\b'

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

  disallowed_callers+=("${relative_caller}")
done <<< "${realm_import_output}"

if [[ ${#disallowed_callers[@]} -gt 0 ]]; then
  echo "RealmSwift import found outside infrastructure boundary." >&2
  echo "Disallowed callers:" >&2
  printf "  %s\n" "${disallowed_callers[@]}" >&2
  echo "Allowed path prefix:" >&2
  echo "  GuideDogs/Code/Data/Infrastructure/Realm/" >&2
  exit 1
fi

echo "RealmSwift imports are confined to Data/Infrastructure/Realm."
