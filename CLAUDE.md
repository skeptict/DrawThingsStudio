# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DrawThingsStudio is a macOS native application (Swift/SwiftUI) that serves as a visual workflow builder for AI image generation. It generates StoryFlow-compatible JSON instruction files that can be executed in Draw Things.

**Platform:** macOS 14.0+
**Architecture:** SwiftUI + SwiftData + MVVM
**Current State:** Fully functional with HTTP and gRPC connectivity to Draw Things, workflow creation, and LLM-assisted prompt enhancement

## Build Commands

```bash
# Build the project (requires Xcode)
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Debug build

# Build for release
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Release build
```

Open in Xcode for development: `open DrawThingsStudio.xcodeproj`

## Current Features (Working)

### Draw Things Connectivity
- **Dual Transport:** HTTP (port 7860) and gRPC (port 7859)
- **gRPC Client:** Uses [DT-gRPC-Swift-Client](https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client) library
- **Image Generation:** Send prompts directly to Draw Things and receive generated images
- **Full Configuration:** All generation parameters (dimensions, steps, guidance, sampler, seed, model, shift, strength, LoRAs)
- **Image Gallery:** View, manage, and auto-save generated images with metadata

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
| `DrawThingsGRPCClient.swift` | **NEW** - gRPC client implementing DrawThingsProvider |
| `DrawThingsHTTPClient.swift` | HTTP client for Draw Things API |
| `DrawThingsProvider.swift` | Protocol + shared types for Draw Things connectivity |
| `ImageGenerationView.swift` | Neumorphic UI for image generation |
| `ImageGenerationViewModel.swift` | State management for generation |
| `ImageStorageManager.swift` | Auto-save generated images with metadata |
| `AppSettings.swift` | Draw Things settings, createDrawThingsClient() factory |
| `NeumorphicStyle.swift` | **NEW** - Design system (colors, modifiers, components) |
| `ContentView.swift` | Neumorphic sidebar styling |
| `WorkflowBuilderView.swift` | Neumorphic styling, searchable preset picker |

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

## Draw Things Connectivity

### Transport Options
| Transport | Port | Library | Features |
|-----------|------|---------|----------|
| HTTP | 7860 | URLSession | Simple, works with shared secret auth |
| gRPC | 7859 | DT-gRPC-Swift-Client | TLS, binary tensors, streaming |

### gRPC Implementation (Working)
Uses [DT-gRPC-Swift-Client](https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client) v1.2.2:
- **Dependencies:** grpc-swift 1.27.1, swift-protobuf 1.33.3, flatbuffers 25.9.23
- **TLS:** Enabled by default, handles Draw Things self-signed certs
- **Tensor Decoding:** DTTensor format with Float16 RGB data
- **Samplers:** 19 sampler types mapped from string names

### Key Files
| File | Purpose |
|------|---------|
| `DrawThingsProvider.swift` | Protocol + shared types (DrawThingsGenerationConfig, GenerationProgress) |
| `DrawThingsHTTPClient.swift` | HTTP implementation using URLSession |
| `DrawThingsGRPCClient.swift` | gRPC wrapper around DrawThingsClient |
| `ImageStorageManager.swift` | Saves images to ~/Library/Application Support/DrawThingsStudio/GeneratedImages/ |

### Configuration Mapping
```swift
DrawThingsGenerationConfig → DrawThingsConfiguration (gRPC)
- width/height → Int32
- sampler (string) → SamplerType enum
- loras → [LoRAConfig]
- seedMode → Int32 (0=Legacy, 1=TorchCPU, 2=ScaleAlike, 3=NvidiaTorch)
```

---

## Known Issues & Notes

### Vision Models Return Empty
If using a vision-language model (e.g., `qwen3-vl`) for text-only prompt enhancement, it returns empty. The app now shows: "Model returned empty response. If using a vision model (VL), try a text-only model instead."

### Enhancement Style "Edit Styles"
Opens the JSON file in the default editor (BBEdit, TextEdit, etc.). User can add custom styles following the format in the file.

### Config Preset Model Field
Fixed: Selecting a preset now populates the Model field via `editModel = preset.modelName` in `loadFromPreset()`.

---

## Next Steps (Roadmap)

### Phase 2: Intelligent Image Analysis
1. **Image Evaluation via LLM** - Connect vision-capable LLMs (LLaVA, Qwen-VL) via Ollama for quality assessment
2. **Image Metadata Reading** - Extract generation metadata from images (Draw Things, A1111, ComfyUI formats)

### Phase 1 Remaining
3. **Direct StoryFlow Execution** - Send StoryFlow commands directly to Draw Things without scripts

### Phase 3+
4. **Conditional Logic** - If/else branching based on image analysis
5. **Batch Processing** - Queue multiple workflows, parameter sweeps
6. **Shortcuts Integration** - Expose workflows to macOS Shortcuts

---

## Session History Summary

### Session 1
- Fixed config preset model field population
- Added searchable config preset dropdown
- Fixed LLM provider selection (was hardcoded to Ollama)
- Added editable enhancement styles with PromptStyleManager
- Added empty response handling for vision models
- Created README.md

### Session 2 (Jan 21, 2026)
- Attempted manual gRPC setup - hit Swift 6 concurrency issues
- Reverted to last working commit

### Session 3 (Jan 24-26, 2026)
- Implemented HTTP connectivity to Draw Things (port 7860)
- Created DrawThingsHTTPClient, ImageStorageManager, ImageGenerationView/ViewModel
- Added Image Generation UI with gallery

### Session 4 (Jan 26, 2026)
- Applied neumorphic design system across entire app
- Created NeumorphicStyle.swift with colors, modifiers, components
- Updated all views with warm beige theme

### Session 5 (Jan 26, 2026) - Current
- **Successfully integrated gRPC** using DT-gRPC-Swift-Client library
- Added package dependency via SPM
- Created DrawThingsGRPCClient.swift wrapper
- Both HTTP and gRPC transports now working
- Updated README.md with comprehensive features and roadmap
