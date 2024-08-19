# Build Configurations

The Soundscape Xcode project contains 3 build configurations. We used each configuration for the purposes defined below, but you may wish to use a different configuration model.

* **Debug** - Used for local builds / when installing directly from Xcode
* **AdHoc** - Used for testing outside of TestFlight releases
* **Release** - Used for AppStore and TestFlight builds

## Feature Flags

Each build configuration may enable a different set of feature flags via the files:  
`/apps/ios/GuideDogs/Assets/Configurations/FeatureFlags-<<Configuration>>`

See for additional documentation and to define feature flags within the code, see:  
`/apps/ios/GuideDogs/Code/App/Feature Flags/FeatureFlag.swift`

## Creating test builds for your local device

You can test out your own builds of Soundscape on a physical device, even if you're not a paid member of the Apple Developer Program, but you'll need to adjust some build settings . Under GuideDogs > Signing & Capabilities > Debug:

1. Change the "Bundle Identifier" to services.soundscape-debug.your_username
2. Click the trash can icon next to:
    1. Associated Domains
    2. iCloud

Once this is done, you should be able to use your device as the Xcode build target. You may additionally need to adjust some settings on your device, including enableing Developer Mode under Settings > Privacy & Security.
