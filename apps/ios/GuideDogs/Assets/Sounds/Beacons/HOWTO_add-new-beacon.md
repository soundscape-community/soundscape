# HOW-TO: Add new beacon sound theme

## Sound files
The files need to be in .wav format.

One can have four different assets of a beacon sound. They describe regions in relation to a target.

* A+        Central 30 degrees, `(angle >= 345 || angle <= 15)`
* A         40 degree windows, `(angle >= 305 && angle <= 345) || (angle >= 15 && angle <= 55)`
* B         70 degree windows, `(angle >= 235 && angle <= 305) || (angle >= 55 && angle <= 125)`
* Behind    Remaining window, `angle >  125 && angle <  235`

For having sounds for all these regions, there should be four corresponding .wav files.

## Add sound files to Xcode project
For the new sound files to be recognized, they have to be added as assets to the Xcode project.

1. Place the .wav files in a new folder under `apps/ios/GuideDogs/Assets/Sounds/Beacons`, e.g. `MyAmazingSound`.
```bash
$ mkdir apps/ios/GuideDogs/Assets/Sounds/Beacons/MyAmazingSound
$ cp <path to .wav files>/*.wav apps/ios/GuideDogs/Assets/Sounds/Beacons/MyAmazingSound
$ ls -l apps/ios/GuideDogs/Assets/Sounds/Beacons/MyAmazingSound 
        ... MyAmazingSound_A+.wav
        ... MyAmazingSound_A.wav
        ... MyAmazingSound_B.wav
        ... MyAmazingSound_Behind.wav
```

2. Open `apps/ios/GuideDogs.xcworkspace` in Xcode.
3. Click on the folder icon on the top left and then click "GuideDogs".
4. Choose "Build Phases" among the tab labels.
5. Scroll down to "Copy Bundle Resources" and expand by clicking on it.
6. Drag-and-drop the .wav files to the expanded menu containing all other resources, and just click "Finish" in the window that pops up.

## Integrate new sound to Soundscape app

### BeaconOption.swift
Open file `apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption.swift` and add:
- `case myAmazingSound` to the `BeaconOption` enum, and
- `case .myAmazingSound: return MyAmazingSoundBeacon.description` to the switch-case in `var id: String`.

```bash
diff --git a/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption.swift b/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption.swift
index 046db81..08f1d4c 100644
--- a/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption.swift     
+++ b/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption.swift     
@@ -22,6 +22,7 @@ enum BeaconOption: String, CaseIterable, Identifiable {
     case mallet
     case malletSlow
     case malletVerySlow
+    case myAmazingSound
     // Update `style` (see "Beacon+Style") when adding a new
     // haptic beacon
     case wand
@@ -42,6 +43,7 @@ enum BeaconOption: String, CaseIterable, Identifiable {
         case .mallet: return MalletBeacon.description
         case .malletSlow: return MalletSlowBeacon.description
         case .malletVerySlow: return MalletVerySlowBeacon.description
+        case .myAmazingSound: return MyAmazingSoundBeacon.description
         case .wand: return HapticWandBeacon.description
         case .pulse: return HapticPulseBeacon.description
         }
```

### BeaconOption+Strings.swift
Open file `apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption+Strings.swift` and add:
- `case .myAmazingSound: return GDLocalizedString("beacon.styles.my_amazing_sound")` to the switch-case in `var localizedName: String`.

```bash
diff --git a/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption+Strings.swift b/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption+Strings.swift
index 2511795..1f9e1a7 100644
--- a/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption+Strings.swift     
+++ b/apps/ios/GuideDogs/Code/Audio/Audio Beacon/BeaconOption+Strings.swift     
@@ -25,6 +25,7 @@ extension BeaconOption {
         case .mallet: return GDLocalizedString("beacon.styles.mallet")
         case .malletSlow: return GDLocalizedString("beacon.styles.mallet.slow")
         case .malletVerySlow: return GDLocalizedString("beacon.styles.mallet.very_slow")
+        case .myAmazingSound: return GDLocalizedString("beacon.styles.my_amazing_sound")
         case .wand: return GDLocalizedString("beacon.styles.haptic.wand")
         case .pulse: return GDLocalizedString("beacon.styles.haptic.pulse")
         }
```

### DynamicAudioEngineAssets.swift
Open file `apps/ios/GuideDogs/Code/Audio/Engine Assets/DynamicAudioEngineAssets.swift` and add new enum:
```swift
enum MyAmazingSoundBeacon: String, DynamicAudioEngineAsset {
    case center = "MyAmazingSound_A+"
    case offset = "MyAmazingSound_A"
    case side   = "MyAmazingSound_B"
    case behind = "MyAmazingSound_Behind"
    
    static var selector: AssetSelector? = MyAmazingSoundBeacon.defaultSelector()
    static let beatsInPhrase: Int = 6
}
```

```bash
diff --git a/apps/ios/GuideDogs/Code/Audio/Engine Assets/DynamicAudioEngineAssets.swift b/apps/ios/GuideDogs/Code/Audio/Engine Assets/DynamicAudioEngineAssets.swift
index 3811dc1..8835a26 100644
--- a/apps/ios/GuideDogs/Code/Audio/Engine Assets/DynamicAudioEngineAssets.swift        
+++ b/apps/ios/GuideDogs/Code/Audio/Engine Assets/DynamicAudioEngineAssets.swift        
@@ -59,6 +59,16 @@ enum ShimmerBeacon: String, DynamicAudioEngineAsset {
     static let beatsInPhrase: Int = 6
 }
 
+enum MyAmazingSoundBeacon: String, DynamicAudioEngineAsset {
+    case center = "MyAmazingSound_A+"
+    case offset = "MyAmazingSound_A"
+    case side   = "MyAmazingSound_B"
+    case behind = "MyAmazingSound_Behind"
+    
+    static var selector: AssetSelector? = MyAmazingSoundBeacon.defaultSelector()
+    static let beatsInPhrase: Int = 6
+}
+
 enum PingBeacon: String, DynamicAudioEngineAsset {
     case center = "Ping_A+"
     case offset = "Ping_A"
```

### DestinationManager.swift
Open file `apps/ios/GuideDogs/Code/Data/Destination Manager/DestinationManager.swift` and add
- `case MyAmazingSoundBeacon.description: playBeacon(MyAmazingSoundBeacon.self, args: args)` to switch-case `switch SettingsContext.shared.selectedBeacon`.

```bash
diff --git a/apps/ios/GuideDogs/Code/Data/Destination Manager/DestinationManager.swift b/apps/ios/GuideDogs/Code/Data/Destination Manager/DestinationManager.swift
index ba59990..ff37e9b 100644
--- a/apps/ios/GuideDogs/Code/Data/Destination Manager/DestinationManager.swift 
+++ b/apps/ios/GuideDogs/Code/Data/Destination Manager/DestinationManager.swift 
@@ -495,6 +495,7 @@ class DestinationManager: DestinationManagerProtocol {
         case MalletBeacon.description: playBeacon(MalletBeacon.self, args: args)
         case MalletSlowBeacon.description: playBeacon(MalletSlowBeacon.self, args: args)
         case MalletVerySlowBeacon.description: playBeacon(MalletVerySlowBeacon.self, args: args)
+        case MyAmazingSoundBeacon.description: playBeacon(MyAmazingSoundBeacon.self, args: args)
         case HapticWandBeacon.description:
             hapticBeacon = HapticWandBeacon(at: args.loc)
             hapticBeacon?.start()
```

### Localizable.strings
Depending on the language set in the Soundscape app, add a display name for the new sound theme.

Assuming the language is set to English (US), open file `apps/ios/GuideDogs/Assets/Localization/en-US.lproj/Localizable.strings` and add  new mapping.

```bash
diff --git a/apps/ios/GuideDogs/Assets/Localization/en-US.lproj/Localizable.strings b/apps/ios/GuideDogs/Assets/Localization/en-US.lproj/Localizable.strings
index ff8917c..e8bbfa4 100644
--- a/apps/ios/GuideDogs/Assets/Localization/en-US.lproj/Localizable.strings
+++ b/apps/ios/GuideDogs/Assets/Localization/en-US.lproj/Localizable.strings
@@ -651,6 +651,9 @@
 /* Name of a beacon style. "Mallet" is used in the same way here as in the string with key 'beacon.styles.mallet'. The difference here is that this version is a much slower version of the beacon audio. */
 "beacon.styles.mallet.very_slow" = "Mallet (Very Slow)";
 
+/* Name of a beacon style. */
+"beacon.styles.my_amazing_sound" = "My Amazing Sound";
+
 /* Name of a beacon style. Unlike the other beacon styles, this style include haptic feedback (e.g. vibration feedback from the iPhone). The term "wand" is used to refer to a pointing device. Together, this name is intended to convey that this beacon style provides haptic feedback to the user when they hold their phone in front of them and point it around. */
 "beacon.styles.haptic.wand" = "Haptic Wand";
```


Now the new beacon sound theme is ready to be used. Simply build and run the Sounscape app, open the menu, go to "Settings" -> "Audio Beacon" and there the new beacon sound should be visible. Click on it to select it, then trigger a beacon sound from the main window to hear how it sounds!