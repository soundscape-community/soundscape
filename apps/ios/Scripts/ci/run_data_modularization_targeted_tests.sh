#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IOS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

WORKSPACE_PATH="${IOS_DIR}/GuideDogs.xcworkspace"
SCHEME_NAME="Soundscape"
OUTPUT_MODE="errors"
DERIVED_DATA_PATH="/tmp/soundscape-modularization-dd"
LOG_DIR="${TMPDIR:-/tmp}/soundscape-ios-logs"
DESTINATION=""
SIMULATOR_ID=""
SIMULATOR_NAME=""
LIST_SIMULATORS=0
RUN_BUILD=1
RUN_TEST=1

readonly -a TARGETED_SUITES=(
  "UnitTests/RouteStorageProviderDispatchTests"
  "UnitTests/DataContractRegistryDispatchTests"
  "UnitTests/CloudSyncContractBridgeTests"
)

usage() {
  cat <<'USAGE'
Usage: run_data_modularization_targeted_tests.sh [options]

Runs low-noise targeted data modularization suites.
By default:
1) build-for-testing
2) targeted test-without-building for:
   - UnitTests/RouteStorageProviderDispatchTests
   - UnitTests/DataContractRegistryDispatchTests
   - UnitTests/CloudSyncContractBridgeTests

Options:
  --build-only                 Run build-for-testing only.
  --test-only                  Run targeted test-without-building only.
  --output <errors|xcpretty|raw>
                               Output mode (default: errors).
  --destination "<xcode destination>"
                               Full xcodebuild destination string.
  --simulator-id <id>          iOS simulator UDID to use.
  --simulator-name <name>      Preferred iPhone device name substring.
  --derived-data-path <path>   DerivedData path (default: /tmp/soundscape-modularization-dd).
  --log-dir <path>             Directory for full xcodebuild logs.
  --workspace <path>           Workspace path (default: GuideDogs.xcworkspace).
  --scheme <name>              Scheme name (default: Soundscape).
  --list-simulators            Print available iPhone simulators and exit.
  --help                       Print this help.

Examples:
  bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh
  bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output xcpretty
  bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --test-only
USAGE
}

filter_xcodebuild_issues() {
  awk '
    /\*\* BUILD FAILED \*\*/ { print; next }
    /\*\* TEST FAILED \*\*/ { print; next }
    /^Testing failed:/ { print; next }
    /^Failing tests:/ { print; next }
    /^Test Case .+ failed/ { print; next }
    /^error: / { print; next }
    /:[0-9]+:[0-9]+: error: / { print; next }
  '
}

list_available_iphone_simulators() {
  xcrun simctl list devices available \
    | grep 'iPhone' \
    | grep -E '\([0-9A-F-]{36}\)' \
    || true
}

resolve_destination() {
  if [[ -n "${DESTINATION}" ]]; then
    return 0
  fi

  if [[ -n "${SIMULATOR_ID}" ]]; then
    DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"
    return 0
  fi

  local available_lines filtered_lines selected_line booted_line
  available_lines="$(list_available_iphone_simulators)"
  filtered_lines="${available_lines}"

  if [[ -n "${SIMULATOR_NAME}" ]]; then
    filtered_lines="$(printf '%s\n' "${available_lines}" | grep -F "${SIMULATOR_NAME}" || true)"
  fi

  booted_line="$(printf '%s\n' "${filtered_lines}" | grep 'Booted' | head -n 1 || true)"
  selected_line="${booted_line}"
  if [[ -z "${selected_line}" ]]; then
    selected_line="$(printf '%s\n' "${filtered_lines}" | head -n 1)"
  fi

  SIMULATOR_ID="$(printf '%s\n' "${selected_line}" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')"
  if [[ -z "${SIMULATOR_ID}" ]]; then
    echo "No available iPhone simulator found. Create one locally in Xcode." >&2
    return 1
  fi

  DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"
  echo "Selected simulator: $(printf '%s\n' "${selected_line}" | sed -E 's/^[[:space:]]*//')"
}

run_xcodebuild_step() {
  local step_name="$1"
  shift
  local -a cmd=("$@")

  mkdir -p "${LOG_DIR}"
  local log_file="${LOG_DIR}/$(date -u +"%Y%m%d-%H%M%SZ")-${step_name}.log"

  echo "Running ${step_name}..."
  echo "Destination: ${DESTINATION}"
  echo "Full log: ${log_file}"

  local step_status=0
  set +e
  if [[ "${OUTPUT_MODE}" == "raw" ]]; then
    "${cmd[@]}" 2>&1 | tee "${log_file}"
    step_status=${PIPESTATUS[0]}
  elif [[ "${OUTPUT_MODE}" == "xcpretty" ]]; then
    if command -v xcpretty >/dev/null 2>&1; then
      "${cmd[@]}" 2>&1 | tee "${log_file}" | xcpretty
      step_status=${PIPESTATUS[0]}
    else
      echo "xcpretty not found; falling back to errors output mode." >&2
      "${cmd[@]}" 2>&1 | tee "${log_file}" | filter_xcodebuild_issues
      step_status=${PIPESTATUS[0]}
    fi
  else
    "${cmd[@]}" 2>&1 | tee "${log_file}" | filter_xcodebuild_issues
    step_status=${PIPESTATUS[0]}
  fi
  set -e

  if [[ ${step_status} -ne 0 ]]; then
    echo "${step_name} failed (exit ${step_status}). See ${log_file}" >&2
    return "${step_status}"
  fi

  echo "${step_name} passed."
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only)
      RUN_TEST=0
      ;;
    --test-only)
      RUN_BUILD=0
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --output" >&2
        exit 1
      fi
      OUTPUT_MODE="$2"
      shift
      ;;
    --destination)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --destination" >&2
        exit 1
      fi
      DESTINATION="$2"
      shift
      ;;
    --simulator-id)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --simulator-id" >&2
        exit 1
      fi
      SIMULATOR_ID="$2"
      shift
      ;;
    --simulator-name)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --simulator-name" >&2
        exit 1
      fi
      SIMULATOR_NAME="$2"
      shift
      ;;
    --derived-data-path)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --derived-data-path" >&2
        exit 1
      fi
      DERIVED_DATA_PATH="$2"
      shift
      ;;
    --log-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --log-dir" >&2
        exit 1
      fi
      LOG_DIR="$2"
      shift
      ;;
    --workspace)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --workspace" >&2
        exit 1
      fi
      WORKSPACE_PATH="$2"
      shift
      ;;
    --scheme)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --scheme" >&2
        exit 1
      fi
      SCHEME_NAME="$2"
      shift
      ;;
    --list-simulators)
      LIST_SIMULATORS=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ "${OUTPUT_MODE}" != "errors" && "${OUTPUT_MODE}" != "xcpretty" && "${OUTPUT_MODE}" != "raw" ]]; then
  echo "Invalid --output value: ${OUTPUT_MODE}. Expected errors, xcpretty, or raw." >&2
  exit 1
fi

if [[ ${RUN_BUILD} -eq 0 && ${RUN_TEST} -eq 0 ]]; then
  echo "Nothing to run. Choose default, --build-only, or --test-only." >&2
  exit 1
fi

if [[ ${LIST_SIMULATORS} -eq 1 ]]; then
  list_available_iphone_simulators
  exit 0
fi

resolve_destination

if [[ ${RUN_BUILD} -eq 1 ]]; then
  bash "${SCRIPT_DIR}/run_local_ios_build_test.sh" \
    --build-only \
    --destination "${DESTINATION}" \
    --derived-data-path "${DERIVED_DATA_PATH}" \
    --workspace "${WORKSPACE_PATH}" \
    --scheme "${SCHEME_NAME}" \
    --output "${OUTPUT_MODE}" \
    --log-dir "${LOG_DIR}"
fi

if [[ ${RUN_TEST} -eq 1 ]]; then
  declare -a cmd=(
    xcodebuild
    test-without-building
    -workspace "${WORKSPACE_PATH}"
    -scheme "${SCHEME_NAME}"
    -destination "${DESTINATION}"
    -derivedDataPath "${DERIVED_DATA_PATH}"
  )

  for suite in "${TARGETED_SUITES[@]}"; do
    cmd+=("-only-testing:${suite}")
  done

  run_xcodebuild_step "targeted-test-without-building" "${cmd[@]}"
fi

echo "Targeted modularization workflow completed."
