//
//  WorkflowBuilderViewModel.swift
//  DrawThingsStudio
//
//  ViewModel for the workflow builder interface
//

import SwiftUI
import Combine

/// ViewModel managing the workflow builder state
@MainActor
class WorkflowBuilderViewModel: ObservableObject {

    // MARK: - Published Properties

    /// List of instructions in the workflow
    @Published var instructions: [WorkflowInstruction] = []

    /// Currently selected instruction ID
    @Published var selectedInstructionID: UUID?

    /// Whether the workflow has unsaved changes
    @Published var hasUnsavedChanges: Bool = false

    /// Current workflow name
    @Published var workflowName: String = "Untitled Workflow"

    /// Error message to display
    @Published var errorMessage: String?

    /// Success message to display
    @Published var successMessage: String?

    // MARK: - Services

    private let generator = StoryflowInstructionGenerator()
    private let exporter = StoryflowExporter()

    // MARK: - Computed Properties

    /// Currently selected instruction
    var selectedInstruction: WorkflowInstruction? {
        guard let id = selectedInstructionID else { return nil }
        return instructions.first { $0.id == id }
    }

    /// Index of selected instruction
    var selectedIndex: Int? {
        guard let id = selectedInstructionID else { return nil }
        return instructions.firstIndex { $0.id == id }
    }

    /// Whether an instruction is selected
    var hasSelection: Bool {
        selectedInstructionID != nil
    }

    /// Total instruction count
    var instructionCount: Int {
        instructions.count
    }

    // MARK: - Instruction Management

    /// Add a new instruction at the end
    func addInstruction(_ type: InstructionType) {
        let instruction = WorkflowInstruction(type: type)
        instructions.append(instruction)
        selectedInstructionID = instruction.id
        hasUnsavedChanges = true
    }

    /// Insert instruction after current selection (or at end if none selected)
    func insertInstruction(_ type: InstructionType) {
        let instruction = WorkflowInstruction(type: type)

        if let index = selectedIndex {
            instructions.insert(instruction, at: index + 1)
        } else {
            instructions.append(instruction)
        }

        selectedInstructionID = instruction.id
        hasUnsavedChanges = true
    }

    /// Update the currently selected instruction
    func updateSelectedInstruction(type: InstructionType) {
        guard let index = selectedIndex else { return }
        instructions[index].type = type
        hasUnsavedChanges = true
    }

    /// Delete instruction at specified index set
    func deleteInstructions(at indexSet: IndexSet) {
        // Clear selection if deleted
        if let selectedIndex = selectedIndex, indexSet.contains(selectedIndex) {
            selectedInstructionID = nil
        }
        instructions.remove(atOffsets: indexSet)
        hasUnsavedChanges = true
    }

    /// Delete currently selected instruction
    func deleteSelectedInstruction() {
        guard let index = selectedIndex else { return }
        instructions.remove(at: index)

        // Select next instruction or previous if at end
        if !instructions.isEmpty {
            let newIndex = min(index, instructions.count - 1)
            selectedInstructionID = instructions[newIndex].id
        } else {
            selectedInstructionID = nil
        }
        hasUnsavedChanges = true
    }

    /// Move instructions within the list
    func moveInstructions(from source: IndexSet, to destination: Int) {
        instructions.move(fromOffsets: source, toOffset: destination)
        hasUnsavedChanges = true
    }

    /// Duplicate selected instruction
    func duplicateSelectedInstruction() {
        guard let instruction = selectedInstruction, let index = selectedIndex else { return }
        let duplicate = WorkflowInstruction(type: instruction.type)
        instructions.insert(duplicate, at: index + 1)
        selectedInstructionID = duplicate.id
        hasUnsavedChanges = true
    }

    /// Move selected instruction up
    func moveSelectedUp() {
        guard let index = selectedIndex, index > 0 else { return }
        instructions.swapAt(index, index - 1)
        hasUnsavedChanges = true
    }

    /// Move selected instruction down
    func moveSelectedDown() {
        guard let index = selectedIndex, index < instructions.count - 1 else { return }
        instructions.swapAt(index, index + 1)
        hasUnsavedChanges = true
    }

    /// Clear all instructions
    func clearAllInstructions() {
        instructions.removeAll()
        selectedInstructionID = nil
        hasUnsavedChanges = true
    }

    // MARK: - Selection

    /// Select instruction by ID
    func select(_ id: UUID?) {
        selectedInstructionID = id
    }

    /// Select next instruction
    func selectNext() {
        guard let index = selectedIndex else {
            if !instructions.isEmpty {
                selectedInstructionID = instructions[0].id
            }
            return
        }

        if index < instructions.count - 1 {
            selectedInstructionID = instructions[index + 1].id
        }
    }

    /// Select previous instruction
    func selectPrevious() {
        guard let index = selectedIndex else {
            if !instructions.isEmpty {
                selectedInstructionID = instructions.last?.id
            }
            return
        }

        if index > 0 {
            selectedInstructionID = instructions[index - 1].id
        }
    }

    // MARK: - Export

    /// Get instructions as dictionaries for export
    func getInstructionDicts() -> [[String: Any]] {
        instructions.map { $0.toInstructionDict() }
    }

    /// Export to JSON string
    func exportToJSON() throws -> String {
        try exporter.exportToJSON(instructions: getInstructionDicts())
    }

    /// Copy to clipboard
    func copyToClipboard() {
        do {
            try exporter.copyToClipboard(instructions: getInstructionDicts())
            successMessage = "Copied \(instructions.count) instructions to clipboard"
        } catch {
            errorMessage = "Failed to copy: \(error.localizedDescription)"
        }
    }

    /// Export to file
    func exportToFile(filename: String) async throws -> URL {
        try exporter.exportToFile(instructions: getInstructionDicts(), filename: filename)
    }

    /// Export with save panel
    func exportWithSavePanel() async {
        do {
            if let url = try await exporter.exportWithSavePanel(
                instructions: getInstructionDicts(),
                suggestedFilename: workflowName
            ) {
                successMessage = "Saved to \(url.lastPathComponent)"
                hasUnsavedChanges = false
            }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    // MARK: - Templates

    /// Load a simple story template
    func loadStoryTemplate(sceneCount: Int = 3) {
        clearAllInstructions()

        addInstruction(.note("Story sequence: \(sceneCount) scenes"))
        addInstruction(.config(DrawThingsConfig(
            width: 1024,
            height: 1024,
            steps: 30,
            guidanceScale: 7.5
        )))

        for i in 1...sceneCount {
            addInstruction(.prompt("Scene \(i) prompt goes here"))
            addInstruction(.canvasSave("scene_\(i).png"))
        }

        selectedInstructionID = instructions.first?.id
        workflowName = "Story Sequence"
    }

    /// Load a batch variation template
    func loadBatchVariationTemplate(count: Int = 5) {
        clearAllInstructions()

        addInstruction(.note("Batch variations: \(count) versions"))
        addInstruction(.config(DrawThingsConfig(
            width: 1024,
            height: 1024,
            steps: 25
        )))
        addInstruction(.prompt("Your prompt here"))
        addInstruction(.loop(count: count, start: 0))
        addInstruction(.loopSave("variation_"))
        addInstruction(.loopEnd)

        selectedInstructionID = instructions.first?.id
        workflowName = "Batch Variations"
    }

    /// Load a character consistency template
    func loadCharacterConsistencyTemplate() {
        clearAllInstructions()

        addInstruction(.note("Character consistency workflow"))
        addInstruction(.config(DrawThingsConfig(
            width: 768,
            height: 1024,
            steps: 30
        )))

        // Character reference
        addInstruction(.prompt("Character reference: detailed description here"))
        addInstruction(.canvasSave("character_ref.png"))

        // Moodboard setup
        addInstruction(.moodboardClear)
        addInstruction(.moodboardCanvas)
        addInstruction(.moodboardWeights([0: 1.0]))

        // Scenes
        addInstruction(.prompt("Character in scene 1"))
        addInstruction(.canvasSave("scene_1.png"))
        addInstruction(.prompt("Character in scene 2"))
        addInstruction(.canvasSave("scene_2.png"))

        selectedInstructionID = instructions.first?.id
        workflowName = "Character Consistency"
    }

    /// Load an img2img template
    func loadImg2ImgTemplate() {
        clearAllInstructions()

        addInstruction(.note("Img2Img workflow"))
        addInstruction(.config(DrawThingsConfig(
            width: 1024,
            height: 1024,
            steps: 30,
            strength: 0.7
        )))
        addInstruction(.canvasLoad("input.png"))
        addInstruction(.prompt("Enhancement prompt"))
        addInstruction(.canvasSave("output.png"))

        selectedInstructionID = instructions.first?.id
        workflowName = "Img2Img"
    }

    // MARK: - Validation

    /// Validate the current workflow
    func validate() -> ValidationResult {
        let validator = StoryflowValidator()
        return validator.validate(instructions: getInstructionDicts())
    }

    /// Check if workflow has any prompts
    var hasPrompts: Bool {
        instructions.contains { instruction in
            if case .prompt = instruction.type { return true }
            return false
        }
    }

    /// Check if workflow has config
    var hasConfig: Bool {
        instructions.contains { instruction in
            if case .config = instruction.type { return true }
            return false
        }
    }

    // MARK: - Messages

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Clear success message
    func clearSuccess() {
        successMessage = nil
    }
}

// MARK: - Keyboard Shortcuts Support

extension WorkflowBuilderViewModel {

    func handleKeyCommand(_ key: KeyEquivalent, modifiers: EventModifiers) {
        switch (key, modifiers) {
        case (.delete, _), (.deleteForward, _):
            deleteSelectedInstruction()
        case ("d", .command):
            duplicateSelectedInstruction()
        case (.upArrow, .option):
            moveSelectedUp()
        case (.downArrow, .option):
            moveSelectedDown()
        case (.upArrow, _):
            selectPrevious()
        case (.downArrow, _):
            selectNext()
        default:
            break
        }
    }
}
