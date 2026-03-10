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
DERIVED_DATA_PATH=""
LOG_DIR="${TMPDIR:-/tmp}/soundscape-ios-logs"
DESTINATION=""
SIMULATOR_ID=""
SIMULATOR_NAME=""
LIST_SIMULATORS=0
RUN_BUILD=1
RUN_TEST=1

usage() {
  cat <<'EOF'
Usage: run_local_ios_build_test.sh [options]

Options:
  --build-only                 Run build-for-testing only.
  --test-only                  Run test-without-building only.
  --output <errors|xcpretty|raw|summary|quiet>
                               Output mode (default: errors). `quiet` aliases `summary`.
  --destination "<xcode destination>"
                               Full xcodebuild destination string.
  --simulator-id <id>          iOS simulator UDID to use.
  --simulator-name <name>      Preferred iPhone device name substring.
  --derived-data-path <path>   Custom DerivedData path.
  --log-dir <path>             Directory for full xcodebuild logs.
  --workspace <path>           Workspace path (default: GuideDogs.xcworkspace).
  --scheme <name>              Scheme name (default: Soundscape).
  --list-simulators            Print available iPhone simulators and exit.
  --help                       Print this help.

Examples:
  bash apps/ios/Scripts/ci/run_local_ios_build_test.sh
  bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --output quiet
  bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --output summary
  bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --output xcpretty
  bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --build-only --derived-data-path /tmp/ss-index-derived
EOF
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

print_summary_from_log() {
  local step_name="$1"
  local log_file="$2"
  local step_status="$3"

  local test_summary
  local error_count
  local warning_count

  test_summary="$(grep -E 'Executed [0-9]+ tests?, with [0-9]+ failures? \([0-9]+ unexpected\) in ' "${log_file}" | tail -n 1 || true)"
  error_count="$(grep -E -c '^error: |:[0-9]+:[0-9]+: error: |\*\* BUILD FAILED \*\*|\*\* TEST FAILED \*\*|^Testing failed:' "${log_file}" || true)"
  warning_count="$(grep -E -c '^warning: |:[0-9]+:[0-9]+: warning: ' "${log_file}" || true)"

  if [[ "${step_status}" -eq 0 ]]; then
    echo "${step_name} passed."
    if [[ -n "${test_summary}" ]]; then
      echo "${test_summary}"
    fi
    echo "Issue counts: errors=${error_count}, warnings=${warning_count}"
    return 0
  fi

  echo "${step_name} failed (exit ${step_status}). See ${log_file}" >&2
  echo "Failure summary (filtered):" >&2
  local filtered_output
  filtered_output="$(filter_xcodebuild_issues < "${log_file}" | tail -n 120 || true)"
  if [[ -n "${filtered_output}" ]]; then
    printf '%s\n' "${filtered_output}" >&2
  else
    tail -n 120 "${log_file}" >&2 || true
  fi
  echo "Issue counts: errors=${error_count}, warnings=${warning_count}" >&2
  return 0
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
  if [[ "${OUTPUT_MODE}" == "summary" ]]; then
    "${cmd[@]}" >"${log_file}" 2>&1
    step_status=$?
  elif [[ "${OUTPUT_MODE}" == "raw" ]]; then
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

  if [[ "${OUTPUT_MODE}" == "summary" ]]; then
    print_summary_from_log "${step_name}" "${log_file}" "${step_status}"
  fi

  if [[ ${step_status} -ne 0 ]]; then
    if [[ "${OUTPUT_MODE}" == "summary" ]]; then
      return "${step_status}"
    fi
    echo "${step_name} failed (exit ${step_status}). See ${log_file}" >&2
    return "${step_status}"
  fi

  if [[ "${OUTPUT_MODE}" == "summary" ]]; then
    return 0
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

if [[ "${OUTPUT_MODE}" == "quiet" ]]; then
  OUTPUT_MODE="summary"
fi

if [[ "${OUTPUT_MODE}" != "errors" && "${OUTPUT_MODE}" != "xcpretty" && "${OUTPUT_MODE}" != "raw" && "${OUTPUT_MODE}" != "summary" ]]; then
  echo "Invalid --output value: ${OUTPUT_MODE}. Expected errors, xcpretty, raw, summary, or quiet." >&2
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

declare -a common_args=(
  -workspace "${WORKSPACE_PATH}"
  -scheme "${SCHEME_NAME}"
  -destination "${DESTINATION}"
)

if [[ -n "${DERIVED_DATA_PATH}" ]]; then
  common_args+=(-derivedDataPath "${DERIVED_DATA_PATH}")
fi

if [[ ${RUN_BUILD} -eq 1 ]]; then
  run_xcodebuild_step "build-for-testing" \
    xcodebuild build-for-testing \
    "${common_args[@]}" \
    CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
fi

if [[ ${RUN_TEST} -eq 1 ]]; then
  run_xcodebuild_step "test-without-building" \
    xcodebuild test-without-building \
    "${common_args[@]}"
fi

echo "Completed requested xcodebuild step(s)."
