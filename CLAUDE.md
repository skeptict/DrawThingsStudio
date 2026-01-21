# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DrawThingsStudio is a macOS native application (Swift/SwiftUI) that serves as a visual workflow builder for AI image generation. It generates StoryFlow-compatible JSON instruction files that can be executed in Draw Things.

**Platform:** macOS 14.0+
**Architecture:** SwiftUI + SwiftData + MVVM
**Current State:** Fully functional for workflow creation and LLM-assisted prompt enhancement

## Build Commands

```bash
# Build the project (requires Xcode)
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Debug build

# Build for release
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Release build
```

Open in Xcode for development: `open DrawThingsStudio.xcodeproj`

## Current Features (Working)

### Workflow Builder
- Visual instruction list with drag-and-drop reordering
- Inline editors for all instruction types (50+ types)
- JSON preview and export
- Copy to clipboard for pasting into Draw Things
- Import/export workflow JSON files
- Save workflows to library (SwiftData)

### Config Presets
- Import model configs from Draw Things JSON exports
- Searchable preset picker with type-to-filter
- Presets stored in SwiftData

### LLM Integration
- **Providers:** Ollama (port 11434), LM Studio (port 1234), Jan (port 1337)
- **Prompt Enhancement:** "Enhance" button with style picker (Creative, Artistic, Photorealistic, etc.)
- **Editable Styles:** Styles loaded from `~/Library/Application Support/DrawThingsStudio/enhance_styles.json`
- **Provider Selection:** Settings → LLM Provider (persisted in UserDefaults)

### Key Files Modified in Recent Sessions
| File | Changes |
|------|---------|
| `WorkflowBuilderView.swift` | Searchable config preset picker, Enhance button with style picker |
| `WorkflowBuilderViewModel.swift` | Fixed LLM provider selection (was hardcoded to Ollama) |
| `LLMProvider.swift` | Added `PromptStyleManager` for editable enhancement styles |
| `OllamaClient.swift` | Added error handling for empty responses (vision model hint) |
| `AppSettings.swift` | LLM provider settings, createLLMClient() factory |

## Architecture

### Core Components

| Component | File | Purpose |
|-----------|------|---------|
| App Entry | `DrawThingsStudioApp.swift` | SwiftData container, keyboard shortcuts, menu commands |
| Main Navigation | `ContentView.swift` | NavigationSplitView with sidebar (Create/Library/Settings) |
| Workflow Builder UI | `WorkflowBuilderView.swift` | Instruction list, inline editors, JSON preview |
| Workflow State | `WorkflowBuilderViewModel.swift` | Instructions array, selection, file I/O, validation |
| LLM Integration | `AIGenerationView.swift` | Provider connection UI, prompt generation |
| Settings | `AppSettings.swift` | UserDefaults-backed settings + SettingsView |

### Data Flow

```
User creates instructions in WorkflowBuilderView
    ↓
WorkflowBuilderViewModel manages state
    ↓
StoryflowInstructionGenerator converts to JSON
    ↓
StoryflowExporter outputs final JSON
    ↓
User copies to Draw Things' StoryflowPipeline.js
```

### LLM Provider Abstraction

`LLMProvider` protocol with implementations:
- `OllamaClient` - Ollama HTTP API (port 11434)
- `OpenAICompatibleClient` - LM Studio (port 1234), Jan (port 1337)

**Important:** When enhancing prompts, `WorkflowBuilderViewModel.enhancePrompt()` uses `AppSettings.shared.createLLMClient()` to get the currently selected provider.

### Persistence

- **SwiftData Models:** `SavedWorkflow`, `ModelConfig` (in `DataModels.swift`)
- **User Settings:** `AppSettings.swift` (UserDefaults-backed)
- **Config Presets:** `ConfigPresetsManager.swift` (JSON file import/export)
- **Enhancement Styles:** `~/Library/Application Support/DrawThingsStudio/enhance_styles.json`

### Instruction System

`WorkflowInstruction` wraps `InstructionType` enum with 50+ cases covering:
- Flow control: `note`, `loop`, `loopEnd`, `end`
- Prompts: `prompt`, `negativePrompt`, `config`
- Canvas: `canvasClear`, `canvasLoad`, `canvasSave`, `moveScale`, `crop`
- Moodboard: `moodboardClear`, `moodboardAdd`, `moodboardWeights`
- Advanced: `depthExtract`, `faceZoom`, `removeBackground`, `inpaintTools`

## Key Patterns

- **@MainActor ViewModels** - Thread-safe UI state management
- **@Query macros** - SwiftData queries in views
- **Focused values** - Keyboard shortcut coordination between views
- **Protocol-based LLM** - Swappable providers without UI changes
- **Singleton settings** - `AppSettings.shared` for global access

## File Organization

```
DrawThingsStudio/           # Main app target
├── *App.swift              # Entry point
├── ContentView.swift       # Navigation
├── WorkflowBuilder*.swift  # Core builder (View + ViewModel)
├── AIGeneration*.swift     # LLM integration
├── Storyflow*.swift        # JSON export pipeline
├── *Client.swift           # HTTP clients (Ollama, OpenAI-compatible)
├── ConfigPresetsManager    # Model config management
├── DataModels.swift        # SwiftData models
├── AppSettings.swift       # Preferences + SettingsView
└── LLMProvider.swift       # Protocol + PromptStyleManager

Sources/StoryFlow/          # Modular library (SPM) - currently unused
Protos/                     # gRPC proto files (not yet integrated)
```

## Adding New Instructions

1. Add case to `InstructionType` enum in `WorkflowInstruction.swift`
2. Add editor component in `WorkflowBuilderView.swift`
3. Add JSON generation in `StoryflowInstructionGenerator.swift`
4. Update validation in `StoryflowValidator.swift` if needed

## Adding New LLM Providers

1. Create new class conforming to `LLMProvider` protocol
2. Implement required methods: `generateText`, `listModels`, `checkConnection`
3. Add case to `LLMProviderType` enum in `LLMProvider.swift`
4. Update provider selection UI in `AppSettings.swift`

---

## Failed Attempt: gRPC Connectivity to Draw Things

### Goal
Send prompts directly to Draw Things via gRPC instead of copy/paste.

### What Was Tried
1. Added grpc-swift 2.x packages → Required macOS 15+ (project targets 14+)
2. Switched to grpc-swift 1.x (version 1.23.1) → Generated code with protoc
3. Proto file source: `https://github.com/drawthingsai/draw-things-community/blob/main/Libraries/GRPC/Models/Sources/imageService/imageService.proto`

### Why It Failed
- **Swift 6 Strict Concurrency:** Generated protobuf code has `_MessageImplementationBase` conformance errors
- **Version Mismatches:** protoc-gen-swift version vs SwiftProtobuf library version conflicts
- **Complex Dependencies:** grpc-swift brings NIO, NIOConcurrencyHelpers, etc. with MainActor isolation issues

### Files Created (Now Removed)
- `DrawThingsStudio/DrawThingsClient.swift` - gRPC client wrapper
- `DrawThingsStudio/Generated/imageService.pb.swift` - Protobuf messages
- `DrawThingsStudio/Generated/imageService.grpc.swift` - gRPC stubs
- `Protos/imageService.proto` - Service definition

### To Retry gRPC Later
1. Wait for grpc-swift to have better Swift 6 support
2. Or try Draw Things HTTP API if available (default port 7860)
3. Or lower Swift language version in build settings (not recommended)

### Draw Things gRPC Details
- **Default Port:** 7860
- **Service:** `ImageGenerationService`
- **Key RPCs:** `Echo` (connection test), `GenerateImage` (streaming response)
- **Proto location:** See URL above

---

## Known Issues & Notes

### Vision Models Return Empty
If using a vision-language model (e.g., `qwen3-vl`) for text-only prompt enhancement, it returns empty. The app now shows: "Model returned empty response. If using a vision model (VL), try a text-only model instead."

### Enhancement Style "Edit Styles"
Opens the JSON file in the default editor (BBEdit, TextEdit, etc.). User can add custom styles following the format in the file.

### Config Preset Model Field
Fixed: Selecting a preset now populates the Model field via `editModel = preset.modelName` in `loadFromPreset()`.

---

## Next Steps (Suggested)

1. **Draw Things Connectivity (Alternative):** Research if Draw Things has an HTTP API as fallback to gRPC
2. **Batch Operations:** Add ability to run multiple prompts in sequence
3. **Template System:** Expand workflow templates
4. **Image Preview:** Show generated images inline (requires DT connectivity)

---

## Session History Summary

### Session 1 (Previous)
- Fixed config preset model field population
- Added searchable config preset dropdown
- Fixed LLM provider selection (was hardcoded to Ollama)
- Added editable enhancement styles with PromptStyleManager
- Added empty response handling for vision models
- Created README.md

### Session 2 (Current - Jan 21, 2026)
- Attempted gRPC setup for Draw Things connectivity
- Created proto files, generated Swift code
- Hit Swift 6 concurrency issues with protobuf generated code
- Reverted to last working commit (efbb52a)
- Updated this CLAUDE.md with comprehensive project state
