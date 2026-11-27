# Soundscape: 3D audio awareness for everyone

[![Build Status](https://github.com/soundscape-community/soundscape/actions/workflows/build-for-testflight.yml/badge.svg)](https://github.com/soundscape-community/soundscape/actions/workflows/build-for-testflight.yml)
[![Translation Status](https://hosted.weblate.org/widgets/openscape/-/svg-badge.svg)](https://hosted.weblate.org/engage/openscape/)

This is a community effort to bring the features of [Microsoft Soundscape](https://www.microsoft.com/en-us/research/product/soundscape/) back to blind and visually-impaired travelers everywhere. Starting with the [components released as open source](https://github.com/microsoft/soundscape) by Microsoft Research, we have filled in some of the missing pieces and services to keep it functional.

## What was Microsoft Soundscape?

>Microsoft Soundscape \[was] a product from Microsoft Research that explored the use of innovative audio-based technology to enable people to build a richer awareness of their surroundings, thus becoming more confident and empowered to get around. Unlike step-by-step navigation apps, Soundscape uses 3D audio cues to enrich ambient awareness and provide a new way to relate to the environment. It allows you to build a mental map and make personal route choices while being more comfortable within unfamiliar spaces. Soundscape is designed to be used by everyone and live in the background; therefore, feel free to use it in conjunction with other apps such as podcasts, audio books, email and even GPS navigation!

For more technical details, see the [original README](https://github.com/microsoft/soundscape/blob/main/README.md) from the open-source Soundscape repository.

## Building Soundscape

See the [iOS client build documentation](https://github.com/soundscape-community/soundscape/blob/main/docs/ios-client/onboarding.md) in the repo, along with the [build tips](https://github.com/soundscape-community/soundscape/wiki/build-tips) on the wiki.

### Shared SSData package

Run `swift test --package-path apps/common` from the repository root on macOS or Ubuntu with Swift 6.1 or newer. On Ubuntu, install `libsqlite3-dev` first.

On an Apple Silicon Mac, install Skip, Swiftly, JDK 21, and the Android SDK Command-Line Tools. The commands below were verified with Skip 1.9.23. Make `skip`, `swiftly`, `sdkmanager`, and `avdmanager` available on `PATH`, and set `JAVA_HOME` to your JDK. Run `swiftly init --skip-install` if Swiftly has not been initialized. [Skip setup](https://skip.dev/docs/gettingstarted/) · [Skip 1.9.23 binaries](https://github.com/skiptools/skip/releases/tag/1.9.23) · [Android SDK Command-Line Tools](https://developer.android.com/tools/sdkmanager)

```sh
export ANDROID_HOME="$HOME/Library/Android/sdk"
skip android sdk install --version 6.4.3
export ANDROID_NDK_HOME="$HOME/Library/org.swift.swiftpm/swift-sdks/swift-6.4.3-RELEASE_android.artifactbundle/swift-android/android-ndk-r30"

sdkmanager --sdk_root="$ANDROID_HOME" --licenses
sdkmanager --sdk_root="$ANDROID_HOME" --install platform-tools emulator 'system-images;android-36;google_apis;arm64-v8a'
avdmanager create avd --name ssdata-arm64 --package 'system-images;android-36;google_apis;arm64-v8a'
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
emulator -avd ssdata-arm64 -no-window -no-audio -no-snapshot &
adb wait-for-device
```

Once `adb shell getprop sys.boot_completed` returns `1`, run the native Skip Fuse build or XCTest suite from the repository root. The helper targets ARM64 at API level 28 and uses the NDK supplied to Skip to compile the pinned SQLite 3.54.1 source with FTS5 and WAL snapshots.

```sh
apps/android/Scripts/ssdata-android.sh build
apps/android/Scripts/ssdata-android.sh test
```

After the test, inspect the ELF dynamic dependencies of the test runner and its companion test library. The output should contain no `NEEDED` entry for `libsqlite3.so`.

```sh
test_dir=apps/android/.build/ssdata/out/Products/Debug-android-aarch64
"$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf" \
  -d "$test_dir/SSDataTests-test-runner" "$test_dir/SSDataTests.so"
```

## Getting involved

Browse through the [open issues](https://github.com/soundscape-community/soundscape/issues). Items labeled "help-wanted" are particularly good candidates for contribution.

Join [our Discord server](https://discord.gg/VQHkZJ8mcA) to discuss the project, give feedback, or just say hello.

[Translate Soundscape](https://hosted.weblate.org/engage/openscape/) in your own language or contribute to an existing translation on Weblate.
