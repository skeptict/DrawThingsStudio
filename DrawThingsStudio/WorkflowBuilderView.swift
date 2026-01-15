//
//  WorkflowBuilderView.swift
//  DrawThingsStudio
//
//  Main workflow builder interface
//

import SwiftUI

/// Main view for building StoryFlow workflows
struct WorkflowBuilderView: View {
    @StateObject private var viewModel = WorkflowBuilderViewModel()
    @State private var showJSONPreview = false
    @State private var showAddInstructionSheet = false
    @State private var showTemplatesSheet = false

    var body: some View {
        HSplitView {
            // Left: Instruction list
            InstructionListView(viewModel: viewModel)
                .frame(minWidth: 280, idealWidth: 320)

            // Right: Instruction editor
            InstructionEditorView(viewModel: viewModel)
                .frame(minWidth: 400)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Add instruction menu
                Menu {
                    addInstructionMenu
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button {
                    showTemplatesSheet = true
                } label: {
                    Label("Templates", systemImage: "doc.on.doc")
                }

                Divider()

                Button {
                    showJSONPreview = true
                } label: {
                    Label("Preview", systemImage: "eye")
                }
                .disabled(viewModel.instructions.isEmpty)

                Button {
                    viewModel.copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                }
                .disabled(viewModel.instructions.isEmpty)

                Button {
                    Task {
                        await viewModel.exportWithSavePanel()
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.instructions.isEmpty)
            }
        }
        .sheet(isPresented: $showJSONPreview) {
            JSONPreviewView(viewModel: viewModel)
        }
        .sheet(isPresented: $showTemplatesSheet) {
            TemplatesSheet(viewModel: viewModel, isPresented: $showTemplatesSheet)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .navigationTitle(viewModel.workflowName)
    }

    // MARK: - Add Instruction Menu

    @ViewBuilder
    private var addInstructionMenu: some View {
        Menu("Flow Control") {
            Button("Note") { viewModel.addInstruction(.note("")) }
            Button("Loop") { viewModel.addInstruction(.loop(count: 5, start: 0)) }
            Button("Loop End") { viewModel.addInstruction(.loopEnd) }
            Button("End") { viewModel.addInstruction(.end) }
        }

        Menu("Prompt & Config") {
            Button("Prompt") { viewModel.addInstruction(.prompt("")) }
            Button("Negative Prompt") { viewModel.addInstruction(.negativePrompt("")) }
            Button("Config") { viewModel.addInstruction(.config(DrawThingsConfig())) }
            Button("Frames") { viewModel.addInstruction(.frames(24)) }
        }

        Menu("Canvas") {
            Button("Clear Canvas") { viewModel.addInstruction(.canvasClear) }
            Button("Load Canvas") { viewModel.addInstruction(.canvasLoad("")) }
            Button("Save Canvas") { viewModel.addInstruction(.canvasSave("output.png")) }
            Button("Move & Scale") { viewModel.addInstruction(.moveScale(x: 0, y: 0, scale: 1.0)) }
            Button("Adapt Size") { viewModel.addInstruction(.adaptSize(maxWidth: 2048, maxHeight: 2048)) }
            Button("Crop") { viewModel.addInstruction(.crop) }
        }

        Menu("Moodboard") {
            Button("Clear Moodboard") { viewModel.addInstruction(.moodboardClear) }
            Button("Canvas to Moodboard") { viewModel.addInstruction(.moodboardCanvas) }
            Button("Add to Moodboard") { viewModel.addInstruction(.moodboardAdd("")) }
            Button("Remove from Moodboard") { viewModel.addInstruction(.moodboardRemove(0)) }
            Button("Moodboard Weights") { viewModel.addInstruction(.moodboardWeights([0: 1.0])) }
        }

        Menu("Mask") {
            Button("Clear Mask") { viewModel.addInstruction(.maskClear) }
            Button("Load Mask") { viewModel.addInstruction(.maskLoad("")) }
            Button("Mask Background") { viewModel.addInstruction(.maskBackground) }
            Button("Mask Foreground") { viewModel.addInstruction(.maskForeground) }
            Button("AI Mask") { viewModel.addInstruction(.maskAsk("")) }
        }

        Menu("Advanced") {
            Button("Remove Background") { viewModel.addInstruction(.removeBackground) }
            Button("Face Zoom") { viewModel.addInstruction(.faceZoom) }
            Button("AI Zoom") { viewModel.addInstruction(.askZoom("")) }
            Button("Inpaint Tools") { viewModel.addInstruction(.inpaintTools(strength: 0.7, maskBlur: 4, maskBlurOutset: 0, restoreOriginal: false)) }
        }

        Menu("Loop Operations") {
            Button("Loop Load") { viewModel.addInstruction(.loopLoad("")) }
            Button("Loop Save") { viewModel.addInstruction(.loopSave("output_")) }
        }
    }
}

// MARK: - Instruction List View

struct InstructionListView: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Instructions")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.instructionCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding()

            Divider()

            // List
            if viewModel.instructions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Instructions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add instructions using the + button\nor load a template to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedInstructionID) {
                    ForEach(viewModel.instructions) { instruction in
                        InstructionRow(instruction: instruction)
                            .tag(instruction.id)
                    }
                    .onMove { from, to in
                        viewModel.moveInstructions(from: from, to: to)
                    }
                    .onDelete { indexSet in
                        viewModel.deleteInstructions(at: indexSet)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer actions
            HStack {
                Button {
                    viewModel.deleteSelectedInstruction()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(!viewModel.hasSelection)
                .help("Delete selected instruction")

                Button {
                    viewModel.duplicateSelectedInstruction()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(!viewModel.hasSelection)
                .help("Duplicate selected instruction")

                Spacer()

                Button {
                    viewModel.moveSelectedUp()
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(!viewModel.hasSelection)
                .help("Move up")

                Button {
                    viewModel.moveSelectedDown()
                } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(!viewModel.hasSelection)
                .help("Move down")
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let instruction: WorkflowInstruction

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: instruction.icon)
                .foregroundColor(instruction.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(instruction.title)
                    .font(.system(.body, design: .default, weight: .medium))
                Text(instruction.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Instruction Editor View

struct InstructionEditorView: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let instruction = viewModel.selectedInstruction {
                // Header
                HStack {
                    Image(systemName: instruction.icon)
                        .foregroundColor(instruction.color)
                        .font(.title2)
                    Text(instruction.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()

                Divider()

                // Editor content
                ScrollView {
                    InstructionEditorContent(viewModel: viewModel, instruction: instruction)
                        .padding()
                }
            } else {
                // No selection
                VStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select an Instruction")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Choose an instruction from the list\nto edit its properties")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Instruction Editor Content

struct InstructionEditorContent: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel
    let instruction: WorkflowInstruction

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch instruction.type {
            case .note(let text):
                NoteEditor(text: text) { newText in
                    viewModel.updateSelectedInstruction(type: .note(newText))
                }

            case .prompt(let text):
                PromptEditor(label: "Prompt", text: text) { newText in
                    viewModel.updateSelectedInstruction(type: .prompt(newText))
                }

            case .negativePrompt(let text):
                PromptEditor(label: "Negative Prompt", text: text) { newText in
                    viewModel.updateSelectedInstruction(type: .negativePrompt(newText))
                }

            case .config(let config):
                ConfigEditor(config: config) { newConfig in
                    viewModel.updateSelectedInstruction(type: .config(newConfig))
                }

            case .loop(let count, let start):
                LoopEditor(count: count, start: start) { newCount, newStart in
                    viewModel.updateSelectedInstruction(type: .loop(count: newCount, start: newStart))
                }

            case .canvasLoad(let path):
                FilePathEditor(label: "File Path", path: path, placeholder: "image.png") { newPath in
                    viewModel.updateSelectedInstruction(type: .canvasLoad(newPath))
                }

            case .canvasSave(let path):
                FilePathEditor(label: "Output File", path: path, placeholder: "output.png", mustBePNG: true) { newPath in
                    viewModel.updateSelectedInstruction(type: .canvasSave(newPath))
                }

            case .moodboardAdd(let path):
                FilePathEditor(label: "Image Path", path: path, placeholder: "reference.png") { newPath in
                    viewModel.updateSelectedInstruction(type: .moodboardAdd(newPath))
                }

            case .moodboardRemove(let index):
                NumberEditor(label: "Index", value: index, range: 0...99) { newIndex in
                    viewModel.updateSelectedInstruction(type: .moodboardRemove(newIndex))
                }

            case .moodboardWeights(let weights):
                MoodboardWeightsEditor(weights: weights) { newWeights in
                    viewModel.updateSelectedInstruction(type: .moodboardWeights(newWeights))
                }

            case .maskLoad(let path):
                FilePathEditor(label: "Mask File", path: path, placeholder: "mask.png") { newPath in
                    viewModel.updateSelectedInstruction(type: .maskLoad(newPath))
                }

            case .maskAsk(let description):
                PromptEditor(label: "Description", text: description, placeholder: "e.g., the person's face") { newDesc in
                    viewModel.updateSelectedInstruction(type: .maskAsk(newDesc))
                }

            case .askZoom(let description):
                PromptEditor(label: "Target Description", text: description, placeholder: "e.g., the building") { newDesc in
                    viewModel.updateSelectedInstruction(type: .askZoom(newDesc))
                }

            case .loopLoad(let folder):
                FilePathEditor(label: "Folder Name", path: folder, placeholder: "input_frames", isFolder: true) { newFolder in
                    viewModel.updateSelectedInstruction(type: .loopLoad(newFolder))
                }

            case .loopSave(let prefix):
                FilePathEditor(label: "Output Prefix", path: prefix, placeholder: "frame_") { newPrefix in
                    viewModel.updateSelectedInstruction(type: .loopSave(newPrefix))
                }

            case .frames(let count):
                NumberEditor(label: "Frame Count", value: count, range: 1...1000) { newCount in
                    viewModel.updateSelectedInstruction(type: .frames(newCount))
                }

            case .inpaintTools(let strength, let blur, let outset, let restore):
                InpaintToolsEditor(strength: strength, maskBlur: blur, maskBlurOutset: outset, restoreOriginal: restore) { s, b, o, r in
                    viewModel.updateSelectedInstruction(type: .inpaintTools(strength: s, maskBlur: b, maskBlurOutset: o, restoreOriginal: r))
                }

            case .moveScale(let x, let y, let scale):
                MoveScaleEditor(x: x, y: y, scale: scale) { newX, newY, newScale in
                    viewModel.updateSelectedInstruction(type: .moveScale(x: newX, y: newY, scale: newScale))
                }

            case .adaptSize(let w, let h):
                SizeEditor(width: w, height: h) { newW, newH in
                    viewModel.updateSelectedInstruction(type: .adaptSize(maxWidth: newW, maxHeight: newH))
                }

            default:
                // Simple instructions with no editable parameters
                Text("This instruction has no editable parameters.")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Editor Components

struct NoteEditor: View {
    let text: String
    let onChange: (String) -> Void

    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note Text")
                .font(.headline)
            TextField("Enter note...", text: $editText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: editText) { _, newValue in
                    onChange(newValue)
                }
        }
        .onAppear { editText = text }
    }
}

struct PromptEditor: View {
    let label: String
    let text: String
    var placeholder: String = "Enter prompt..."
    let onChange: (String) -> Void

    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            TextEditor(text: $editText)
                .font(.body)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: editText) { _, newValue in
                    onChange(newValue)
                }

            Text("\(editText.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear { editText = text }
    }
}

struct FilePathEditor: View {
    let label: String
    let path: String
    var placeholder: String = "filename.png"
    var mustBePNG: Bool = false
    var isFolder: Bool = false
    let onChange: (String) -> Void

    @State private var editPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            TextField(placeholder, text: $editPath)
                .textFieldStyle(.roundedBorder)
                .onChange(of: editPath) { _, newValue in
                    onChange(newValue)
                }

            if mustBePNG {
                Text("Must end with .png")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if isFolder {
                Text("Folder name in Pictures directory")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Relative to Pictures folder (.png, .jpg, .webp)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { editPath = path }
    }
}

struct NumberEditor: View {
    let label: String
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    @State private var editValue: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            HStack {
                TextField("", value: $editValue, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Stepper("", value: $editValue, in: range)
                    .labelsHidden()
            }
            .onChange(of: editValue) { _, newValue in
                onChange(newValue)
            }
        }
        .onAppear { editValue = value }
    }
}

struct ConfigEditor: View {
    let config: DrawThingsConfig
    let onChange: (DrawThingsConfig) -> Void

    @State private var width: Int = 1024
    @State private var height: Int = 1024
    @State private var steps: Int = 30
    @State private var guidanceScale: Float = 7.5
    @State private var seed: Int = -1
    @State private var model: String = ""
    @State private var strength: Float = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generation Settings")
                .font(.headline)

            Group {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Width")
                            .font(.caption)
                        TextField("", value: $width, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading) {
                        Text("Height")
                            .font(.caption)
                        TextField("", value: $height, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Steps: \(steps)")
                        .font(.caption)
                    Slider(value: .init(get: { Float(steps) }, set: { steps = Int($0) }), in: 1...150, step: 1)
                }

                VStack(alignment: .leading) {
                    Text("Guidance Scale: \(guidanceScale, specifier: "%.1f")")
                        .font(.caption)
                    Slider(value: $guidanceScale, in: 1...30, step: 0.5)
                }

                VStack(alignment: .leading) {
                    Text("Strength: \(strength, specifier: "%.2f")")
                        .font(.caption)
                    Slider(value: $strength, in: 0...1, step: 0.05)
                }

                VStack(alignment: .leading) {
                    Text("Model")
                        .font(.caption)
                    TextField("model_name.ckpt", text: $model)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Seed (-1 for random)")
                        .font(.caption)
                    TextField("", value: $seed, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .onChange(of: width) { _, _ in updateConfig() }
            .onChange(of: height) { _, _ in updateConfig() }
            .onChange(of: steps) { _, _ in updateConfig() }
            .onChange(of: guidanceScale) { _, _ in updateConfig() }
            .onChange(of: seed) { _, _ in updateConfig() }
            .onChange(of: model) { _, _ in updateConfig() }
            .onChange(of: strength) { _, _ in updateConfig() }
        }
        .onAppear {
            width = config.width ?? 1024
            height = config.height ?? 1024
            steps = config.steps ?? 30
            guidanceScale = config.guidanceScale ?? 7.5
            seed = config.seed ?? -1
            model = config.model ?? ""
            strength = config.strength ?? 1.0
        }
    }

    private func updateConfig() {
        let newConfig = DrawThingsConfig(
            width: width,
            height: height,
            steps: steps,
            guidanceScale: guidanceScale,
            seed: seed == -1 ? nil : seed,
            model: model.isEmpty ? nil : model,
            strength: strength < 1.0 ? strength : nil
        )
        onChange(newConfig)
    }
}

struct LoopEditor: View {
    let count: Int
    let start: Int
    let onChange: (Int, Int) -> Void

    @State private var editCount: Int = 5
    @State private var editStart: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Loop Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Iterations")
                    .font(.caption)
                HStack {
                    TextField("", value: $editCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Stepper("", value: $editCount, in: 1...1000)
                        .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Start Index")
                    .font(.caption)
                HStack {
                    TextField("", value: $editStart, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Stepper("", value: $editStart, in: 0...999)
                        .labelsHidden()
                }
            }
        }
        .onChange(of: editCount) { _, _ in onChange(editCount, editStart) }
        .onChange(of: editStart) { _, _ in onChange(editCount, editStart) }
        .onAppear {
            editCount = count
            editStart = start
        }
    }
}

struct MoodboardWeightsEditor: View {
    let weights: [Int: Float]
    let onChange: ([Int: Float]) -> Void

    @State private var editWeights: [(index: Int, weight: Float)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Moodboard Weights")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    let nextIndex = (editWeights.map(\.index).max() ?? -1) + 1
                    editWeights.append((index: nextIndex, weight: 1.0))
                    updateWeights()
                }
            }

            ForEach(editWeights.indices, id: \.self) { i in
                HStack {
                    Text("Index \(editWeights[i].index)")
                        .frame(width: 60)
                    Slider(value: $editWeights[i].weight, in: 0...2, step: 0.1)
                    Text("\(editWeights[i].weight, specifier: "%.1f")")
                        .frame(width: 40)
                    Button {
                        editWeights.remove(at: i)
                        updateWeights()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
                .onChange(of: editWeights[i].weight) { _, _ in updateWeights() }
            }
        }
        .onAppear {
            editWeights = weights.map { (index: $0.key, weight: $0.value) }.sorted { $0.index < $1.index }
        }
    }

    private func updateWeights() {
        var dict: [Int: Float] = [:]
        for item in editWeights {
            dict[item.index] = item.weight
        }
        onChange(dict)
    }
}

struct InpaintToolsEditor: View {
    let strength: Float?
    let maskBlur: Int?
    let maskBlurOutset: Int?
    let restoreOriginal: Bool?
    let onChange: (Float?, Int?, Int?, Bool?) -> Void

    @State private var editStrength: Float = 0.7
    @State private var editBlur: Int = 4
    @State private var editOutset: Int = 0
    @State private var editRestore: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inpaint Settings")
                .font(.headline)

            VStack(alignment: .leading) {
                Text("Strength: \(editStrength, specifier: "%.2f")")
                    .font(.caption)
                Slider(value: $editStrength, in: 0...1, step: 0.05)
            }

            VStack(alignment: .leading) {
                Text("Mask Blur: \(editBlur)")
                    .font(.caption)
                Slider(value: .init(get: { Float(editBlur) }, set: { editBlur = Int($0) }), in: 0...20, step: 1)
            }

            VStack(alignment: .leading) {
                Text("Mask Blur Outset: \(editOutset)")
                    .font(.caption)
                Slider(value: .init(get: { Float(editOutset) }, set: { editOutset = Int($0) }), in: 0...20, step: 1)
            }

            Toggle("Restore Original After Inpaint", isOn: $editRestore)
        }
        .onChange(of: editStrength) { _, _ in update() }
        .onChange(of: editBlur) { _, _ in update() }
        .onChange(of: editOutset) { _, _ in update() }
        .onChange(of: editRestore) { _, _ in update() }
        .onAppear {
            editStrength = strength ?? 0.7
            editBlur = maskBlur ?? 4
            editOutset = maskBlurOutset ?? 0
            editRestore = restoreOriginal ?? false
        }
    }

    private func update() {
        onChange(editStrength, editBlur, editOutset, editRestore)
    }
}

struct MoveScaleEditor: View {
    let x: Float
    let y: Float
    let scale: Float
    let onChange: (Float, Float, Float) -> Void

    @State private var editX: Float = 0
    @State private var editY: Float = 0
    @State private var editScale: Float = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Position & Scale")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("X Position")
                        .font(.caption)
                    TextField("", value: $editX, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Y Position")
                        .font(.caption)
                    TextField("", value: $editY, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading) {
                Text("Scale: \(editScale, specifier: "%.2f")")
                    .font(.caption)
                Slider(value: $editScale, in: 0.1...4.0, step: 0.1)
            }
        }
        .onChange(of: editX) { _, _ in onChange(editX, editY, editScale) }
        .onChange(of: editY) { _, _ in onChange(editX, editY, editScale) }
        .onChange(of: editScale) { _, _ in onChange(editX, editY, editScale) }
        .onAppear {
            editX = x
            editY = y
            editScale = scale
        }
    }
}

struct SizeEditor: View {
    let width: Int
    let height: Int
    let onChange: (Int, Int) -> Void

    @State private var editWidth: Int = 2048
    @State private var editHeight: Int = 2048

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Maximum Size")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Max Width")
                        .font(.caption)
                    TextField("", value: $editWidth, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Max Height")
                        .font(.caption)
                    TextField("", value: $editHeight, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .onChange(of: editWidth) { _, _ in onChange(editWidth, editHeight) }
        .onChange(of: editHeight) { _, _ in onChange(editWidth, editHeight) }
        .onAppear {
            editWidth = width
            editHeight = height
        }
    }
}

// MARK: - Templates Sheet

struct TemplatesSheet: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Workflow Templates")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose a template to get started quickly")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                TemplateButton(
                    title: "Simple Story",
                    description: "3-scene story sequence with prompts and saves",
                    icon: "book"
                ) {
                    viewModel.loadStoryTemplate()
                    isPresented = false
                }

                TemplateButton(
                    title: "Batch Variations",
                    description: "Generate 5 variations of a single prompt",
                    icon: "square.stack.3d.up"
                ) {
                    viewModel.loadBatchVariationTemplate()
                    isPresented = false
                }

                TemplateButton(
                    title: "Character Consistency",
                    description: "Create consistent character across scenes using moodboard",
                    icon: "person.2"
                ) {
                    viewModel.loadCharacterConsistencyTemplate()
                    isPresented = false
                }

                TemplateButton(
                    title: "Img2Img",
                    description: "Transform an input image with a prompt",
                    icon: "photo.on.rectangle"
                ) {
                    viewModel.loadImg2ImgTemplate()
                    isPresented = false
                }
            }

            Spacer()

            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 400, height: 400)
    }
}

struct TemplateButton: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
