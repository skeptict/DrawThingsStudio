# DrawThingsStudio Code Audit Report

**Last Run:** 2026-03-09T17:16:25Z
**App Version:** 0.4.25
**Scope:** Targeted — DescribeAgentsManager.swift, DescribeAgentEditorView.swift, ImageDescriptionView.swift, LLMProvider.swift (describeImage), OllamaClient.swift (describeImage), OpenAICompatibleClient.swift (describeImage), AppSettings.swift (describeImageSendTarget), ImageInspectorView.swift (Describe button), ImageGenerationView.swift (Describe button), DTProjectBrowserView.swift (Describe buttons)
**Auditor:** Claude code-quality-auditor agent

---

## Summary
- Critical Security Issues: 0
- High Priority: 2
- Medium Priority: 4
- Low Priority / Style: 3

---

## Findings

### [HIGH-1] Sheet attaches to `galleryPanel` computed var, image captured lazily — `ImageGenerationView.swift` (~line 1167)

**Category:** Best Practice / SwiftUI
**Severity:** High

**Explanation:**
`showDescribeSheet` is declared on `ImageGenerationView` (line 28), and the `.sheet(isPresented: $showDescribeSheet)` modifier is attached to the `galleryPanel` computed property. Inside the sheet closure, it reads `viewModel.selectedImage?.image` at the time the sheet actually opens — not at the moment the "Describe..." button was tapped. The button lives inside `imageDetailView(_ generatedImage:)`, which receives a specific `generatedImage` value, but the sheet ignores that parameter and re-reads from `viewModel.selectedImage`.

If `viewModel.selectedImage` is nil or changes between the button tap and the sheet's SwiftUI layout pass (e.g., user clicks a different thumbnail during an animation frame), the `if let image` guard fails and the sheet presents as a blank panel with no error. This is a silent failure mode.

The `DTDetailPanel` and `DTClipDetailPanel` private structs both own their own `showDescribeSheet` state and correctly capture their `entry`/`clip` values at struct-init time, so those are fine. The Inspector's sheet is also fine because `viewModel.selectedImage` is only changed synchronously by user action in the history list. The `galleryPanel` case is the problematic one.

**Current Code:**
```swift
// galleryPanel:
.sheet(isPresented: $showDescribeSheet) {
    if let image = viewModel.selectedImage?.image {  // read at sheet-open time
        ImageDescriptionView(
            image: image,
            onSendToGeneratePrompt: { text in viewModel.prompt = text },
            onSendToWorkflowPrompt: nil
        )
    }
    // if selectedImage changed, this branch is empty — sheet shows blank
}

// Deep inside imageDetailView(_ generatedImage: GeneratedImage):
Button("Describe...") { showDescribeSheet = true }
// generatedImage.image is available here but not captured
```

**Improved Code:**
```swift
// Add alongside showDescribeSheet:
@State private var imageToDescribe: NSImage? = nil

// Inside imageDetailView(_ generatedImage: GeneratedImage):
Button("Describe...") {
    imageToDescribe = generatedImage.image  // capture now
    showDescribeSheet = true
}

// Sheet (at galleryPanel root or body):
.sheet(isPresented: $showDescribeSheet) {
    if let image = imageToDescribe {
        ImageDescriptionView(
            image: image,
            onSendToGeneratePrompt: { text in viewModel.prompt = text },
            onSendToWorkflowPrompt: nil
        )
    }
}
```

---

### [HIGH-2] Ollama `describeImage` sends no `options` — unbounded token output for vision requests — `OllamaClient.swift:223-232`

**Category:** API Correctness / Reliability
**Severity:** High

**Explanation:**
The `describeImage` body omits the `options` dict that all other `OllamaClient` requests include (temperature, top_p, num_predict). Without `num_predict`, Ollama uses its server-level default, which is typically unlimited or very large. For vision models describing complex images, this can produce extremely verbose output and cause the 120-second `timeoutIntervalForRequest` to be hit, surfacing as a generic connection error to the user.

The `generateText` path sets `num_predict: options.maxTokens` (typically 500). Vision description outputs are usually shorter than full text generation, so 800 tokens is a reasonable cap that prevents runaway responses while not truncating useful descriptions.

**Current Code:**
```swift
let body: [String: Any] = [
    "model": model,
    "messages": [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": userMessage, "images": [base64Image]]
    ],
    "stream": false
    // no options — server default max tokens applies (often unbounded)
]
```

**Improved Code:**
```swift
let body: [String: Any] = [
    "model": model,
    "messages": [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": userMessage, "images": [base64Image]]
    ],
    "stream": false,
    "options": [
        "num_predict": 800
    ]
]
```

---

### [MEDIUM-1] `DescribeAgentsManager.saveAgents()` filter never persists icon changes to built-ins — `DescribeAgentsManager.swift:172-182`

**Category:** Logic Error
**Severity:** Medium

**Explanation:**
The `saveAgents()` filter compares five fields to detect whether a modified built-in differs from its default and should be saved: `systemPrompt`, `name`, `userMessage`, `preferredVisionModel`, `targetModel`. The `icon` field is absent from the comparison. If a user changes only the icon of a built-in agent (e.g., from "eye" to "camera") and saves, the filter considers it unchanged and excludes it from the JSON file. On next launch, `loadAgentsSync` finds no persisted override and restores the default icon, silently discarding the user's change.

The same comparison is used in `isBuiltInModified(id:)` — fixing both in concert will make the "Reset to Default" button visibility and the save filter consistent.

**Current Code:**
```swift
// saveAgents:
return agent.systemPrompt != builtIn.systemPrompt
    || agent.name != builtIn.name
    || agent.userMessage != builtIn.userMessage
    || agent.preferredVisionModel != builtIn.preferredVisionModel
    || agent.targetModel != builtIn.targetModel
    // agent.icon missing

// isBuiltInModified:
return current.systemPrompt != d.systemPrompt
    || current.name != d.name
    || current.userMessage != d.userMessage
    || current.preferredVisionModel != d.preferredVisionModel
    // current.icon missing
```

**Improved Code:**
```swift
// saveAgents — add icon:
return agent.systemPrompt != builtIn.systemPrompt
    || agent.name != builtIn.name
    || agent.userMessage != builtIn.userMessage
    || agent.preferredVisionModel != builtIn.preferredVisionModel
    || agent.targetModel != builtIn.targetModel
    || agent.icon != builtIn.icon

// isBuiltInModified — add icon:
return current.systemPrompt != d.systemPrompt
    || current.name != d.name
    || current.userMessage != d.userMessage
    || current.preferredVisionModel != d.preferredVisionModel
    || current.targetModel != d.targetModel
    || current.icon != d.icon
```

---

### [MEDIUM-2] `DescribeAgentEditorView.agentRow` "modified" badge shows for unmodified built-ins after reset — `DescribeAgentEditorView.swift:119-131`

**Category:** Logic Error / UI
**Severity:** Medium

**Explanation:**
The badge logic checks `agent.isBuiltIn` first. After a user edits a built-in, `updateCurrentAgent` sets `agent.isBuiltIn = false`. After the user clicks "Reset to Default", `resetBuiltInAgent` restores the original content but leaves `isBuiltIn` as `false` (it assigns the default agent directly from `BuiltInDescribeAgent.agent`, whose `isBuiltIn` is `true` — so actually the reset does restore `isBuiltIn = true`). Let me state this precisely:

`BuiltInDescribeAgent.agent` returns agents with `isBuiltIn: true`. So `resetBuiltInAgent` writes back an agent with `isBuiltIn = true`, and the badge would correctly show "built-in" again after a reset. The badge logic is therefore correct in the reset path.

However, the edge case is: a custom agent whose `id` happens to collide with a built-in raw value string (e.g., a user somehow creates one named "general"). `BuiltInDescribeAgent(rawValue: agent.id) != nil` would return `true`, so it shows "modified" even though it's a fully custom agent. In practice this can only happen if a user manually edits the JSON file with a colliding ID — low probability but the logic is fragile.

The real improvement is: the "modified" label should call `agentsManager.isBuiltInModified(id:)` instead of relying solely on `agent.isBuiltIn`.

**Current Code:**
```swift
if agent.isBuiltIn {
    Text("built-in")
} else if BuiltInDescribeAgent(rawValue: agent.id) != nil {
    Text("modified")  // shows for any agent whose id matches a built-in raw value
} else {
    Text("custom")
}
```

**Improved Code:**
```swift
if agent.isBuiltIn {
    Text("built-in")
} else if BuiltInDescribeAgent(rawValue: agent.id) != nil {
    // Has a built-in ID but isBuiltIn==false; check if content actually differs
    Text(agentsManager.isBuiltInModified(id: agent.id) ? "modified" : "built-in")
} else {
    Text("custom")
}
```

---

### [MEDIUM-3] `OpenAICompatibleClient.OpenAIMessage.content` is non-optional — decoding throws on null content — `OpenAICompatibleClient.swift:422-425`

**Category:** JSON Decoding / Robustness
**Severity:** Medium

**Explanation:**
`OpenAIMessage` declares `content: String` as non-optional. The OpenAI chat completions spec allows `content` to be `null` when the assistant turn is a tool-call response. Some local servers (LM Studio, Jan) return HTTP 200 with `content: null` for refusals or multi-modal routing failures. When this happens, `JSONDecoder` throws at decode time, which is caught and surfaces as a generic `LLMError.invalidResponse`. That's not a crash, but the user message is unhelpful — they see "Invalid response from LLM" with no indication of why.

Since `describeImage` already has `guard let content = result.choices.first?.message.content else { throw LLMError.invalidResponse }`, making `content` optional costs nothing at the call sites and makes the decoding more spec-compliant.

**Current Code:**
```swift
private struct OpenAIMessage: Codable {
    let role: String
    let content: String   // throws decode error if JSON value is null
}
```

**Improved Code:**
```swift
private struct OpenAIMessage: Codable {
    let role: String
    let content: String?  // null-safe; callers already guard against nil
}
```

---

### [MEDIUM-4] `ImageDescriptionView.describe()` creates a new URLSession per tap — `ImageDescriptionView.swift:243`

**Category:** Performance
**Severity:** Medium

**Explanation:**
`AppSettings.shared.createLLMClient()` allocates a brand-new `OllamaClient` or `OpenAICompatibleClient`, each of which creates a new `URLSession` with its own TCP connection pool. This is the same pattern used by `WorkflowBuilderViewModel.enhancePrompt()` and is intentional there (one-shot text calls). For vision requests — which involve encoding a full JPEG image (typically 200-800 KB base64) — reusing a session is more beneficial because TLS + TCP connection establishment adds visible latency on first call.

Vision calls can take 5-30 seconds on consumer hardware. If the user clicks "Describe Image" twice quickly (e.g., to retry after a timeout), the first task's URLSession is already gone, and the second starts a fresh connection. Since `isDescribing` prevents double-tap, the practical impact is limited to the connection setup overhead on each individual call.

A low-friction fix is to cache the client for the lifetime of the sheet:

**Current Code:**
```swift
private func describe() {
    // ...
    let client = AppSettings.shared.createLLMClient()  // new URLSession each call
    // ...
}
```

**Improved Code:**
```swift
// As @State in ImageDescriptionView — persists for the sheet's lifetime:
@State private var llmClient: (any LLMProvider)?

private func describe() {
    guard let agent = agentsManager.agent(for: selectedAgentID) else { return }
    guard let imageData = image.jpegData(compressionQuality: 0.85) else {
        errorMessage = "Failed to encode image."
        return
    }

    // Reuse client if settings haven't changed; recreate only on first use
    let client = llmClient ?? AppSettings.shared.createLLMClient()
    llmClient = client
    // ... rest unchanged
}
```

---

### [LOW-1] `DescribeAgentsManager.saveAgents()` silently discards write errors — `DescribeAgentsManager.swift:189-191`

**Category:** Error Handling
**Severity:** Low

**Explanation:**
Both `try? encoder.encode(toSave)` and `try? data.write(to: agentsFilePath)` silently discard failures. The analogous `PromptStyleManager.saveStyles()` uses `do/catch` with `logger.error(...)`. Apply the same pattern here.

**Current Code:**
```swift
if let data = try? encoder.encode(toSave) {
    try? data.write(to: agentsFilePath)
}
```

**Improved Code:**
```swift
// Add to DescribeAgentsManager:
private let logger = Logger(subsystem: "com.drawthingsstudio", category: "describe-agents")

// In saveAgents():
do {
    let data = try encoder.encode(toSave)
    try data.write(to: agentsFilePath)
} catch {
    logger.error("Failed to save describe agents: \(error.localizedDescription)")
}
```

---

### [LOW-2] `describeImageSendTarget` compared and stored as raw strings — `ImageDescriptionView.swift:157-159`, `AppSettings.swift:137-138`

**Category:** Readability / Maintainability
**Severity:** Low

**Explanation:**
The strings `"generateImage"` and `"workflowBuilder"` appear as Picker tags in `ImageDescriptionView`, as Picker tags in `SettingsView`, as a comparison in `sendToTarget()`, and as a reset default in `AppSettings.resetToDefaults()`. A typo anywhere silently breaks routing. An enum with `rawValue` would eliminate this and match the project's `LLMProviderType`/`DrawThingsTransport` pattern.

**Current Code:**
```swift
// In multiple locations:
.tag("generateImage")
.tag("workflowBuilder")
if settings.describeImageSendTarget == "generateImage" { ... }
describeImageSendTarget = "generateImage"  // reset default
```

**Improved Code:**
```swift
// In AppSettings.swift or LLMProvider.swift:
enum DescribeSendTarget: String {
    case generateImage = "generateImage"
    case workflowBuilder = "workflowBuilder"
}
// @Published var describeImageSendTarget: String remains String for UserDefaults compatibility
// Comparisons use DescribeSendTarget(rawValue: settings.describeImageSendTarget) ?? .generateImage
```

---

### [LOW-3] `DescribeAgentEditorView` `@ObservedObject var agentsManager` — confirmed intentional pattern — `DescribeAgentEditorView.swift:11`

**Category:** Best Practice / SwiftUI (note only)
**Severity:** Low

**Explanation:**
This uses `@ObservedObject var agentsManager = DescribeAgentsManager.shared`, following the established project pattern for singleton-backed managers (not `@StateObject`). This is correct. Noted for completeness; no change needed.

---

## Applied Fixes
None — findings reported only. Awaiting authorization.

## Notes

**Security:**
No security issues found in this changeset. The vision API calls send image data only to locally configured LLM providers (Ollama, LM Studio, Jan) — all expected to be on localhost or local network, consistent with the existing HTTP connectivity model. No credentials are logged. Image data is not persisted beyond the session.

**API format correctness:**
- Ollama vision format (base64 in `images` array at message level, string `content`) is correct for llava/moondream/bakllava.
- OpenAI-compatible vision format (content array with `{"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}`) is correct for LM Studio and Jan's multimodal endpoints.

**Architecture:**
The agent system mirrors `PromptStyleManager` in structure and is well-designed. The sheet routing via optional closures in `ImageDescriptionView` is clean and avoids tight coupling. The nested sheet (`ImageDescriptionView` → `DescribeAgentEditorView`) works correctly on macOS 14+.

**DTProjectBrowserView — clips panel:**
`clip.frames[min(selectedFrameIndex, clip.frames.count - 1)].thumbnail` inside the sheet closure is safe because the button is `.disabled(clip.frames.first?.thumbnail == nil)` (ensuring frames is non-empty) and `clip` is a value-type struct captured at `DTClipDetailPanel` struct-init time.
