#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly CODE_DIR="${IOS_DIR}/GuideDogs/Code"
readonly PATTERN='Route\.(add|update|delete|deleteAll)\('

# Direct route mutation statics are allowed only in Realm infrastructure.
if rg --line-number --no-heading \
  --glob '*.swift' \
  --glob '!**/Data/Infrastructure/Realm/**' \
  --regexp "${PATTERN}" \
  "${CODE_DIR}"; then
  echo "Direct Route mutation usage found outside allowed seam files." >&2
  echo "Allowed paths:" >&2
  echo "  GuideDogs/Code/Data/Infrastructure/Realm/**" >&2
  exit 1
fi

echo "No direct Route mutation usage found outside allowed seam files."
