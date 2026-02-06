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
cd apps/ios
swift Scripts/LocalizationLinter/main.swift
```

Build for testing:

```sh
xcodebuild build-for-testing -workspace GuideDogs.xcworkspace \
  -scheme Soundscape \
  -destination "platform=iOS Simulator,OS=18.1,name=iPhone 16" \
  CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Run tests:

```sh
xcodebuild test-without-building -workspace GuideDogs.xcworkspace \
  -scheme Soundscape \
  -destination "platform=iOS Simulator,OS=18.1,name=iPhone 16"
```

## Fastlane (Optional)

Fastlane lanes are in `apps/ios/fastlane`.

If you use Fastlane locally:

```sh
cd apps/ios
bundle install
```
