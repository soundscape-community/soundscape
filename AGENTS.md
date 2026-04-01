# Agent Notes

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

Current intended workflow for IB removal:

1. Run `InterfaceBuilderAudit`.
2. Start with `stale_symbol` and `unreferenced` candidates.
3. Remove the IB asset plus its project-file references in the same change.
4. Replace dead segue or storyboard navigation paths with explicit programmatic routing.
5. Re-run the audit and confirm the candidate set shrinks as expected.

If the script itself changes, keep this note aligned with its supported flags and classifications.
