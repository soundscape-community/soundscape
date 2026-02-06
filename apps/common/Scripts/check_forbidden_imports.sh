#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCES_DIR="${ROOT_DIR}/Sources"
readonly FORBIDDEN_PATTERN='^(@_exported[[:space:]]+)?import[[:space:]]+(UIKit|SwiftUI|CoreLocation|MapKit|AVFoundation|CoreMotion|CoreBluetooth|UserNotifications|MediaPlayer|CoreHaptics|Contacts|SafariServices|WebKit|Intents|StoreKit|MessageUI|IntentsUI|SceneKit|GLKit)\b'

if rg --line-number --no-heading --glob '*.swift' --regexp "${FORBIDDEN_PATTERN}" "${SOURCES_DIR}"; then
  echo "Forbidden platform-specific imports found in ${SOURCES_DIR}" >&2
  exit 1
fi

echo "No forbidden platform-specific imports found in ${SOURCES_DIR}"
