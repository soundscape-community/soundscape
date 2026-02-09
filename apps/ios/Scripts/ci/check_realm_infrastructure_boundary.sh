#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DATA_DIR="${IOS_DIR}/GuideDogs/Code/Data"
readonly REALM_IMPORT_PATTERN='^\s*import\s+RealmSwift\b'

if rg --line-number --no-heading \
  --glob '*.swift' \
  --glob '!**/Infrastructure/Realm/**' \
  --regexp "${REALM_IMPORT_PATTERN}" \
  "${DATA_DIR}"; then
  echo "RealmSwift import found outside allowed infrastructure boundary." >&2
  echo "Allowed path prefix:" >&2
  echo "  GuideDogs/Code/Data/Infrastructure/Realm/" >&2
  exit 1
fi

echo "RealmSwift imports are confined to Data/Infrastructure/Realm."
