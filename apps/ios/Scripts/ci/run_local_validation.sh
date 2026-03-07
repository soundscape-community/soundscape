#!/usr/bin/env bash
#
# Copyright (c) Soundscape Community Contributers.
#
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IOS_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT="$(cd "${IOS_DIR}/../.." && pwd)"

SKIP_IOS_BUILD_TEST=0
declare -a IOS_BUILD_TEST_ARGS=()

usage() {
  cat <<'EOF'
Usage: run_local_validation.sh [--skip-ios-build-test] [-- <run_local_ios_build_test args>]

Runs the common local validation baseline:
1) apps/common boundary check
2) apps/common package tests
3) iOS localization linter
4) iOS seam and boundary scripts
5) iOS build+test (unless skipped)

Examples:
  bash apps/ios/Scripts/ci/run_local_validation.sh
  bash apps/ios/Scripts/ci/run_local_validation.sh -- --output summary
  bash apps/ios/Scripts/ci/run_local_validation.sh -- --output xcpretty
  bash apps/ios/Scripts/ci/run_local_validation.sh --skip-ios-build-test
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ios-build-test)
      SKIP_IOS_BUILD_TEST=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      IOS_BUILD_TEST_ARGS=("$@")
      break
      ;;
    *)
      IOS_BUILD_TEST_ARGS+=("$1")
      shift
      ;;
  esac
done

echo "Step 1/5: apps/common forbidden import boundary check"
bash "${REPO_ROOT}/apps/common/Scripts/check_forbidden_imports.sh"

echo "Step 2/5: apps/common package tests"
swift test --package-path "${REPO_ROOT}/apps/common"

echo "Step 3/5: iOS localization linter"
(
  cd "${IOS_DIR}"
  swift Scripts/LocalizationLinter/main.swift
)

echo "Step 4/5: iOS seam and boundary scripts"
(
  cd "${IOS_DIR}"
  bash Scripts/ci/check_spatial_data_cache_seam.sh
  bash Scripts/ci/check_realm_infrastructure_boundary.sh
  bash Scripts/ci/check_data_contract_boundaries.sh
  bash Scripts/ci/check_data_contract_infra_type_allowlist.sh
  bash Scripts/ci/check_route_mutation_seam.sh
)

if [[ ${SKIP_IOS_BUILD_TEST} -eq 1 ]]; then
  echo "Step 5/5: iOS build/test skipped (--skip-ios-build-test)."
else
  echo "Step 5/5: iOS build and test"
  if [[ ${#IOS_BUILD_TEST_ARGS[@]} -gt 0 ]]; then
    bash "${IOS_DIR}/Scripts/ci/run_local_ios_build_test.sh" "${IOS_BUILD_TEST_ARGS[@]}"
  else
    bash "${IOS_DIR}/Scripts/ci/run_local_ios_build_test.sh"
  fi
fi

echo "Local validation baseline completed."
