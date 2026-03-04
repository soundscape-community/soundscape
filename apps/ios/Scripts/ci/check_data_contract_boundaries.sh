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
readonly REALM_ADAPTER_CONSTRUCTOR_PATTERN='\b(RealmSpatialReadContract|RealmSpatialWriteContract|RealmSpatialMaintenanceWriteContract)\s*\('
readonly REALM_ADAPTER_REGISTRY_DEFAULT_DECLARATION_PATTERN='^[[:space:]]*private[[:space:]]+static[[:space:]]+let[[:space:]]+defaultSpatial(Read|WriteAdapter|MaintenanceWriteAdapter)[[:space:]]*=[[:space:]]*RealmSpatial(Read|Write|MaintenanceWrite)Contract[[:space:]]*\([[:space:]]*\)[[:space:]]*$'
readonly REALM_ADAPTER_ALLOWED_REGISTRY='GuideDogs/Code/Data/Contracts/Storage/DataContractRegistry.swift'
readonly REALM_ADAPTER_ALLOWED_INFRA_PREFIX='GuideDogs/Code/Data/Infrastructure/Realm/'
readonly REALM_ADAPTER_CONSTRUCTOR_ALLOWED_TEST_PREFIX='UnitTests/'
readonly DATA_CONTRACT_REGISTRY_TEST_OVERRIDE_PATTERN='DataContractRegistry\.(configure|resetForTesting)\('
readonly DATA_CONTRACT_REGISTRY_TEST_OVERRIDE_ALLOWED_PREFIX='UnitTests/'
# Match assignment targets even when prefixed by punctuation (for example tuple assignment),
# while avoiding member-access false positives like `foo.spatialRead =`.
readonly DATA_CONTRACT_REGISTRY_ASSIGNMENT_PATTERN='(^|[^[:alnum:]_\.])((self|Self|DataContractRegistry)\.)?spatial(Read|Write|MaintenanceWrite)[[:space:]]*='
readonly DATA_CONTRACT_REGISTRY_ALLOWED_ASSIGNMENT_DECLARATION_PATTERN='^[[:space:]]*private\(set\)[[:space:]]+static[[:space:]]+var[[:space:]]+spatial(Read|Write|MaintenanceWrite)[[:space:]]*:[[:space:]]*[A-Za-z0-9_\.]+[[:space:]]*=[[:space:]]*defaultSpatial(Read|WriteAdapter|MaintenanceWriteAdapter)[[:space:]]*$'
readonly DATA_CONTRACT_REGISTRY_ALLOWED_CONFIGURE_ASSIGNMENT_PATTERN='^[[:space:]]*self\.spatial(Read|Write|MaintenanceWrite)[[:space:]]*=[[:space:]]*(spatialRead|spatialWrite|spatialMaintenanceWrite|defaultSpatialWriteAdapter|defaultSpatialMaintenanceWriteAdapter)[[:space:]]*$'
readonly DATA_CONTRACT_REGISTRY_ALLOWED_RESET_ASSIGNMENT_PATTERN='^[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=[[:space:]]*defaultSpatial(Read|WriteAdapter|MaintenanceWriteAdapter)[[:space:]]*$'
readonly DATA_CONTRACT_REGISTRY_CONFIGURE_SIGNATURE_PATTERN='^[[:space:]]*static[[:space:]]+func[[:space:]]+configure\('
readonly DATA_CONTRACT_REGISTRY_RESET_SIGNATURE_PATTERN='^[[:space:]]*static[[:space:]]+func[[:space:]]+resetForTesting\('
resolve_swift_scope_end_line() {
  local file_path="$1"
  local start_line="$2"

  awk -v start_line="${start_line}" '
    NR < start_line {
      next
    }
    {
      line = $0
      open_count = gsub(/\{/, "{", line)
      close_count = gsub(/\}/, "}", line)

      if (scope_started == 0) {
        if (open_count > 0) {
          scope_started = 1
          scope_depth += open_count - close_count
          if (scope_depth <= 0) {
            print NR
            exit
          }
        }
        next
      }

      scope_depth += open_count - close_count
      if (scope_depth <= 0) {
        print NR
        exit
      }
    }
  ' "${file_path}"
}

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

check_realm_adapter_constructor_boundary() {
  local constructor_output relative_caller
  declare -a disallowed_callers=()

  constructor_output="$(
    rg --line-number --no-heading \
      --glob '*.swift' \
      --regexp "${REALM_ADAPTER_CONSTRUCTOR_PATTERN}" \
      "${IOS_DIR}" \
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

    if [[ "${relative_caller}" == ${REALM_ADAPTER_CONSTRUCTOR_ALLOWED_TEST_PREFIX}* ]]; then
      continue
    fi

    disallowed_callers+=("${relative_caller}")
  done <<< "${constructor_output}"

  if [[ ${#disallowed_callers[@]} -gt 0 ]]; then
    echo "Realm adapter construction found outside allowed wiring seams." >&2
    echo "Disallowed callers:" >&2
    printf "  %s\n" "${disallowed_callers[@]}" >&2
    echo "Allowed callers:" >&2
    echo "  ${REALM_ADAPTER_ALLOWED_REGISTRY}" >&2
    echo "  ${REALM_ADAPTER_CONSTRUCTOR_ALLOWED_TEST_PREFIX}*" >&2
    exit 1
  fi
}

check_data_contract_registry_realm_adapter_wiring() {
  local registry_file constructor_output line_number line_content
  declare -a disallowed_registry_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  constructor_output="$(
    rg --line-number --no-heading --no-filename \
      --regexp "${REALM_ADAPTER_CONSTRUCTOR_PATTERN}" \
      "${registry_file}" \
      || true
  )"

  while IFS= read -r constructor_line; do
    [[ -z "${constructor_line}" ]] && continue
    line_number="${constructor_line%%:*}"
    line_content="${constructor_line#*:}"

    if [[ "${line_content}" =~ ${REALM_ADAPTER_REGISTRY_DEFAULT_DECLARATION_PATTERN} ]]; then
      continue
    fi

    disallowed_registry_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${constructor_output}"

  if [[ ${#disallowed_registry_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains non-default Realm adapter constructor wiring." >&2
    echo "Disallowed constructor call sites:" >&2
    printf "  %s\n" "${disallowed_registry_wiring[@]}" >&2
    echo "Allowed constructor shape:" >&2
    echo "  private static let defaultSpatial* = RealmSpatial*Contract()" >&2
    exit 1
  fi
}

check_data_contract_registry_test_override_boundary() {
  local test_override_output relative_caller
  declare -a disallowed_callers=()

  test_override_output="$(
    rg --line-number --no-heading \
      --glob '*.swift' \
      --regexp "${DATA_CONTRACT_REGISTRY_TEST_OVERRIDE_PATTERN}" \
      "${IOS_DIR}" \
      | cut -d: -f1 \
      | sort -u \
      || true
  )"

  while IFS= read -r caller; do
    [[ -z "${caller}" ]] && continue
    relative_caller="${caller#${IOS_DIR}/}"

    if [[ "${relative_caller}" == ${DATA_CONTRACT_REGISTRY_TEST_OVERRIDE_ALLOWED_PREFIX}* ]]; then
      continue
    fi

    disallowed_callers+=("${relative_caller}")
  done <<< "${test_override_output}"

  if [[ ${#disallowed_callers[@]} -gt 0 ]]; then
    echo "DataContractRegistry override seams are used outside UnitTests." >&2
    echo "Disallowed callers:" >&2
    printf "  %s\n" "${disallowed_callers[@]}" >&2
    echo "Allowed callers:" >&2
    echo "  ${DATA_CONTRACT_REGISTRY_TEST_OVERRIDE_ALLOWED_PREFIX}*" >&2
    exit 1
  fi
}

check_data_contract_registry_assignment_wiring() {
  local registry_file assignment_output line_number line_content
  local configure_start_line configure_end_line reset_start_line reset_end_line
  declare -a disallowed_registry_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  configure_start_line="$(
    rg --line-number --no-heading --no-filename \
      --regexp "${DATA_CONTRACT_REGISTRY_CONFIGURE_SIGNATURE_PATTERN}" \
      "${registry_file}" \
      | head -n1 \
      | cut -d: -f1 \
      || true
  )"
  reset_start_line="$(
    rg --line-number --no-heading --no-filename \
      --regexp "${DATA_CONTRACT_REGISTRY_RESET_SIGNATURE_PATTERN}" \
      "${registry_file}" \
      | head -n1 \
      | cut -d: -f1 \
      || true
  )"

  if [[ -n "${configure_start_line}" ]]; then
    configure_end_line="$(resolve_swift_scope_end_line "${registry_file}" "${configure_start_line}")"
  else
    configure_end_line=""
  fi

  if [[ -n "${reset_start_line}" ]]; then
    reset_end_line="$(resolve_swift_scope_end_line "${registry_file}" "${reset_start_line}")"
  else
    reset_end_line=""
  fi

  assignment_output="$(
    rg --line-number --no-heading --no-filename \
      --regexp "${DATA_CONTRACT_REGISTRY_ASSIGNMENT_PATTERN}" \
      "${registry_file}" \
      || true
  )"

  while IFS= read -r assignment_line; do
    [[ -z "${assignment_line}" ]] && continue
    line_number="${assignment_line%%:*}"
    line_content="${assignment_line#*:}"

    if [[ "${line_content}" =~ ${DATA_CONTRACT_REGISTRY_ALLOWED_ASSIGNMENT_DECLARATION_PATTERN} ]]; then
      continue
    fi

    if [[ "${line_content}" =~ ${DATA_CONTRACT_REGISTRY_ALLOWED_CONFIGURE_ASSIGNMENT_PATTERN} ]]; then
      if [[ -z "${configure_start_line}" || -z "${configure_end_line}" || "${line_number}" -lt "${configure_start_line}" || "${line_number}" -gt "${configure_end_line}" ]]; then
        disallowed_registry_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
      fi
      continue
    fi

    if [[ "${line_content}" =~ ${DATA_CONTRACT_REGISTRY_ALLOWED_RESET_ASSIGNMENT_PATTERN} ]]; then
      if [[ -z "${reset_start_line}" || -z "${reset_end_line}" || "${line_number}" -lt "${reset_start_line}" || "${line_number}" -gt "${reset_end_line}" ]]; then
        disallowed_registry_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
      fi
      continue
    fi

    disallowed_registry_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${assignment_output}"

  if [[ ${#disallowed_registry_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains non-seam spatial adapter assignment wiring." >&2
    echo "Disallowed assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_assignments[@]}" >&2
    echo "Allowed assignment shapes:" >&2
    echo "  private(set) static var spatial* = defaultSpatial*" >&2
    echo "  self.spatial* = spatial* (inside configure seam only)" >&2
    echo "  self.spatial* = defaultSpatial* (inside configure fallback seam only)" >&2
    echo "  spatial* = defaultSpatial* (inside resetForTesting seam only)" >&2
    exit 1
  fi
}

check_data_contract_registry_parenthesized_assignment_wiring() {
  local registry_file parenthesized_assignment_output line_number
  declare -a disallowed_registry_parenthesized_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  parenthesized_assignment_output="$(
    awk '
        BEGIN {
          in_candidate = 0
          candidate_start_line = 0
          candidate = ""
        }

        {
          line = $0

          if (in_candidate == 0) {
            if (line ~ /^[[:space:]]*\(/) {
              in_candidate = 1
              candidate_start_line = NR
              candidate = ""
            } else {
              next
            }
          }

          candidate = candidate line "\n"

          if (line ~ /\)[[:space:]]*=/) {
            if (candidate ~ /(^|[^[:alnum:]_])(((self|Self|DataContractRegistry)[[:space:]]*\.[[:space:]]*)|(\.[[:space:]]*))?spatial(Read|Write|MaintenanceWrite)([^[:alnum:]_]|$)/) {
              print candidate_start_line
            }

            in_candidate = 0
            candidate_start_line = 0
            candidate = ""
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_parenthesized_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${parenthesized_assignment_output}"

  if [[ ${#disallowed_registry_parenthesized_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains parenthesized spatial adapter assignment wiring." >&2
    echo "Disallowed parenthesized assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_parenthesized_assignments[@]}" >&2
    echo "Use explicit per-adapter assignments in configure/reset seams to preserve guardrail coverage." >&2
    exit 1
  fi
}

check_data_contract_registry_multiline_assignment_wiring() {
  local registry_file multiline_assignment_output line_number
  declare -a disallowed_registry_multiline_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  multiline_assignment_output="$(
    awk '
        BEGIN {
          pending_lhs_line = 0
        }

        {
          line = $0

          if (line ~ /^[[:space:]]*((self|Self|DataContractRegistry)\.)?spatial(Read|Write|MaintenanceWrite)[[:space:]]*(\/\/.*)?$/) {
            pending_lhs_line = NR
            next
          }

          if (pending_lhs_line > 0) {
            if (line ~ /^[[:space:]]*=[^=]/) {
              print pending_lhs_line
            }
            pending_lhs_line = 0
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_multiline_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${multiline_assignment_output}"

  if [[ ${#disallowed_registry_multiline_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains multiline spatial adapter assignment wiring." >&2
    echo "Disallowed multiline assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_multiline_assignments[@]}" >&2
    echo "Use single-line explicit per-adapter assignments in configure/reset seams to preserve guardrail coverage." >&2
    exit 1
  fi
}

check_data_contract_registry_split_member_assignment_wiring() {
  local registry_file split_member_assignment_output line_number
  declare -a disallowed_registry_split_member_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  split_member_assignment_output="$(
    awk '
        BEGIN {
          pending_owner_line = 0
          pending_member_line = 0
        }

        {
          line = $0

          if (pending_member_line > 0) {
            if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*\/\//) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print pending_owner_line
            }

            pending_owner_line = 0
            pending_member_line = 0
          }

          if (pending_owner_line == 0) {
            if (line ~ /^[[:space:]]*(self|Self|DataContractRegistry)[[:space:]]*(\/\/.*)?$/) {
              pending_owner_line = NR
            }
            next
          }

          if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*\/\//) {
            next
          }

          if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
            print pending_owner_line
            pending_owner_line = 0
            next
          }

          if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*(\/\/.*)?$/) {
            pending_member_line = NR
            next
          }

          pending_owner_line = 0
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_split_member_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${split_member_assignment_output}"

  if [[ ${#disallowed_registry_split_member_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains split member-access spatial adapter assignment wiring." >&2
    echo "Disallowed split member-assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_split_member_assignments[@]}" >&2
    echo "Use direct single-line member assignments in configure/reset seams to preserve guardrail coverage." >&2
    exit 1
  fi
}

check_boundary_dir "${CONTRACTS_DIR}" "GuideDogs/Code/Data/Contracts"
check_boundary_dir "${DOMAIN_DIR}" "GuideDogs/Code/Data/Domain"
check_realm_adapter_boundary
check_realm_adapter_constructor_boundary
check_data_contract_registry_realm_adapter_wiring
check_data_contract_registry_test_override_boundary
check_data_contract_registry_assignment_wiring
check_data_contract_registry_parenthesized_assignment_wiring
check_data_contract_registry_multiline_assignment_wiring
check_data_contract_registry_split_member_assignment_wiring

echo "Data contract/domain boundaries passed (no forbidden platform imports/runtime symbols, no Realm adapter seam leaks, constructor wiring boundaries preserved including registry-default declarations, registry spatial-adapter assignment seams preserved including parenthesized/multiline/split-member assignment detection, and test-only registry overrides)."
