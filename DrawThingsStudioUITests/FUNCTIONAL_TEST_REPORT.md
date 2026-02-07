# DrawThingsStudio Functional Test Report

**Date:** 2026-02-07
**Tester:** Claude (automated via AppleScript)
**Draw Things:** Running with gRPC on port 7859

## Issues Found

### Issue #1: UI Tests Modify Real App Settings (CRITICAL)
**Severity:** High
**Location:** UI Tests / UserDefaults persistence

**Description:**
The UI test `testSettingsRetainedAfterNavigation` in `SettingsTests.swift` enters test values like `test-host-4556` into the Host field. These values persist in UserDefaults after the test completes, breaking the app's connection to Draw Things for subsequent use.

**Impact:**
- After running UI tests, the app cannot connect to Draw Things
- User must manually reset settings

**Recommendation:**
1. Use a separate test configuration/mock for UI tests
2. Reset settings to default values in `tearDownWithError()`
3. Consider using `XCUIApplication().launchArguments` to pass test-specific defaults

---

### Issue #2: Empty Model Field Causes Silent Generation Failure
**Severity:** Medium
**Location:** `ImageGenerationView.swift` / `ImageGenerationViewModel.swift`

**Description:**
When the Model field is empty and the user clicks Generate, the app starts generation but produces a static/noise image because no model is specified. There's no validation or error message.

**Expected Behavior:**
- Generate button should be disabled when model is empty, OR
- An error message should appear explaining a model is required

**Actual Behavior:**
- Generation proceeds with empty model
- Result is garbage/static image

---

### Issue #3: Generated Images Folder Not Created
**Severity:** Medium
**Location:** `ImageStorageManager.swift`

**Description:**
The app's storage directory `~/Library/Application Support/DrawThingsStudio/GeneratedImages/` is never created. Images appear in the in-app gallery but may not persist to disk.

**Expected:**
- `ensureDirectoryExists()` should create the folder on first save

**Actual:**
- Folder doesn't exist after multiple generations

**To Investigate:**
- Check if `saveImage()` is being called
- Check for permission issues
- Verify the logger output

---

### Issue #4: gRPC Model/LoRA Fetching Returns Empty (Known Issue)
**Severity:** Low (has workaround)
**Location:** `DrawThingsGRPCClient.swift`

**Description:**
The connection shows "Connected via gRPC - 0 models, 0 LoRAs" even when Draw Things has models loaded. The manual entry field works as a workaround.

**Status:** Known issue from previous sessions. The `EchoReply` from Draw Things doesn't expose model names in a parseable format.

---

### Issue #5: Keyboard Input Sometimes Fails in Text Fields
**Severity:** Low
**Location:** SwiftUI text fields

**Description:**
During AppleScript testing, `keystroke` commands sometimes failed to enter text in text fields. Using `set value of` worked reliably instead.

**This may indicate:**
- Focus issues with text fields
- First responder not being set correctly

---

## Successful Functionality

✅ **gRPC Connection** - Successfully connects to Draw Things at 127.0.0.1:7859
✅ **Image Generation** - Successfully generates images when model is specified manually
✅ **Gallery Display** - Generated images appear in the gallery with thumbnails
✅ **Navigation** - All sidebar navigation works correctly
✅ **Settings Persistence** - Settings save to UserDefaults (but see Issue #1)

## Test Environment

- macOS 26.2 (arm64)
- Draw Things running with gRPC enabled on port 7859
- Model: flux1-schnell-q8p.ckpt
- Transport: gRPC

## Recommendations

1. **Add model validation before generation** - Don't allow generation with empty model field
2. **Fix image persistence** - Ensure `ImageStorageManager` creates directory and saves images
3. **Reset test settings** - Add cleanup in UI test teardown
4. **Add error states** - Show clear error messages when generation fails
5. **Consider connection test on launch** - Auto-check connection when app starts
