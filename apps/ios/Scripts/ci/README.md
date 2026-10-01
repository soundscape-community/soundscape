# Releasing an uploaded build to external TestFlight

Upload your archive from Xcode using **App Store Connect** distribution. A build
uploaded using **TestFlight Internal Only** cannot be released to external groups.
Wait for processing to finish and complete any export compliance questions.

Once `.github/workflows/release-testflight.yml` is merged into the default branch,
open GitHub **Actions → Release uploaded build to external TestFlight → Run workflow**.
Enter the existing external group names or IDs, separated by commas. Leave the
version and build blank to select the most recently uploaded iOS build, or enter
them to select a particular upload. Optional **What to Test** text updates the
build's testing notes; leaving it blank preserves the notes in App Store Connect.

The workflow uses Fastlane to submit the selected build for beta review when
needed, assign it to the requested groups, and enable tester notifications. Apple
may need to approve the build before testers can install it. The final external
build state is reported in the job summary. If a run fails after submitting for
review, it can be rerun for the same version and build to finish assigning groups.
Complete the app's beta description, feedback email, and review contact details
in App Store Connect before the first submission.

Authentication uses the existing **Production** environment secrets:

- `APP_STORE_P8_BASE64`: base64 encoded App Store Connect `.p8` private key
- `APP_STORE_KEY_ID`: API key ID
- `APP_STORE_ISSUER_ID`: issuer ID

The API key must have the **App Manager** or **Admin** role and access to Soundscape.
Signing certificates and provisioning permissions are not needed. This workflow
only distributes an existing upload; it does not build or upload a binary.

The Production environment's deployment branch rules must allow the branch used
to run the workflow (normally `main`). If GitHub blocks the job before it starts,
an administrator should check **Settings → Environments → Production → Deployment
branches and tags** and allow `main`.

References: [Fastlane TestFlight distribution](https://docs.fastlane.tools/actions/testflight/)
and [Apple's external testing requirements](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).
