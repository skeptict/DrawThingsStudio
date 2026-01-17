//
//  DrawThingsStudioApp.swift
//  DrawThingsStudio
//
//  Created by skeptict on 1/14/26.
//

import SwiftUI
import SwiftData

// MARK: - Focused Values

struct FocusedWorkflowKey: FocusedValueKey {
    typealias Value = WorkflowBuilderViewModel
}

extension FocusedValues {
    var workflowViewModel: WorkflowBuilderViewModel? {
        get { self[FocusedWorkflowKey.self] }
        set { self[FocusedWorkflowKey.self] = newValue }
    }
}

// MARK: - App

@main
struct DrawThingsStudioApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedWorkflow.self,
            GeneratedImage.self,
            PromptTemplate.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            WorkflowCommands()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - Workflow Commands

struct WorkflowCommands: Commands {
    @FocusedValue(\.workflowViewModel) var viewModel

    var body: some Commands {
        // File menu
        CommandGroup(replacing: .newItem) {
            Button("New Workflow") {
                viewModel?.clearAllInstructions()
                viewModel?.workflowName = "Untitled Workflow"
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Workflow...") {
                Task {
                    await viewModel?.importWithOpenPanel()
                }
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Save Workflow...") {
                Task {
                    await viewModel?.exportWithSavePanel()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(viewModel?.instructions.isEmpty ?? true)
        }

        // Edit menu additions
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Delete Instruction") {
                viewModel?.deleteSelectedInstruction()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(viewModel?.hasSelection != true)

            Button("Duplicate Instruction") {
                viewModel?.duplicateSelectedInstruction()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(viewModel?.hasSelection != true)

            Divider()

            Button("Move Up") {
                viewModel?.moveSelectedUp()
            }
            .keyboardShortcut(.upArrow, modifiers: [.option, .command])
            .disabled(viewModel?.hasSelection != true)

            Button("Move Down") {
                viewModel?.moveSelectedDown()
            }
            .keyboardShortcut(.downArrow, modifiers: [.option, .command])
            .disabled(viewModel?.hasSelection != true)
        }

        // Workflow menu
        CommandMenu("Workflow") {
            Button("Validate") {
                _ = viewModel?.validate()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(viewModel?.instructions.isEmpty ?? true)

            Button("Copy JSON to Clipboard") {
                viewModel?.copyToClipboard()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(viewModel?.instructions.isEmpty ?? true)

            Divider()

            Menu("Add Instruction") {
                Button("Note") { viewModel?.addInstruction(.note("")) }
                Button("Prompt") { viewModel?.addInstruction(.prompt("")) }
                Button("Negative Prompt") { viewModel?.addInstruction(.negativePrompt("")) }
                Button("Config") { viewModel?.addInstruction(.config(DrawThingsConfig())) }

                Divider()

                Button("Loop") { viewModel?.addInstruction(.loop(count: 5, start: 0)) }
                Button("Loop End") { viewModel?.addInstruction(.loopEnd) }

                Divider()

                Button("Clear Canvas") { viewModel?.addInstruction(.canvasClear) }
                Button("Load Canvas") { viewModel?.addInstruction(.canvasLoad("")) }
                Button("Save Canvas") { viewModel?.addInstruction(.canvasSave("output.png")) }
            }

            Divider()

            Button("Clear All Instructions") {
                viewModel?.clearAllInstructions()
            }
            .disabled(viewModel?.instructions.isEmpty ?? true)
        }
    }
}
