#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly CODE_DIR="${IOS_DIR}/GuideDogs/Code"
readonly CONTRACTS_DIR="${IOS_DIR}/GuideDogs/Code/Data/Contracts"
readonly DOMAIN_DIR="${IOS_DIR}/GuideDogs/Code/Data/Domain"
readonly FORBIDDEN_IMPORT_PATTERN='^\s*import\s+(RealmSwift|CoreLocation|MapKit)\b'
readonly FORBIDDEN_RUNTIME_SYMBOL_PATTERN='\b(AppContext(\.shared)?|UIRuntimeProviderRegistry|BehaviorRuntimeProviderRegistry)\b'
readonly REALM_ADAPTER_SYMBOL_PATTERN='\b(RealmSpatialReadContract|RealmSpatialWriteContract|RealmSpatialMaintenanceWriteContract)\b'
readonly REALM_ADAPTER_ALLOWED_REGISTRY='GuideDogs/Code/Data/Contracts/Storage/DataContractRegistry.swift'
readonly REALM_ADAPTER_ALLOWED_INFRA_PREFIX='GuideDogs/Code/Data/Infrastructure/Realm/'

check_boundary_dir() {
  local dir="$1"
  local label="$2"

  if [[ ! -d "${dir}" ]]; then
    return 0
  fi

  if rg --line-number --no-heading \
    --glob '*.swift' \
    --regexp "${FORBIDDEN_IMPORT_PATTERN}" \
    "${dir}"; then
    echo "Forbidden platform/storage import found under ${label}." >&2
    echo "Disallowed imports: RealmSwift, CoreLocation, MapKit" >&2
    exit 1
  fi

  if rg --line-number --no-heading \
    --glob '*.swift' \
    --regexp "${FORBIDDEN_RUNTIME_SYMBOL_PATTERN}" \
    "${dir}"; then
    echo "Forbidden app/runtime dependency symbol found under ${label}." >&2
    echo "Disallowed symbols: AppContext, AppContext.shared, UIRuntimeProviderRegistry, BehaviorRuntimeProviderRegistry" >&2
    exit 1
  fi
}

check_realm_adapter_boundary() {
  local adapter_symbol_output relative_caller
  declare -a disallowed_callers=()

  adapter_symbol_output="$(
    rg --line-number --no-heading \
      --glob '*.swift' \
      --regexp "${REALM_ADAPTER_SYMBOL_PATTERN}" \
      "${CODE_DIR}" \
      | cut -d: -f1 \
      | sort -u \
      || true
  )"

  while IFS= read -r caller; do
    [[ -z "${caller}" ]] && continue
    relative_caller="${caller#${IOS_DIR}/}"

    if [[ "${relative_caller}" == "${REALM_ADAPTER_ALLOWED_REGISTRY}" ]]; then
      continue
    fi

    if [[ "${relative_caller}" == ${REALM_ADAPTER_ALLOWED_INFRA_PREFIX}* ]]; then
      continue
    fi

    disallowed_callers+=("${relative_caller}")
  done <<< "${adapter_symbol_output}"

  if [[ ${#disallowed_callers[@]} -gt 0 ]]; then
    echo "Realm adapter type usage found outside allowed seam files." >&2
    echo "Disallowed callers:" >&2
    printf "  %s\n" "${disallowed_callers[@]}" >&2
    echo "Allowed callers:" >&2
    echo "  ${REALM_ADAPTER_ALLOWED_REGISTRY}" >&2
    echo "  ${REALM_ADAPTER_ALLOWED_INFRA_PREFIX}*" >&2
    exit 1
  fi
}

check_boundary_dir "${CONTRACTS_DIR}" "GuideDogs/Code/Data/Contracts"
check_boundary_dir "${DOMAIN_DIR}" "GuideDogs/Code/Data/Domain"
check_realm_adapter_boundary

echo "Data contract/domain boundaries passed (no forbidden platform imports/runtime symbols and no Realm adapter seam leaks)."
