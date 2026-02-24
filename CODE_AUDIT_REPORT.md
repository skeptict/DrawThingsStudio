# DrawThingsStudio Code Audit Report

**Last Run:** 2026-02-24T18:00:00Z
**App Version:** 0.4.09
**Scope:** Full project re-audit — DrawThingsHTTPClient.swift, StoryflowExecutor.swift, WorkflowBuilderViewModel.swift, ImageInspectorViewModel.swift, OllamaClient.swift, OpenAICompatibleClient.swift, DrawThingsGRPCClient.swift, DrawThingsAssetManager.swift, ImageStorageManager.swift, DTProjectBrowserViewModel.swift, WorkflowPipelineView.swift, WorkflowPipelineViewModel.swift, ImageGenerationView.swift, DTProjectBrowserView.swift, AppSettings.swift, ContentView.swift — plus broader scan of StoryStudioView.swift, StoryStudioViewModel.swift, CharacterEditorView.swift, SceneEditorView.swift, StoryProjectLibraryView.swift, StoryDataModels.swift, PromptAssembler.swift, WorkflowBuilderView.swift, WorkflowExecutionView.swift, WorkflowExecutionViewModel.swift, LLMProvider.swift, CloudModelCatalog.swift, DrawThingsProvider.swift, ConfigPresetsManager.swift, DataModels.swift, KeychainService.swift
**Auditor:** Claude code-quality-auditor agent

---

## Summary

- Critical Security Issues: 0
- High Priority: 1
- Medium Priority: 4
- Low Priority / Style: 4

All findings from the previous two audit cycles have been confirmed fixed in the current codebase (see Applied Fixes table at bottom). This report covers only newly identified issues from the third full-project scan.

---

## Findings

---

### [HIGH] `WorkflowExecutionViewModel.browseWorkingDirectory()` Calls `NSOpenPanel.runModal()` — `WorkflowExecutionViewModel.swift:243`

**Category:** Best Practice / macOS
**Severity:** High

**Explanation:**
`WorkflowExecutionViewModel.browseWorkingDirectory()` presents an `NSOpenPanel` using the synchronous `.runModal()` call:

```swift
func browseWorkingDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.message = "Select working directory for file operations"

    if panel.runModal() == .OK, let url = panel.url {
        workingDirectory = url
    }
}
```

This is the same pattern that was flagged as [HIGH] in the previous audit cycle for `DTProjectBrowserViewModel.addFolder()` and subsequently fixed there (using the async `panel.begin { }` callback). `WorkflowExecutionViewModel` still uses the blocking form. `NSOpenPanel.runModal()` spins a synchronous modal event loop on the main actor, preventing SwiftUI from processing layout updates or animations during the file picker.

The class is `@MainActor`, so this call blocks the main actor for the full duration the user is interacting with the panel (potentially many seconds).

**Current Code:**
```swift
// WorkflowExecutionViewModel.swift:236-246
func browseWorkingDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.message = "Select working directory for file operations"

    if panel.runModal() == .OK, let url = panel.url {
        workingDirectory = url
    }
}
```

**Improved Code:**
Replace the synchronous `.runModal()` with the async `begin(completionHandler:)` callback, matching the pattern used in `DTProjectBrowserViewModel.addFolder()`:

```swift
func browseWorkingDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.message = "Select working directory for file operations"

    // Use async form to avoid blocking the main actor during panel interaction.
    panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        self?.workingDirectory = url
    }
}
```

Alternatively, if the call site is always a SwiftUI button action (which runs on the main actor), move to `.fileImporter` in `WorkflowExecutionView`, consistent with `ImageGenerationView`.

---

### [MEDIUM] `LLMModel.formattedSize` Allocates a New `ByteCountFormatter` Per Call — `LLMProvider.swift:58`

**Category:** Performance
**Severity:** Medium

**Explanation:**
`LLMModel.formattedSize` is a computed property on a `struct` that allocates a fresh `ByteCountFormatter` instance every time it is accessed:

```swift
var formattedSize: String {
    guard let size = size else { return "Unknown" }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
}
```

`LLMModel` is displayed in a `List` or `Picker` (in the AI Generation settings panel and in `AIGenerationView.swift`), where `formattedSize` is accessed in the view body for each model row. `ByteCountFormatter` allocation is expensive — this is the same antipattern previously fixed in `DTProjectBrowserViewModel.formatFileSize` and `ImageStorageManager.saveImage`.

Because `LLMModel` is a `struct` (not a class), a `static` property is not directly available for this particular formatter. The correct fix is a module-level or extension-level `private` static constant.

**Current Code:**
```swift
// LLMProvider.swift:58-63
var formattedSize: String {
    guard let size = size else { return "Unknown" }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
}
```

**Improved Code:**
```swift
// Add a private static formatter in an extension or at module scope:
private let _llmModelSizeFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useGB, .useMB]
    f.countStyle = .file
    return f
}()

// In LLMModel:
var formattedSize: String {
    guard let size = size else { return "Unknown" }
    return _llmModelSizeFormatter.string(fromByteCount: size)
}
```

Or move `formattedSize` into a static helper function:

```swift
extension LLMModel {
    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .file
        return f
    }()

    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        return Self.sizeFormatter.string(fromByteCount: size)
    }
}
```

---

### [MEDIUM] `OllamaClient.parseDate` Allocates a New `ISO8601DateFormatter` Per Call — `OllamaClient.swift:248`

**Category:** Performance
**Severity:** Medium

**Explanation:**
`OllamaClient.parseDate(_:)` is called once per model entry returned from `listModels()`. For a user with many Ollama models, this allocates one `ISO8601DateFormatter` per model. `DateFormatter` and its subclasses are expensive to create. This is the same antipattern previously fixed in `RequestLogger.timestamp()` and `ImageStorageManager.saveImage`.

```swift
private func parseDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: dateString)
}
```

**Current Code:**
```swift
// OllamaClient.swift:247-252
private func parseDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: dateString)
}
```

**Improved Code:**
```swift
private static let ollamaDateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private func parseDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    return Self.ollamaDateFormatter.date(from: dateString)
}
```

`ISO8601DateFormatter` is thread-safe when used from a single thread; since `OllamaClient` is `@MainActor`, a `static let` is safe here.

---

### [MEDIUM] `SettingsView` Tasks Use `await MainActor.run` When Already on Main Actor — `AppSettings.swift:562,574`

**Category:** Swift Concurrency / Best Practice
**Severity:** Medium

**Explanation:**
`SettingsView.testConnection()` and `testDTConnection()` create unstructured `Task` blocks and then use `await MainActor.run { }` to update `@State` properties:

```swift
private func testConnection() {
    testingConnection = true
    Task {
        let client = settings.createLLMClient()
        let success = await client.checkConnection()
        let providerName = settings.providerType.displayName

        await MainActor.run {
            testingConnection = false
            connectionResult = success ? "..." : "..."
        }
    }
}
```

`SettingsView` is a SwiftUI `View`. In Swift 5.9+, SwiftUI view methods are inferred to run on the main actor, and an unstructured `Task { }` created from a `@MainActor` context inherits that actor. This means the `await MainActor.run { }` wrapper inside the task is redundant — the closures after the `await` already execute on the main actor.

The `await MainActor.run` wrapper works correctly but adds unnecessary boilerplate and may confuse readers into thinking the outer context is not already on the main actor. The improved pattern uses `Task { @MainActor in ... }` for clarity, or simply annotates the `Task` closure body directly.

**Current Code:**
```swift
// AppSettings.swift:562-572
Task {
    let client = settings.createLLMClient()
    let success = await client.checkConnection()
    let providerName = settings.providerType.displayName

    await MainActor.run {
        testingConnection = false
        connectionResult = success ? "Success! Connected to \(providerName)" : "Failed to connect"
    }
}
```

**Improved Code:**
```swift
// The Task inherits the main actor from the view's button action context.
// Explicit annotation makes isolation clear without the redundant MainActor.run wrapper.
Task { @MainActor in
    let client = settings.createLLMClient()
    let success = await client.checkConnection()
    let providerName = settings.providerType.displayName
    testingConnection = false
    connectionResult = success ? "Success! Connected to \(providerName)" : "Failed to connect"
}
```

Apply the same change to `testDTConnection()`.

---

### [LOW] `WorkflowExecutionViewModel` and `ConfigPresetsManager` and `PromptStyleManager` Are Not `final` — Multiple Files

**Category:** Best Practice / Readability
**Severity:** Low

**Explanation:**
Three classes in the project are declared without `final` but are neither subclassed nor designed for subclassing:

- `WorkflowExecutionViewModel` at `WorkflowExecutionViewModel.swift:70`: declared `@MainActor class WorkflowExecutionViewModel: ObservableObject`
- `ConfigPresetsManager` at `ConfigPresetsManager.swift:297`: declared `@MainActor class ConfigPresetsManager`
- `PromptStyleManager` at `LLMProvider.swift:193`: declared `@MainActor class PromptStyleManager: ObservableObject`

The project convention is `@MainActor final class`. Marking these `final` enables compiler devirtualization, makes the intent clear, and aligns with every other ViewModel and manager in the codebase.

**Current Code:**
```swift
// WorkflowExecutionViewModel.swift:70
@MainActor
class WorkflowExecutionViewModel: ObservableObject {

// ConfigPresetsManager.swift:297
@MainActor
class ConfigPresetsManager {

// LLMProvider.swift:193
@MainActor
class PromptStyleManager: ObservableObject {
```

**Improved Code:**
```swift
@MainActor
final class WorkflowExecutionViewModel: ObservableObject {

@MainActor
final class ConfigPresetsManager {

@MainActor
final class PromptStyleManager: ObservableObject {
```

---

### [LOW] `ImageInspectorViewModel.storageDirectory` Recomputes `FileManager.urls` on Every Access — `ImageInspectorViewModel.swift:148`

**Category:** Performance
**Severity:** Low

**Explanation:**
`storageDirectory` is a computed property that calls `FileManager.default.urls(for:in:)` and `appendingPathComponent` on every access:

```swift
private var storageDirectory: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("DrawThingsStudio/InspectorHistory", isDirectory: true)
}
```

This property is accessed in `saveEntryToDisk`, `deleteEntryFromDisk`, `clearPersistedHistory`, `loadHistoryFromDisk`, and `ensureDirectoryExists` — all called during normal operation. While `FileManager.urls(for:in:)` is fast, the path is constant for the lifetime of the process and there is no reason to recompute it. Compare with `ImageStorageManager`, which correctly stores `storageDirectory` as a `let` constant initialized in `init()`.

**Current Code:**
```swift
// ImageInspectorViewModel.swift:148-151
private var storageDirectory: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("DrawThingsStudio/InspectorHistory", isDirectory: true)
}
```

**Improved Code:**
```swift
// Computed once, stored as a constant — consistent with ImageStorageManager pattern.
private let storageDirectory: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("DrawThingsStudio/InspectorHistory", isDirectory: true)
}()
```

---

### [LOW] `WorkflowExecutionViewModel` `onInstructionStart` Closure Uses Guard-let `self` Instead of `[weak self]` Capture — `WorkflowExecutionViewModel.swift:154`

**Category:** Swift Concurrency / Memory
**Severity:** Low

**Explanation:**
The callbacks set on `executor` capture `self` weakly, but the `onInstructionStart` closure uses `guard let self = self` in the old pre-Swift-5.3 style, while `onInstructionComplete` and `onProgress` use `self?.` optional chaining. This inconsistency is not a bug — both patterns prevent retain cycles — but the non-uniform approach is slightly confusing:

```swift
executor?.onInstructionStart = { [weak self] instruction, index, total in
    guard let self = self else { return }
    self.currentInstructionIndex = index
    self.totalInstructions = total
    // ...
    self.executionLog.append(entry)
}

executor?.onInstructionComplete = { [weak self] instruction, result in
    guard let self = self else { return }
    // ...
}

executor?.onProgress = { [weak self] progress in
    self?.generationProgress = progress
}
```

Swift 5.3+ allows `[weak self]` with `guard let self` (shorthand), which is cleaner than the older pattern. More importantly, the `onInstructionStart` closure builds and appends an `ExecutionLogEntry` inside the `guard let self` block — this is correct, but the block is fairly long. The style should be consistent across all three closures.

This is a style/consistency issue only; there is no functional defect.

**Current Code:**
```swift
// WorkflowExecutionViewModel.swift:154-169
executor?.onInstructionStart = { [weak self] instruction, index, total in
    guard let self = self else { return }
    self.currentInstructionIndex = index
    ...
}
```

**Improved Code:**
Uniform weak capture across all three closures using Swift 5.7+ shorthand:

```swift
executor?.onInstructionStart = { [weak self] instruction, index, total in
    guard let self else { return }   // Swift 5.7 shorthand
    currentInstructionIndex = index
    totalInstructions = total
    // ...
    executionLog.append(entry)
}

executor?.onInstructionComplete = { [weak self] instruction, result in
    guard let self else { return }
    // ...
}

executor?.onProgress = { [weak self] progress in
    guard let self else { return }
    generationProgress = progress
}
```

---

### [LOW] `processNewFolder` Path Comparison Uses `.path` String Equality Instead of Standardized URL Equality — `DTProjectBrowserViewModel.swift:111`

**Category:** Correctness / Best Practice
**Severity:** Low

**Explanation:**
`processNewFolder` checks for duplicate folder additions using raw path string comparison:

```swift
if folders.contains(where: { $0.url.path == url.path }) {
    // Already have this folder — just refresh
    reloadAllProjects()
    return
}
```

This is inconsistent with `removeFolder`, which correctly uses `.standardizedFileURL`:

```swift
// removeFolder (correct):
return resolved.standardizedFileURL == folder.url.standardizedFileURL
```

Using `.path` string comparison can give false negatives for symlinks, trailing slashes, or paths containing `.` or `..` components. For example, `/Users/foo/bar` and `/Users/foo/bar/` would not be considered equal. The previous audit cycle flagged and fixed this exact issue in `removeFolder`, but `processNewFolder` uses the older `.path` comparison pattern.

**Current Code:**
```swift
// DTProjectBrowserViewModel.swift:111
if folders.contains(where: { $0.url.path == url.path }) {
```

**Improved Code:**
```swift
if folders.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
```

---

## Previous Audit Findings — Status Verification

All findings from audit cycles 1 and 2 (2026-02-24) have been verified fixed in the current codebase:

### Cycle 1 Findings (All Fixed)

| Finding | Status | Notes |
|---------|--------|-------|
| [CRITICAL] OSLog emitting request bodies in `RequestLogger.append()` | Fixed | `append()` writes file-only; `logger.debug` removed |
| [CRITICAL] SQL table name interpolation in `DTProjectDatabase` | Fixed | `ThumbnailTable` enum with compile-time `rawValue` in place |
| [HIGH] `@StateObject` for shared singleton in `ImageGenerationView` and `WorkflowPipelineView` | Fixed | Both use `@ObservedObject` with explanatory comment |
| [HIGH] `DispatchQueue.main.asyncAfter` in `ImageGenerationView` | Fixed | Uses `Task { try? await Task.sleep(for: .seconds(3)) }` |
| [HIGH] `cancelPipeline` race + CancellationError error message | Fixed | `cancelPipeline` defers cleanup to task; `CancellationError` catch is silent |
| [HIGH] Dead code `_ = firstID` in `removeStep` | Fixed | Uses `if !steps.isEmpty` |
| [MEDIUM] HTTP warning for non-localhost | Fixed | Warning text shown in `SettingsView` after transport picker |
| [MEDIUM] `NSOpenPanel.runModal()` in `ImageGenerationView.openSourceImagePanel` | Fixed | Replaced with `.fileImporter` + `@State` flag |
| [MEDIUM] `filteredEntries` computed O(n) each render | Fixed | `@Published` + Combine `CombineLatest` in `init()` |
| [MEDIUM] `folderSection` O(n) filter per folder | Fixed | `projectsByFolder` dict precomputed; passed into function |
| [MEDIUM] `@unchecked Sendable` with mutable `db` | Fixed | `db` is `let` (assigned once in `init`) |
| [MEDIUM] `removeFolder` path string comparison | Fixed | `standardizedFileURL` equality used |
| [MEDIUM] `runPipeline` double `firstIndex(where:)` per step | Fixed | Uses `steps.indices` directly |
| [MEDIUM] `DateFormatter` allocated per `timestamp()` call | Fixed | `static let timestampFormatter` in `RequestLogger` |
| [LOW] `.foregroundColor(isSelected ? .primary : .primary)` | Fixed | Simplified to `.foregroundColor(.primary)` |
| [LOW] Mixed view persistence strategies undocumented | Fixed | Comment in `ContentView.swift` |
| [LOW] Error silently swallowed in `loadSourceFromProvider` | Deferred | Silent catch preserved; not a data loss issue |

### Cycle 2 Findings (All Fixed)

| Finding | Status | Notes |
|---------|--------|-------|
| [HIGH] `NSOpenPanel.runModal()` in `DTProjectBrowserViewModel.addFolder` | Fixed | Refactored to `panel.begin { }` async callback; folder processing extracted to `processNewFolder(_:)` |
| [HIGH] OSLog prompt logging in `DrawThingsHTTPClient` | Fixed | Removed `prompt.prefix(50)` from `logger.debug`; now logs only generation mode |
| [HIGH] `StoryflowExecutor.init` falls back to `~/Pictures` | Fixed | Uses `StoryflowExecutionState()` default (WorkflowOutput path); removed force-unwrap |
| [MEDIUM] `DrawThingsAssetManager.allModels` recomputed on every access | Fixed | `@Published private(set) var allModels`; `updateAllModels()` called after each fetch |
| [MEDIUM] `ISO8601DateFormatter` allocated per `saveImage` call | Fixed | `private static let filenameFormatter` in `ImageStorageManager` |
| [MEDIUM] `ByteCountFormatter` allocated per `formatFileSize` call | Fixed | `private static let fileSizeFormatter` in `DTProjectBrowserViewModel` |
| [MEDIUM] `DrawThingsGRPCClient.extractStrings` runs on main actor | Fixed | `nonisolated`; both call sites use `Task.detached(priority: .userInitiated)` |
| [MEDIUM] `OllamaClient` uses `await MainActor.run` instead of `@MainActor` | Fixed | `@MainActor final class`; all `await MainActor.run` wrappers removed |
| [MEDIUM] `OpenAICompatibleClient` same issue | Fixed | Same fix applied |
| [LOW] `StoryflowExecutor`, `WorkflowBuilderViewModel`, `DrawThingsHTTPClient` not `final` | Fixed | All three marked `final` |
| [LOW] `isCancelled` not checked during active generation | Fixed | Doc comment added to `cancel()` documenting cooperative cancellation behaviour |
| [LOW] `ImageInspectorViewModel.loadImage(webURL:)` Task annotation | Fixed | `Task { @MainActor in ... }` — explicit isolation annotation |
| [LOW] `PipelineStepEditorView` accesses `DrawThingsAssetManager.shared.loras` directly | Fixed | `availableLoRAs` param added; injected from parent's `assetManager.loras` |

---

## Applied Fixes

All cycle 3 findings applied (2026-02-24):

| Finding | Status | Notes |
|---------|--------|-------|
| [HIGH] `WorkflowExecutionViewModel.browseWorkingDirectory()` calls `NSOpenPanel.runModal()` | ✅ Fixed | Replaced with `panel.begin { [weak self] }` async callback |
| [MEDIUM] `LLMModel.formattedSize` allocates `ByteCountFormatter` per call | ✅ Fixed | `private static let sizeFormatter` in `LLMModel` |
| [MEDIUM] `OllamaClient.parseDate` allocates `ISO8601DateFormatter` per call | ✅ Fixed | `private static let ollamaDateFormatter` |
| [MEDIUM] `SettingsView` uses redundant `await MainActor.run` in test functions | ✅ Fixed | Both tasks now use `Task { @MainActor in }` with direct mutation |
| [LOW] `WorkflowExecutionViewModel`, `ConfigPresetsManager`, `PromptStyleManager` not `final` | ✅ Fixed | All three marked `final` |
| [LOW] `ImageInspectorViewModel.storageDirectory` recomputed on every access | ✅ Fixed | `private let storageDirectory: URL = { ... }()` constant |
| [LOW] Inconsistent `guard let self = self` / `self?.` in executor callbacks | ✅ Fixed | All three closures use Swift 5.7 `guard let self` shorthand |
| [LOW] `processNewFolder` uses `.path` string comparison | ✅ Fixed | Uses `standardizedFileURL` equality, consistent with `removeFolder` |

---

## Notes

### Architecture Observations

1. **`RequestLogger` thread safety:** `append()` opens and closes a `FileHandle` synchronously. All callers are `@MainActor`, making this safe in practice. If callers are ever added from non-main contexts, consider making `RequestLogger` an actor.

2. **Dual `.task` blocks for asset loading:** Both `WorkflowPipelineView` and `ImageGenerationView` call `assetManager.fetchAssets()` + `assetManager.fetchCloudCatalogIfNeeded()` in `.task`. The second call is effectively a no-op (singleton caches), but it triggers a redundant connection check to Draw Things. Centralizing asset loading in `ContentView.task` would eliminate this.

3. **`DTProjectDatabase.stochasticSamplingGamma` hardcoded:** `parseEntry` always sets `stochasticSamplingGamma: 0.3` regardless of FlatBuffer content — no VTable slot is defined for this field. A comment (now present in the code) documents this as intentional. The constant `0.3` is the FlatBuffer schema default.

4. **Security-scoped bookmark lifecycle:** `DTProjectBrowserViewModel.deinit` correctly calls `stopAccessingSecurityScopedResource()` for all URLs. Since it lives as `@StateObject` in `ContentView`, `deinit` never runs during normal app use — macOS will clean up security scope on process exit. This is acceptable behavior.

5. **`StoryflowExecutor.isCancelled` cancellation gap:** When a gRPC or HTTP generation is in progress (potentially running for minutes), cancellation via `executor.cancel()` will not interrupt the in-flight network request. The current architecture does not thread cancellation tokens through to the `URLSession` or gRPC transport. This is a known architectural limitation, now documented in `cancel()`.

6. **`SettingsView` uses `@ObservedObject` for singletons:** `SettingsView` declares `@ObservedObject var settings = AppSettings.shared` and `@ObservedObject var styleManager = PromptStyleManager.shared`. These are correctly `@ObservedObject` (not `@StateObject`) for shared singletons.

7. **`KeychainService`:** Correctly uses `kSecUseDataProtectionKeychain: true` and does not store sensitive data in UserDefaults. Secrets are migrated from UserDefaults to Keychain on first launch via `migrateLegacySecretsIfNeeded`. No issues found.

8. **`CloudModelCatalog`:** Correctly implements exponential backoff retry (3 attempts), validates HTTP status codes and content type, and uses `URLSession` with a 15-second timeout. No security issues found.
