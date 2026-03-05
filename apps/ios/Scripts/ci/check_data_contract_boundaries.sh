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
readonly DATA_CONTRACT_REGISTRY_ASSIGNMENT_PATTERN='(^|[^[:alnum:]_\.])((self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*\.[[:space:]]*)?spatial(Read|Write|MaintenanceWrite)[[:space:]]*='
readonly DATA_CONTRACT_REGISTRY_ALLOWED_ASSIGNMENT_DECLARATION_PATTERN='^[[:space:]]*private\(set\)[[:space:]]+static[[:space:]]+var[[:space:]]+spatial(Read|Write|MaintenanceWrite)[[:space:]]*:[[:space:]]*[A-Za-z0-9_\.]+[[:space:]]*=[[:space:]]*defaultSpatial(Read|WriteAdapter|MaintenanceWriteAdapter)[[:space:]]*$'
readonly DATA_CONTRACT_REGISTRY_ALLOWED_CONFIGURE_ASSIGNMENT_PATTERN='^[[:space:]]*self[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=[[:space:]]*(spatialRead|spatialWrite|spatialMaintenanceWrite|defaultSpatialWriteAdapter|defaultSpatialMaintenanceWriteAdapter)[[:space:]]*$'
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

          if (line ~ /^[[:space:]]*((self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*\.[[:space:]]*)?spatial(Read|Write|MaintenanceWrite)[[:space:]]*(\/\/.*)?$/) {
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
            if (line ~ /^[[:space:]]*(self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*(\/\/.*)?$/) {
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

check_data_contract_registry_parenthesized_owner_assignment_wiring() {
  local registry_file parenthesized_owner_output line_number
  declare -a disallowed_registry_parenthesized_owner_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  parenthesized_owner_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /\([[:space:]]*(self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*\)[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
            print NR
            state = "none"
            start_line = 0
            next
          }

          if (state == "owner_ready") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "member_wait_eq") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "paren_wait_owner") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*(self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*$/) {
              state = "paren_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "paren_wait_close") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*(self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*\)[[:space:]]*$/) {
            state = "owner_ready"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*$/) {
            state = "paren_wait_owner"
            start_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_parenthesized_owner_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${parenthesized_owner_output}"

  if [[ ${#disallowed_registry_parenthesized_owner_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains parenthesized-owner spatial adapter assignment wiring." >&2
    echo "Disallowed parenthesized-owner assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_parenthesized_owner_assignments[@]}" >&2
    echo "Avoid parenthesized owner wrappers around self/Self/DataContractRegistry in spatial adapter assignments." >&2
    exit 1
  fi
}

check_data_contract_registry_parenthesized_alias_owner_assignment_wiring() {
  local registry_file parenthesized_alias_owner_output line_number
  declare -a disallowed_registry_parenthesized_alias_owner_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  parenthesized_alias_owner_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /\([[:space:]]*(([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*[[:space:]]*\)[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
            print NR
            state = "none"
            start_line = 0
            next
          }

          if (state == "owner_ready") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "member_wait_eq") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "paren_wait_owner") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*[[:space:]]*$/) {
              state = "paren_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "paren_wait_close") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*(([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*[[:space:]]*\)[[:space:]]*$/) {
            state = "owner_ready"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*$/) {
            state = "paren_wait_owner"
            start_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_parenthesized_alias_owner_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${parenthesized_alias_owner_output}"

  if [[ ${#disallowed_registry_parenthesized_alias_owner_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains parenthesized-alias-owner spatial adapter assignment wiring." >&2
    echo "Disallowed parenthesized-alias-owner assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_parenthesized_alias_owner_assignments[@]}" >&2
    echo "Avoid parenthesized alias-owner wrappers around spatial adapter assignments; keep direct canonical seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_nested_parenthesized_owner_assignment_wiring() {
  local registry_file nested_parenthesized_owner_output line_number
  declare -a disallowed_registry_nested_parenthesized_owner_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  nested_parenthesized_owner_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]*\)[[:space:]]*\)[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
            print NR
            state = "none"
            start_line = 0
            next
          }

          if (state == "owner_ready") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "member_wait_eq") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]*\)[[:space:]]*\)[[:space:]]*$/) {
            state = "owner_ready"
            start_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_nested_parenthesized_owner_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${nested_parenthesized_owner_output}"

  if [[ ${#disallowed_registry_nested_parenthesized_owner_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains nested-parenthesized owner spatial adapter assignment wiring." >&2
    echo "Disallowed nested-parenthesized owner assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_nested_parenthesized_owner_assignments[@]}" >&2
    echo "Avoid nested parenthesized owner wrappers around spatial adapter assignments; keep direct canonical seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_cast_owner_assignment_wiring() {
  local registry_file cast_owner_output line_number
  declare -a disallowed_registry_cast_owner_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  cast_owner_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
            print NR
            state = "none"
            start_line = 0
            next
          }

          if (state == "owner_ready") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "member_wait_eq") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "paren_wait_owner") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]*$/) {
              state = "cast_wait_as"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]*$/) {
              state = "cast_wait_type"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*$/) {
              state = "cast_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "cast_wait_as") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]*$/) {
              state = "cast_wait_type"
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*$/) {
              state = "cast_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "cast_wait_type") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*$/) {
              state = "cast_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "cast_wait_close") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*$/) {
              state = "cast_wait_coalesce_rhs"
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*$/) {
              state = "cast_wait_coalesce_after_rhs"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "cast_wait_coalesce_rhs") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*[[:space:]]*$/) {
              state = "cast_wait_coalesce_after_rhs"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "cast_wait_coalesce_after_rhs") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)[[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\)[[:space:]]*!?[[:space:]]*$/) {
            state = "owner_ready"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
            state = "owner_ready"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]*$/) {
            state = "cast_wait_type"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]*$/) {
            state = "cast_wait_as"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*$/) {
            state = "paren_wait_owner"
            start_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_cast_owner_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${cast_owner_output}"

  if [[ ${#disallowed_registry_cast_owner_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains cast-owner spatial adapter assignment wiring." >&2
    echo "Disallowed cast-owner assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_cast_owner_assignments[@]}" >&2
    echo "Avoid assigning spatial adapters through cast-owner expressions; keep direct canonical seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_nested_cast_owner_assignment_wiring() {
  local registry_file nested_cast_owner_output line_number
  declare -a disallowed_registry_nested_cast_owner_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  nested_cast_owner_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
            print NR
            state = "none"
            start_line = 0
            next
          }

          if (state == "owner_ready") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "member_wait_eq") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "outer_paren_wait_inner_open") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\([[:space:]]*$/) {
              state = "nested_paren_wait_owner"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "nested_paren_wait_owner") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]*$/) {
              state = "nested_cast_wait_as"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]*$/) {
              state = "nested_cast_wait_type"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "nested_wait_outer_close"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*$/) {
              state = "nested_cast_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "nested_cast_wait_as") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]*$/) {
              state = "nested_cast_wait_type"
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "nested_wait_outer_close"
              next
            }

            if (line ~ /^[[:space:]]*as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*$/) {
              state = "nested_cast_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "nested_cast_wait_type") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "nested_wait_outer_close"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*Type[[:space:]]*\??[[:space:]]*$/) {
              state = "nested_cast_wait_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "nested_cast_wait_close") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*$/) {
              state = "nested_cast_wait_coalesce_rhs"
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "nested_wait_outer_close"
              next
            }

            if (line ~ /^[[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*$/) {
              state = "nested_cast_wait_coalesce_after_rhs"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "nested_wait_outer_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "nested_cast_wait_coalesce_rhs") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "nested_wait_outer_close"
              next
            }

            if (line ~ /^[[:space:]]*[^)]*[[:space:]]*$/) {
              state = "nested_cast_wait_coalesce_after_rhs"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "nested_cast_wait_coalesce_after_rhs") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            if (line ~ /^[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*$/) {
              state = "nested_wait_outer_close"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "nested_wait_outer_close") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*\)?[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            if (line ~ /^[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
              state = "owner_ready"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*\)([[:space:]]*\?\?[[:space:]]*[^)]*[[:space:]]*\))?[[:space:]]*!?[[:space:]]*\)[[:space:]]*\)?[[:space:]]*$/) {
            state = "owner_ready"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]*$/) {
            state = "nested_cast_wait_type"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]+as[[:space:]]*[!?]?[[:space:]]+[^)]*Type[[:space:]]*\??[[:space:]]*$/) {
            state = "nested_cast_wait_close"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*\([[:space:]]*(((self|Self|DataContractRegistry)|([A-Za-z_][A-Za-z0-9_]*)|(`([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*)`))([[:space:]]*\.[[:space:]]*self)*)[[:space:]]*$/) {
            state = "nested_cast_wait_as"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*\([[:space:]]*$/) {
            state = "outer_paren_wait_inner_open"
            start_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_nested_cast_owner_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${nested_cast_owner_output}"

  if [[ ${#disallowed_registry_nested_cast_owner_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains nested-cast-owner spatial adapter assignment wiring." >&2
    echo "Disallowed nested-cast-owner assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_nested_cast_owner_assignments[@]}" >&2
    echo "Avoid assigning spatial adapters through nested cast-owner expressions; keep direct canonical seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_commented_assignment_wiring() {
  local registry_file commented_assignment_output line_number
  declare -a disallowed_registry_commented_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  commented_assignment_output="$(
    awk '
        BEGIN {
          pending_lhs_line = 0
        }

        {
          line = $0

          if (pending_lhs_line > 0) {
            if (line ~ /^[[:space:]]*$/ || line ~ /^[[:space:]]*\/\//) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print pending_lhs_line
            }
            pending_lhs_line = 0
          }

          if (line !~ /spatial(Read|Write|MaintenanceWrite)/) {
            next
          }

          comment_index = index(line, "/*")
          eq_index = index(line, "=")

          if (comment_index > 0 && eq_index > 0 && comment_index < eq_index) {
            print NR
            next
          }

          if (comment_index > 0 && eq_index == 0) {
            pending_lhs_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_commented_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${commented_assignment_output}"

  if [[ ${#disallowed_registry_commented_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains block-comment-interleaved spatial adapter assignment wiring." >&2
    echo "Disallowed block-comment assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_commented_assignments[@]}" >&2
    echo "Avoid block comments in spatial adapter assignment LHS expressions to preserve guardrail coverage." >&2
    exit 1
  fi
}

check_data_contract_registry_block_comment_separated_assignment_wiring() {
  local registry_file block_comment_separated_output line_number
  declare -a disallowed_registry_block_comment_separated_assignments=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  block_comment_separated_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_leading_inline_block_comments(input,    rest, comment_end) {
          rest = input
          leading_comment_is_open = 0

          while (rest ~ /^[[:space:]]*\/\*/) {
            comment_end = index(rest, "*/")
            if (comment_end == 0) {
              leading_comment_is_open = 1
              return ""
            }
            rest = substr(rest, comment_end + 2)
          }

          return rest
        }

        {
          line = $0

          if (in_block_comment == 1) {
            comment_end = index(line, "*/")
            if (comment_end == 0) {
              next
            }

            line = substr(line, comment_end + 2)
            in_block_comment = 0
          }

          if (state == "lhs_wait_eq") {
            normalized_line = strip_leading_inline_block_comments(line)
            if (leading_comment_is_open == 1) {
              in_block_comment = 1
              next
            }

            if (normalized_line ~ /^[[:space:]]*$/ || normalized_line ~ /^[[:space:]]*\/\//) {
              next
            }

            if (normalized_line ~ /^[[:space:]]*=[^=]/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "owner_wait_member") {
            normalized_line = strip_leading_inline_block_comments(line)
            if (leading_comment_is_open == 1) {
              in_block_comment = 1
              next
            }

            if (normalized_line ~ /^[[:space:]]*$/ || normalized_line ~ /^[[:space:]]*\/\//) {
              next
            }

            if (normalized_line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print start_line
              state = "none"
              start_line = 0
              next
            }

            if (normalized_line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              state = "member_wait_eq"
              next
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "member_wait_eq") {
            normalized_line = strip_leading_inline_block_comments(line)
            if (leading_comment_is_open == 1) {
              in_block_comment = 1
              next
            }

            if (normalized_line ~ /^[[:space:]]*$/ || normalized_line ~ /^[[:space:]]*\/\//) {
              next
            }

            if (normalized_line ~ /^[[:space:]]*=[^=]/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /^[[:space:]]*((self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*\.[[:space:]]*)?spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
            state = "lhs_wait_eq"
            start_line = NR
            next
          }

          if (line ~ /^[[:space:]]*(self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)*[[:space:]]*(\/\/.*)?$/) {
            state = "owner_wait_member"
            start_line = NR
            next
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_block_comment_separated_assignments+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${block_comment_separated_output}"

  if [[ ${#disallowed_registry_block_comment_separated_assignments[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains block-comment-separated spatial adapter assignment wiring." >&2
    echo "Disallowed block-comment-separated assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_block_comment_separated_assignments[@]}" >&2
    echo "Avoid separating spatial adapter assignment fragments with block-comment-only lines." >&2
    exit 1
  fi
}

check_data_contract_registry_inout_wiring() {
  local registry_file inout_output line_number
  declare -a disallowed_registry_inout_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  inout_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (state == "after_amp") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*(self|Self|DataContractRegistry)[[:space:]]*$/) {
              state = "after_amp_owner"
              next
            }

            if (line ~ /^[[:space:]]*((self|Self|DataContractRegistry)[[:space:]]*\.[[:space:]]*)?spatial(Read|Write|MaintenanceWrite)([^[:alnum:]_]|$)/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "after_amp_owner") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)([^[:alnum:]_]|$)/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /&[[:space:]]*((self|Self|DataContractRegistry)[[:space:]]*\.[[:space:]]*)?spatial(Read|Write|MaintenanceWrite)([^[:alnum:]_]|$)/) {
            print NR
            next
          }

          if (line ~ /&[[:space:]]*(self|Self|DataContractRegistry)[[:space:]]*$/) {
            state = "after_amp_owner"
            start_line = NR
            next
          }

          if (line ~ /&[[:space:]]*$/) {
            state = "after_amp"
            start_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_inout_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${inout_output}"

  if [[ ${#disallowed_registry_inout_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains inout-based spatial adapter wiring." >&2
    echo "Disallowed inout wiring call sites:" >&2
    printf "  %s\n" "${disallowed_registry_inout_wiring[@]}" >&2
    echo "Avoid `&spatial*` inout mutation paths; use explicit assignment seams for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_keypath_wiring() {
  local registry_file keypath_output line_number
  declare -a disallowed_registry_keypath_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  keypath_output="$(
    awk '
        BEGIN {
          state = "none"
          start_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (state == "after_backslash") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*(self|Self|DataContractRegistry)[[:space:]]*$/) {
              state = "after_backslash_owner"
              next
            }

            if (line ~ /^[[:space:]]*(((self|Self|DataContractRegistry)[[:space:]]*\.[[:space:]]*)|(\.[[:space:]]*))spatial(Read|Write|MaintenanceWrite)([^[:alnum:]_]|$)/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (state == "after_backslash_owner") {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)([^[:alnum:]_]|$)/) {
              print start_line
            }

            state = "none"
            start_line = 0
            next
          }

          if (line ~ /\\[[:space:]]*(((self|Self|DataContractRegistry)[[:space:]]*\.[[:space:]]*)|(\.[[:space:]]*))spatial(Read|Write|MaintenanceWrite)([^[:alnum:]_]|$)/) {
            print NR
            next
          }

          if (line ~ /\\[[:space:]]*(self|Self|DataContractRegistry)[[:space:]]*$/) {
            state = "after_backslash_owner"
            start_line = NR
            next
          }

          if (line ~ /\\[[:space:]]*$/) {
            state = "after_backslash"
            start_line = NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_keypath_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${keypath_output}"

  if [[ ${#disallowed_registry_keypath_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains spatial adapter key-path wiring." >&2
    echo "Disallowed key-path wiring call sites:" >&2
    printf "  %s\n" "${disallowed_registry_keypath_wiring[@]}" >&2
    echo "Avoid key-path access for spatial adapters; keep explicit adapter seams for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_metatype_alias_assignment_wiring() {
  local registry_file metatype_alias_output line_number
  declare -a disallowed_registry_metatype_alias_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  metatype_alias_output="$(
    awk '
        BEGIN {
          pending_owner_line = 0
          pending_member_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /^[[:space:]]*(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(:[^=]+)?=[[:space:]]*(self|Self|DataContractRegistry)([[:space:]]*\.[[:space:]]*self)?[[:space:]]*$/) {
            alias_decl = line
            sub(/^[[:space:]]*(let|var)[[:space:]]+/, "", alias_decl)
            sub(/[[:space:]]*(:[^=]+)?=.*/, "", alias_decl)
            gsub(/[[:space:]]+$/, "", alias_decl)
            if (alias_decl != "self" && alias_decl != "Self" && alias_decl != "DataContractRegistry") {
              metatype_aliases[alias_decl] = 1
            }
            next
          }

          if (pending_member_line > 0) {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print pending_owner_line
            }

            pending_owner_line = 0
            pending_member_line = 0
          }

          if (pending_owner_line == 0) {
            if (line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*$/) {
              owner = line
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", owner)
              if (owner in metatype_aliases) {
                pending_owner_line = NR
              }
            }
          } else {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print pending_owner_line
              pending_owner_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              pending_member_line = NR
              next
            }

            pending_owner_line = 0
          }

          for (alias_owner in metatype_aliases) {
            pattern = "(^|[^[:alnum:]_\\.])" alias_owner "[[:space:]]*\\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*="
            if (line ~ pattern) {
              print NR
              break
            }
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_metatype_alias_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${metatype_alias_output}"

  if [[ ${#disallowed_registry_metatype_alias_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains metatype-alias spatial adapter assignment wiring." >&2
    echo "Disallowed metatype-alias assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_metatype_alias_wiring[@]}" >&2
    echo "Avoid assigning spatial adapters through local metatype aliases; keep direct self/Self seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_typealias_assignment_wiring() {
  local registry_file typealias_output line_number
  declare -a disallowed_registry_typealias_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  typealias_output="$(
    awk '
        BEGIN {
          pending_owner_line = 0
          pending_member_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /^[[:space:]]*typealias[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*([[:space:]]*\.[[:space:]]*Type)?[[:space:]]*$/) {
            alias_decl = line
            sub(/^[[:space:]]*typealias[[:space:]]+/, "", alias_decl)
            sub(/[[:space:]]*=.*/, "", alias_decl)
            gsub(/[[:space:]]+$/, "", alias_decl)

            rhs_owner = line
            sub(/^[[:space:]]*typealias[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*/, "", rhs_owner)
            sub(/[[:space:]]*(\.[[:space:]]*Type)?[[:space:]]*$/, "", rhs_owner)
            gsub(/[[:space:]]+$/, "", rhs_owner)

            if (rhs_owner == "Self" || rhs_owner == "DataContractRegistry" || (rhs_owner in type_aliases)) {
              if (alias_decl != "Self" && alias_decl != "DataContractRegistry") {
                type_aliases[alias_decl] = 1
              }
            }
            next
          }

          if (pending_member_line > 0) {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print pending_owner_line
            }

            pending_owner_line = 0
            pending_member_line = 0
          }

          if (pending_owner_line == 0) {
            if (line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*$/) {
              owner = line
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", owner)
              if (owner in type_aliases) {
                pending_owner_line = NR
              }
            }
          } else {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print pending_owner_line
              pending_owner_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              pending_member_line = NR
              next
            }

            pending_owner_line = 0
          }

          for (alias_owner in type_aliases) {
            pattern = "(^|[^[:alnum:]_\\.])" alias_owner "[[:space:]]*\\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*="
            if (line ~ pattern) {
              print NR
              break
            }
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_typealias_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${typealias_output}"

  if [[ ${#disallowed_registry_typealias_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains typealias-based spatial adapter assignment wiring." >&2
    echo "Disallowed typealias assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_typealias_wiring[@]}" >&2
    echo "Avoid assigning spatial adapters through typealias owners; keep direct registry/seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_typealias_metatype_alias_assignment_wiring() {
  local registry_file typealias_metatype_alias_output line_number
  declare -a disallowed_registry_typealias_metatype_alias_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  typealias_metatype_alias_output="$(
    awk '
        BEGIN {
          pending_owner_line = 0
          pending_member_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /^[[:space:]]*typealias[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*([[:space:]]*\.[[:space:]]*Type)?[[:space:]]*$/) {
            alias_decl = line
            sub(/^[[:space:]]*typealias[[:space:]]+/, "", alias_decl)
            sub(/[[:space:]]*=.*/, "", alias_decl)
            gsub(/[[:space:]]+$/, "", alias_decl)

            rhs_owner = line
            sub(/^[[:space:]]*typealias[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*/, "", rhs_owner)
            sub(/[[:space:]]*(\.[[:space:]]*Type)?[[:space:]]*$/, "", rhs_owner)
            gsub(/[[:space:]]+$/, "", rhs_owner)

            if (rhs_owner == "Self" || rhs_owner == "DataContractRegistry" || (rhs_owner in type_aliases)) {
              if (alias_decl != "Self" && alias_decl != "DataContractRegistry") {
                type_aliases[alias_decl] = 1
              }
            }
            next
          }

          if (line ~ /^[[:space:]]*(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(:[^=]+)?=[[:space:]]*[A-Za-z_][A-Za-z0-9_]*([[:space:]]*\.[[:space:]]*self)?[[:space:]]*$/) {
            alias_decl = line
            sub(/^[[:space:]]*(let|var)[[:space:]]+/, "", alias_decl)
            alias_name = alias_decl
            sub(/[[:space:]]*(:[^=]+)?=.*/, "", alias_name)
            gsub(/[[:space:]]+$/, "", alias_name)

            rhs = line
            sub(/^[[:space:]]*(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(:[^=]+)?=[[:space:]]*/, "", rhs)
            gsub(/[[:space:]]+$/, "", rhs)
            owner = rhs
            sub(/[[:space:]]*(\.[[:space:]]*self)?[[:space:]]*$/, "", owner)
            gsub(/[[:space:]]+$/, "", owner)

            if (owner in type_aliases) {
              if (alias_name != owner) {
                metatype_aliases[alias_name] = 1
              }
            }
            next
          }

          if (pending_member_line > 0) {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print pending_owner_line
            }

            pending_owner_line = 0
            pending_member_line = 0
          }

          if (pending_owner_line == 0) {
            if (line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*$/) {
              owner = line
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", owner)
              if (owner in metatype_aliases) {
                pending_owner_line = NR
              }
            }
          } else {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print pending_owner_line
              pending_owner_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              pending_member_line = NR
              next
            }

            pending_owner_line = 0
          }

          for (alias_owner in metatype_aliases) {
            pattern = "(^|[^[:alnum:]_\\.])" alias_owner "[[:space:]]*\\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*="
            if (line ~ pattern) {
              print NR
              break
            }
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_typealias_metatype_alias_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${typealias_metatype_alias_output}"

  if [[ ${#disallowed_registry_typealias_metatype_alias_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains typealias-derived metatype-alias spatial adapter assignment wiring." >&2
    echo "Disallowed typealias-derived metatype-alias assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_typealias_metatype_alias_wiring[@]}" >&2
    echo "Avoid assigning spatial adapters through metatype aliases derived from typealias owners; keep direct registry/seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_escaped_alias_owner_assignment_wiring() {
  local registry_file escaped_alias_owner_output line_number
  declare -a disallowed_registry_escaped_alias_owner_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  escaped_alias_owner_output="$(
    awk '
        BEGIN {
          pending_owner_line = 0
          pending_member_line = 0
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (pending_member_line > 0) {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*=[^=]/) {
              print pending_owner_line
            }

            pending_owner_line = 0
            pending_member_line = 0
          }

          if (pending_owner_line == 0) {
            if (line ~ /^[[:space:]]*`[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*`[[:space:]]*$/) {
              pending_owner_line = NR
              next
            }
          } else {
            if (line ~ /^[[:space:]]*$/) {
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
              print pending_owner_line
              pending_owner_line = 0
              next
            }

            if (line ~ /^[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*$/) {
              pending_member_line = NR
              next
            }

            pending_owner_line = 0
          }

          if (line ~ /`[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*`[[:space:]]*\.[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*=/) {
            print NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_escaped_alias_owner_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${escaped_alias_owner_output}"

  if [[ ${#disallowed_registry_escaped_alias_owner_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains escaped-alias-owner spatial adapter assignment wiring." >&2
    echo "Disallowed escaped-alias-owner assignment call sites:" >&2
    printf "  %s\n" "${disallowed_registry_escaped_alias_owner_wiring[@]}" >&2
    echo "Avoid assigning spatial adapters through backtick-escaped alias owners; keep direct canonical seam assignments for guardrail visibility." >&2
    exit 1
  fi
}

check_data_contract_registry_escaped_owner_wiring() {
  local registry_file escaped_owner_output line_number
  declare -a disallowed_registry_escaped_owner_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  escaped_owner_output="$(
    awk '
        BEGIN {
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /`[[:space:]]*(self|Self|DataContractRegistry)[[:space:]]*`/) {
            print NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_escaped_owner_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${escaped_owner_output}"

  if [[ ${#disallowed_registry_escaped_owner_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains escaped-owner spatial adapter wiring." >&2
    echo "Disallowed escaped-owner call sites:" >&2
    printf "  %s\n" "${disallowed_registry_escaped_owner_wiring[@]}" >&2
    echo "Avoid backtick-escaped owner identifiers (`self`, `Self`, `DataContractRegistry`) in adapter wiring seams." >&2
    exit 1
  fi
}

check_data_contract_registry_escaped_identifier_wiring() {
  local registry_file escaped_identifier_output line_number
  declare -a disallowed_registry_escaped_identifier_wiring=()

  registry_file="${IOS_DIR}/${REALM_ADAPTER_ALLOWED_REGISTRY}"
  if [[ ! -f "${registry_file}" ]]; then
    return 0
  fi

  escaped_identifier_output="$(
    awk '
        BEGIN {
          in_block_comment = 0
        }

        function strip_block_comments(input,    out, rest, start, finish) {
          out = ""
          rest = input

          while (length(rest) > 0) {
            if (in_block_comment == 1) {
              finish = index(rest, "*/")
              if (finish == 0) {
                return out
              }
              rest = substr(rest, finish + 2)
              in_block_comment = 0
              continue
            }

            start = index(rest, "/*")
            if (start == 0) {
              out = out rest
              break
            }

            out = out substr(rest, 1, start - 1)
            rest = substr(rest, start + 2)
            finish = index(rest, "*/")
            if (finish == 0) {
              in_block_comment = 1
              break
            }

            rest = substr(rest, finish + 2)
          }

          return out
        }

        {
          line = strip_block_comments($0)
          sub(/\/\/.*$/, "", line)
          gsub(/"[^"]*"/, "", line)

          if (line ~ /`[[:space:]]*spatial(Read|Write|MaintenanceWrite)[[:space:]]*`/) {
            print NR
          }
        }
      ' "${registry_file}"
  )"

  while IFS= read -r line_number; do
    [[ -z "${line_number}" ]] && continue
    disallowed_registry_escaped_identifier_wiring+=("${REALM_ADAPTER_ALLOWED_REGISTRY}:${line_number}")
  done <<< "${escaped_identifier_output}"

  if [[ ${#disallowed_registry_escaped_identifier_wiring[@]} -gt 0 ]]; then
    echo "DataContractRegistry contains escaped-identifier spatial adapter wiring." >&2
    echo "Disallowed escaped-identifier call sites:" >&2
    printf "  %s\n" "${disallowed_registry_escaped_identifier_wiring[@]}" >&2
    echo "Avoid backtick-escaped spatial adapter identifiers; keep canonical adapter seam names for guardrail visibility." >&2
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
check_data_contract_registry_parenthesized_owner_assignment_wiring
check_data_contract_registry_parenthesized_alias_owner_assignment_wiring
check_data_contract_registry_nested_parenthesized_owner_assignment_wiring
check_data_contract_registry_cast_owner_assignment_wiring
check_data_contract_registry_nested_cast_owner_assignment_wiring
check_data_contract_registry_commented_assignment_wiring
check_data_contract_registry_block_comment_separated_assignment_wiring
check_data_contract_registry_inout_wiring
check_data_contract_registry_keypath_wiring
check_data_contract_registry_metatype_alias_assignment_wiring
check_data_contract_registry_typealias_assignment_wiring
check_data_contract_registry_typealias_metatype_alias_assignment_wiring
check_data_contract_registry_escaped_alias_owner_assignment_wiring
check_data_contract_registry_escaped_owner_wiring
check_data_contract_registry_escaped_identifier_wiring

echo "Data contract/domain boundaries passed (no forbidden platform imports/runtime symbols, no Realm adapter seam leaks, constructor wiring boundaries preserved including registry-default declarations, registry spatial-adapter assignment seams preserved including parenthesized/multiline/split-member/parenthesized-owner/parenthesized-alias-owner/nested-parenthesized-owner/cast-owner/nested-cast-owner/forced-optional-cast-owner/optional-metatype-cast-owner/cast-coalescing-owner/spaced-member/comment-interleaved/block-comment-separated/metatype-self-owner/chained-metatype-self-owner/parenthesized-chained-metatype-self-owner/chained-metatype-self-cast-owner/inout/key-path/metatype-alias/typealias/typealias-chain/typealias-derived-metatype-alias/escaped-alias-owner/escaped-owner/escaped-identifier wiring detection, and test-only registry overrides)."
