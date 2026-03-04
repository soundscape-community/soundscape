# Soundscape iOS App

This document describes how to build and test the Soundscape iOS app in this repository.

## CI-Aligned Tooling Baseline

The `ios-tests` workflow (`.github/workflows/ios-tests.yml`) currently uses:

- Xcode 16.1
- iOS Simulator destination: `platform=iOS Simulator,OS=18.1,name=iPhone 16`

Use this as the default baseline for local command-line builds when possible.

## Prerequisites

- Xcode with command line tools installed:

```sh
xcode-select --install
```

## Workspace

The iOS project entry point is:

- `apps/ios/GuideDogs.xcworkspace`

## Local Build, Lint, and Test Commands

From repository root:

```sh
bash apps/ios/Scripts/ci/run_local_validation.sh
```

Output modes:

```sh
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output xcpretty
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output raw
```

Build/test only (auto-selects an installed iPhone simulator, default output is errors-only):

```sh
bash apps/ios/Scripts/ci/run_local_ios_build_test.sh
```

## Fastlane (Optional)

Fastlane lanes are in `apps/ios/fastlane`.

If you use Fastlane locally:

```sh
cd apps/ios
bundle install
```
