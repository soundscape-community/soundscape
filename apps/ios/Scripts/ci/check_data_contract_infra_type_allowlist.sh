#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly CONTRACTS_DIR="${IOS_DIR}/GuideDogs/Code/Data/Contracts"

# All known Realm-backed model type names under Data/Infrastructure/Realm that
# could leak across the contract boundary.
readonly KNOWN_INFRA_TYPES=(
  Address
  GDASpatialDataResultEntity
  Intersection
  IntersectionRoadId
  OsmTag
  RealmReferenceEntity
  Road
  Route
  RouteWaypoint
  TileData
)

# Temporary allowlist while contracts are still being migrated to DTO/value types.
readonly ALLOWED_INFRA_TYPES_IN_CONTRACTS=(
  Intersection
  RealmReferenceEntity
  Road
  Route
  TileData
)

if [[ ! -d "${CONTRACTS_DIR}" ]]; then
  echo "Contracts directory not found; skipping infrastructure type allowlist check."
  exit 0
fi

known_pattern="$(printf "%s|" "${KNOWN_INFRA_TYPES[@]}")"
known_pattern="${known_pattern%|}"

detected_types_output="$(
  rg --no-heading --no-filename --glob '*.swift' --only-matching --replace '$1' --regexp "\\b(${known_pattern})\\b" "${CONTRACTS_DIR}" \
    | sort -u || true
)"

if [[ -z "${detected_types_output}" ]]; then
  echo "No Realm infrastructure model type references found in Data/Contracts."
  exit 0
fi

declare -a disallowed=()
declare -a detected_types=()

while IFS= read -r detected; do
  [[ -z "${detected}" ]] && continue
  detected_types+=("${detected}")

  is_allowed=0
  for allowed in "${ALLOWED_INFRA_TYPES_IN_CONTRACTS[@]}"; do
    if [[ "${allowed}" == "${detected}" ]]; then
      is_allowed=1
      break
    fi
  done

  if [[ ${is_allowed} -eq 0 ]]; then
    disallowed+=("${detected}")
  fi
done <<< "${detected_types_output}"

if [[ ${#disallowed[@]} -gt 0 ]]; then
  printf "Found non-allowlisted infrastructure model type references in Data/Contracts:\n" >&2
  printf " - %s\n" "${disallowed[@]}" >&2
  printf "Allowed temporary infrastructure types: %s\n" "${ALLOWED_INFRA_TYPES_IN_CONTRACTS[*]}" >&2
  exit 1
fi

echo "Data/Contracts infrastructure type allowlist check passed (detected: ${detected_types[*]})."
