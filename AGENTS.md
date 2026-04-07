# Agent Notes

## Copyright notices

- Never add new `Copyright (c) Microsoft Corporation.` notices to files changed in this repository.
- Add `Copyright (c) Soundscape Community Contributors.` to new code files.
- When modifying an existing code file that already has a Microsoft copyright notice, keep the Microsoft notice and add the Soundscape Community Contributors notice as well.
- Do not remove or rewrite existing Microsoft copyright notices in established files unless a Microsoft notice was added to a non-Microsoft file by mistake and you are correcting that mistake.

## iOS Interface Builder cleanup

Use `apps/ios/Scripts/InterfaceBuilderAudit/main.swift` before removing storyboard or xib assets from the iOS app.

- Run from the repo root:
  - `apps/ios/Scripts/InterfaceBuilderAudit/main.swift --only candidates --kind all --format text`
- Run from `apps/ios`:
  - `./Scripts/InterfaceBuilderAudit/main.swift --only candidates --kind all --format text`
- Use `--format json` when another tool or agent needs machine-readable output.
- Use `--kind storyboard` or `--kind xib` to narrow the scan.
- Use `--root <path>` if auto-detection fails.

The script scans:

- `apps/ios/GuideDogs/**/*.storyboard`
- `apps/ios/GuideDogs/**/*.xib`
- `apps/ios/GuideDogs/**/*.swift`
- `apps/ios/GuideDogs/Assets/PropertyLists/Info.plist`
- `apps/ios/GuideDogs.xcodeproj/project.pbxproj`

It classifies assets and storyboard scenes as:

- `active_direct`: directly referenced from Swift, plist, or project files
- `active_indirect`: referenced through storyboard placeholders or related IB wiring
- `wrapper_only`: minimal hosting or container shells that are still intentional
- `stale_symbol`: IB metadata references a missing custom class or stale symbol
- `unreferenced`: no useful references were found
- `project_orphan`: file is not tracked in the Xcode project

Use the script to drive cleanup batches. Do not delete storyboard/xib files based only on visual inspection; confirm the candidate with the audit output and then verify the runtime path in code.

Additional xib caution:

- Treat `unreferenced` xibs with a `File's Owner` custom class or IBOutlet wiring as suspicious until you verify the runtime construction path in code.
- A xib can be live even when Swift only instantiates the owning controller class and never mentions the xib filename directly.
- Build success is not enough to prove a xib is dead; nib-backed controllers can fail only at runtime when outlets load as `nil`.

Current intended workflow for IB removal:

1. Run `InterfaceBuilderAudit`.
2. Start with `stale_symbol` and `unreferenced` candidates.
3. For xibs, inspect the file owner and root custom class, then confirm whether those classes are instantiated anywhere even if the xib name is not searched directly.
4. Remove the IB asset plus its project-file references in the same change.
5. Replace dead segue or storyboard navigation paths with explicit programmatic routing.
6. Re-run the audit and confirm the candidate set shrinks as expected.

If the script itself changes, keep this note aligned with its supported flags and classifications.
