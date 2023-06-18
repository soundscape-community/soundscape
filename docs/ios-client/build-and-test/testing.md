# Testing
Note that this file may only be relevant to the default `Soundscape` scheme (not necessarily others such as `Soundscape - Dogfood`).

## Running Tests
### Running Tests via GitHub Actions
*This is currently planned but not yet implemented.*

### Manually Running Tests
To manually run tests in XCode, go to **Product** → **Test** (`⌘U`) or click and hold down the run button to show more options and select **Test**. This will build the project and run the test plan.

## Creating Tests
Go to the Tests Navigator tab (`⌘6`) to see all tests. Tests may be added to existing files, and new test classes may be added by right clicking on the Test Navigator or clicking the `+` icon in the bottom-left of the Test Navigator. The organization of tests is detailed below.

## Test Plan & Organization
Separate test plans are included for each type of test *(currently only unit tests)*:

### Unit Tests
Settings for the unit test plan are included in `apps/ios/UnitTests.xctestplan`. It runs the `UnitTests` test target which are located in `apps/ios/UnitTests/`. The tests are run on the Soundscape app target.

Within the unit tests directory, the file structure reflects the `apps/ios/GuideDogs/Code` file structure with tests for the corresponding files.