# QA: Automated UI & Functional Testing

You are performing a comprehensive QA pass on this macOS Swift application. Your goal is to verify that every user-facing feature works as intended by writing and running automated tests.

## Background: XCUITest

XCUITest is Apple's native UI testing framework, built on top of XCTest and bundled with Xcode. It lets you write Swift code that launches the app, interacts with UI elements (buttons, text fields, menus, etc.), and asserts that the app reaches the expected state. Key classes:

- **XCUIApplication** — a proxy to launch and interact with the app
- **XCUIElement** — represents a UI element (button, label, text field, etc.)
- **XCUIElementQuery** — finds elements by type, identifier, or predicate
- **XCTAssert / XCTAssertEqual / XCTAssertTrue** — assertion functions to verify expected outcomes

UI elements are found via accessibility identifiers. If the app's views don't have accessibility identifiers set, you will need to add them as part of this QA process.

## Step 1: Analyze the Project

Before writing any tests:

1. Read the project's `CLAUDE.md`, `README.md`, and any documentation to understand what the app does.
2. Examine the full source tree. Identify every view, window, sheet, and user-facing feature.
3. Build a mental map of the app's navigation flow and all interactive elements.
4. List every distinct user action the app supports (e.g., "click Generate button", "select model from dropdown", "drag image to well", "open preferences", "export file").
5. Check if a UI Testing target already exists in the Xcode project. Look for a folder ending in `UITests` and a corresponding target in the `.xcodeproj` or `.xcworkspace`.

**Output a checklist** of every feature and user flow you've identified before proceeding. Ask me to confirm or add anything I want tested before you write code.

## Step 2: Ensure a UI Test Target Exists

If no UI test target exists:

1. Check if you can add one via `xcodebuild`. If not, instruct me to add a "macOS UI Testing Bundle" target in Xcode (File > New > Target > macOS UI Testing Bundle) and name it `<AppName>UITests`.
2. Verify the test target's host application is set to the main app target.
3. Confirm the test target compiles: `xcodebuild -scheme <AppName>UITests -destination 'platform=macOS' build-for-testing`

If a UI test target already exists, verify it builds cleanly before proceeding.

## Step 3: Add Accessibility Identifiers

For every interactive UI element you plan to test, ensure it has a `.accessibilityIdentifier` set in the source code. This is how XCUITest finds elements reliably.

Example for SwiftUI:
```swift
Button("Generate") { ... }
    .accessibilityIdentifier("generateButton")

TextField("Prompt", text: $prompt)
    .accessibilityIdentifier("promptTextField")
```

Example for AppKit/NSView:
```swift
button.setAccessibilityIdentifier("generateButton")
textField.setAccessibilityIdentifier("promptTextField")
```

**Rules:**
- Use camelCase identifiers that clearly describe the element.
- Add identifiers to ALL interactive elements: buttons, text fields, toggles, pickers, sliders, menu items, tab views, etc.
- Add identifiers to key labels and status indicators you'll want to assert against.
- Do NOT remove or rename any existing accessibility identifiers — other tests or accessibility features may depend on them.
- Commit these changes separately with a message like: `chore: add accessibility identifiers for UI testing`

## Step 4: Write the Tests

Create test files organized by feature area. Each test file should be a subclass of `XCTestCase`.

### Test file structure:

```swift
import XCTest

final class <FeatureName>Tests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func test<DescriptiveActionName>() throws {
        // Arrange — navigate to the right state
        // Act — perform the user action
        // Assert — verify the expected outcome
    }
}
```

### What to test for each feature:

- **Happy path**: The feature works with valid input as expected.
- **Empty / missing input**: What happens when required fields are blank?
- **Edge cases**: Very long strings, special characters, rapid repeated clicks.
- **State transitions**: Does the UI update correctly? Do loading indicators appear and disappear?
- **Error states**: If the feature can fail (e.g., network error, invalid file), does the app show an appropriate error and remain usable?
- **Navigation**: Can the user get to and back from every screen/sheet/popover?
- **Window management**: Does the app handle window resizing, multiple windows (if applicable)?
- **Menu bar items**: Test any custom menu actions the app registers.

### Naming convention:

Use descriptive test names: `testGenerateButton_WithValidPrompt_ProducesOutput()`, `testSettingsWindow_ChangingModel_PersistsAfterRestart()`

### Common XCUITest patterns:

```swift
// Tap a button
app.buttons["generateButton"].tap()

// Type into a text field
let field = app.textFields["promptTextField"]
field.tap()
field.typeText("a beautiful sunset")

// Wait for an element to appear (important for async operations)
let output = app.images["outputImage"]
let exists = output.waitForExistence(timeout: 30)
XCTAssertTrue(exists, "Output image should appear within 30 seconds")

// Check a label's value
XCTAssertEqual(app.staticTexts["statusLabel"].label, "Complete")

// Verify an element is disabled
XCTAssertFalse(app.buttons["generateButton"].isEnabled)

// Work with popovers/sheets
app.buttons["settingsButton"].tap()
let sheet = app.sheets.firstMatch
XCTAssertTrue(sheet.waitForExistence(timeout: 5))

// Work with menus (macOS)
app.menuBarItems["File"].click()
app.menuItems["Export..."].click()

// Work with dropdowns/popUpButtons
app.popUpButtons["modelPicker"].click()
app.menuItems["ModelName"].click()
```

## Step 5: Run the Tests

Run the full test suite:

```bash
xcodebuild test \
    -scheme <AppName> \
    -destination 'platform=macOS' \
    -only-testing:<AppName>UITests \
    2>&1 | tail -50
```

If `xcodebuild` output is too noisy, you can also use `xcpretty` if available:

```bash
xcodebuild test \
    -scheme <AppName> \
    -destination 'platform=macOS' \
    -only-testing:<AppName>UITests \
    2>&1 | xcpretty
```

## Step 6: Triage and Fix

For each failing test:

1. Determine whether the failure is a **test issue** (wrong identifier, bad timing, flaky assertion) or an **app bug** (the feature genuinely doesn't work).
2. For test issues: fix the test and re-run.
3. For app bugs: report them to me with:
   - Which test failed
   - What was expected vs. what happened
   - The relevant source code location if identifiable
   - Suggested fix (if obvious)

**Do NOT silently skip or delete failing tests.** Every failure must be explained.

## Step 7: Summary Report

After all tests pass (or all failures are triaged), provide a summary:

- **Total tests**: N
- **Passed**: N
- **Failed**: N (with reasons)
- **Skipped**: N (with reasons)
- **Features with full coverage**: list
- **Features with partial coverage**: list + what's missing
- **Features with no coverage**: list + why (e.g., "requires network", "requires user credential")
- **Accessibility identifiers added**: list of files modified
- **App bugs discovered**: list with severity

## Guidelines

- Prefer **multiple focused tests** over one giant test. Each test should verify one behavior.
- Use `waitForExistence(timeout:)` generously — macOS UI can be slow, especially for first launch.
- If a feature requires external dependencies (network APIs, hardware, file system access), note it as **not testable via XCUITest** and suggest an alternative approach (mocking, unit test, manual verification).
- Keep tests independent — no test should depend on another test having run first.
- If adding identifiers or tests requires changes to the app's code, make those changes in a **separate commit** from any bug fixes.
- Run the full test suite at least twice to check for flaky tests before reporting results.
