#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${REPO_ROOT}/docs/plans/artifacts/dependency-analysis}"

mkdir -p "${REPORT_DIR}"

TIMESTAMP="$(date -u +"%Y%m%d-%H%M%SZ")"
COMMIT_SHA="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
REPORT_FILE="${REPORT_DIR}/${TIMESTAMP}-ssindex-${COMMIT_SHA}.txt"
TMP_FILE="${REPORT_FILE}.tmp"

cleanup() {
  if [ -f "${TMP_FILE}" ]; then
    rm -f "${TMP_FILE}"
  fi
}
trap cleanup EXIT

DEFAULT_ARGS=(
  --top 40
  --min-count 2
  --file-top 40
  --external-top 25
)

if [ "$#" -gt 0 ]; then
  ANALYZER_ARGS=("$@")
else
  ANALYZER_ARGS=("${DEFAULT_ARGS[@]}")
fi

COMMAND=(
  swift
  run
  --package-path
  tools/SSIndexAnalyzer
  SSIndexAnalyzer
  "${ANALYZER_ARGS[@]}"
)

{
  echo "SSIndexAnalyzer Report"
  echo "Generated (UTC): ${TIMESTAMP}"
  echo "Git commit: ${COMMIT_SHA}"
  echo "Repository: ${REPO_ROOT}"
  echo "Command: ${COMMAND[*]}"
  echo ""
} > "${TMP_FILE}"

(
  cd "${REPO_ROOT}"
  "${COMMAND[@]}"
) >> "${TMP_FILE}"

mv "${TMP_FILE}" "${REPORT_FILE}"

cp "${REPORT_FILE}" "${REPORT_DIR}/latest.txt"

echo "Report written: ${REPORT_FILE}"
echo "Latest copy: ${REPORT_DIR}/latest.txt"
