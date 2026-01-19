# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DrawThingsStudio is a macOS native application (Swift/SwiftUI) that serves as a visual workflow builder for AI image generation. It generates StoryFlow-compatible JSON instruction files that can be executed in Draw Things.

**Platform:** macOS 14.0+
**Architecture:** SwiftUI + SwiftData + MVVM

## Build Commands

```bash
# Build the project
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Debug build

# Build for release
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Release build
```

Open in Xcode for development: `open DrawThingsStudio.xcodeproj`

## Architecture

### Core Components

| Component | File | Purpose |
|-----------|------|---------|
| App Entry | `DrawThingsStudioApp.swift` | SwiftData container, keyboard shortcuts, menu commands |
| Main Navigation | `ContentView.swift` | NavigationSplitView with sidebar (Create/Library/Settings) |
| Workflow Builder UI | `WorkflowBuilderView.swift` | Instruction list, inline editors, JSON preview |
| Workflow State | `WorkflowBuilderViewModel.swift` | Instructions array, selection, file I/O, validation |
| LLM Integration | `AIGenerationView.swift` | Provider connection UI, prompt generation |

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

### Persistence

- **SwiftData Models:** `SavedWorkflow`, `ModelConfig` (in `DataModels.swift`)
- **User Settings:** `AppSettings.swift` (UserDefaults-backed)
- **Config Presets:** `ConfigPresetsManager.swift` (JSON file import/export)

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
└── AppSettings.swift       # Preferences

Sources/StoryFlow/          # Modular library (SPM)
├── Instructions.swift      # Core instruction types
└── InstructionGenerator.swift
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
