//
//  AIGenerationView.swift
//  DrawThingsStudio
//
//  UI for AI-powered prompt and workflow generation
//

import SwiftUI
import Combine

// MARK: - AI Generation Sheet

struct AIGenerationSheet: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel
    @StateObject private var aiViewModel = AIGenerationViewModel()
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status bar
                ConnectionStatusBar(viewModel: aiViewModel)

                Divider()

                // Main content
                if aiViewModel.connectionStatus.isConnected {
                    GenerationOptionsView(
                        aiViewModel: aiViewModel,
                        workflowViewModel: viewModel,
                        isPresented: $isPresented
                    )
                } else {
                    ConnectionSetupView(viewModel: aiViewModel)
                }
            }
            .navigationTitle("AI Generation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(width: 550, height: 600)
        .onAppear {
            Task {
                await aiViewModel.checkConnection()
            }
        }
    }
}

// MARK: - AI Generation ViewModel

@MainActor
class AIGenerationViewModel: ObservableObject {
    // Connection - load from settings
    @Published var host: String
    @Published var port: String
    @Published var connectionStatus: LLMConnectionStatus = .disconnected
    @Published var availableModels: [LLMModel] = []
    @Published var selectedModel: String

    private let settings = AppSettings.shared

    init() {
        // Initialize from saved settings
        self.host = settings.ollamaHost
        self.port = String(settings.ollamaPort)
        self.selectedModel = settings.ollamaDefaultModel
    }

    // Generation state
    @Published var isGenerating: Bool = false
    @Published var generationProgress: String = ""
    @Published var errorMessage: String?

    // Ollama client and generator
    private var ollamaClient: OllamaClient?
    private var promptGenerator: WorkflowPromptGenerator?

    func checkConnection() async {
        connectionStatus = .connecting

        let client = OllamaClient(host: host, port: Int(port) ?? 11434, defaultModel: selectedModel)
        let connected = await client.checkConnection()

        if connected {
            connectionStatus = .connected
            ollamaClient = client
            promptGenerator = WorkflowPromptGenerator(ollamaClient: client)

            // Save successful connection settings
            settings.ollamaHost = host
            settings.ollamaPort = Int(port) ?? 11434

            // Load models
            do {
                availableModels = try await client.listModels()
                if let firstModel = availableModels.first {
                    selectedModel = firstModel.name
                    client.defaultModel = firstModel.name
                    settings.ollamaDefaultModel = firstModel.name
                }
            } catch {
                errorMessage = "Failed to load models: \(error.localizedDescription)"
            }
        } else {
            connectionStatus = .error("Could not connect to Ollama")
        }
    }

    func disconnect() {
        ollamaClient = nil
        promptGenerator = nil
        connectionStatus = .disconnected
        availableModels = []
    }

    // MARK: - Generation Methods

    func generateStoryWorkflow(
        concept: String,
        sceneCount: Int,
        style: PromptStyle,
        config: DrawThingsConfig
    ) async throws -> [[String: Any]] {
        guard let generator = promptGenerator else {
            throw LLMError.connectionFailed("Not connected to Ollama")
        }

        ollamaClient?.defaultModel = selectedModel
        isGenerating = true
        generationProgress = "Generating story..."

        defer { isGenerating = false }

        return try await generator.generateStoryWorkflow(
            concept: concept,
            sceneCount: sceneCount,
            style: style,
            config: config
        )
    }

    func generateVariationWorkflow(
        concept: String,
        variationCount: Int,
        style: PromptStyle,
        config: DrawThingsConfig
    ) async throws -> [[String: Any]] {
        guard let generator = promptGenerator else {
            throw LLMError.connectionFailed("Not connected to Ollama")
        }

        ollamaClient?.defaultModel = selectedModel
        isGenerating = true
        generationProgress = "Generating variations..."

        defer { isGenerating = false }

        return try await generator.generateVariationWorkflow(
            concept: concept,
            variationCount: variationCount,
            style: style,
            config: config
        )
    }

    func generateCharacterWorkflow(
        characterConcept: String,
        sceneDescriptions: [String],
        style: PromptStyle,
        config: DrawThingsConfig
    ) async throws -> [[String: Any]] {
        guard let generator = promptGenerator else {
            throw LLMError.connectionFailed("Not connected to Ollama")
        }

        ollamaClient?.defaultModel = selectedModel
        isGenerating = true
        generationProgress = "Generating character workflow..."

        defer { isGenerating = false }

        return try await generator.generateCharacterWorkflow(
            characterConcept: characterConcept,
            sceneDescriptions: sceneDescriptions,
            style: style,
            config: config
        )
    }

    func enhancePrompt(concept: String, style: PromptStyle) async throws -> String {
        guard let generator = promptGenerator else {
            throw LLMError.connectionFailed("Not connected to Ollama")
        }

        ollamaClient?.defaultModel = selectedModel
        isGenerating = true
        generationProgress = "Enhancing prompt..."

        defer { isGenerating = false }

        return try await generator.enhancePrompt(concept: concept, style: style)
    }
}

// MARK: - Connection Status Bar

struct ConnectionStatusBar: View {
    @ObservedObject var viewModel: AIGenerationViewModel

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(viewModel.connectionStatus.statusText)
                .font(.caption)

            Spacer()

            if viewModel.connectionStatus.isConnected {
                Picker("Model", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.availableModels) { model in
                        Text(model.name).tag(model.name)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var statusColor: Color {
        switch viewModel.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

// MARK: - Connection Setup View

struct ConnectionSetupView: View {
    @ObservedObject var viewModel: AIGenerationViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Connect to Ollama")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter your Ollama server details to enable AI-powered prompt generation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                HStack {
                    Text("Host:")
                        .frame(width: 50, alignment: .trailing)
                    TextField("localhost", text: $viewModel.host)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }

                HStack {
                    Text("Port:")
                        .frame(width: 50, alignment: .trailing)
                    TextField("11434", text: $viewModel.port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
            }

            Button {
                Task {
                    await viewModel.checkConnection()
                }
            } label: {
                if case .connecting = viewModel.connectionStatus {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 100)
                } else {
                    Text("Connect")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.connectionStatus == .connecting)

            if case .error(let message) = viewModel.connectionStatus {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            Text("Make sure Ollama is running: ollama serve")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Generation Options View

struct GenerationOptionsView: View {
    @ObservedObject var aiViewModel: AIGenerationViewModel
    @ObservedObject var workflowViewModel: WorkflowBuilderViewModel
    @Binding var isPresented: Bool

    @State private var selectedTab: GenerationType = .story
    @State private var concept: String = ""
    @State private var sceneCount: Int = 3
    @State private var variationCount: Int = 5
    @State private var selectedStyle: PromptStyle = .creative
    @State private var characterConcept: String = ""
    @State private var sceneDescriptions: String = ""

    // Config
    @State private var width: Int = 1024
    @State private var height: Int = 1024
    @State private var steps: Int = 30

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Generation Type", selection: $selectedTab) {
                ForEach(GenerationType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content based on tab
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .story:
                        storyGenerationForm
                    case .variations:
                        variationsGenerationForm
                    case .character:
                        characterGenerationForm
                    }

                    Divider()

                    // Common config
                    configSection

                    // Style picker
                    styleSection
                }
                .padding()
            }

            Divider()

            // Generate button
            generateButton
        }
    }

    // MARK: - Story Form

    private var storyGenerationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generate Story Sequence")
                .font(.headline)

            Text("Describe your story concept and the AI will generate scene prompts")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $concept)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if concept.isEmpty {
                        Text("e.g., A wizard's journey through an enchanted forest...")
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Text("Number of scenes:")
                Stepper("\(sceneCount)", value: $sceneCount, in: 2...10)
            }
        }
    }

    // MARK: - Variations Form

    private var variationsGenerationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generate Variations")
                .font(.headline)

            Text("Enter a concept and the AI will create multiple prompt variations")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $concept)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if concept.isEmpty {
                        Text("e.g., A cyberpunk city at night...")
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Text("Number of variations:")
                Stepper("\(variationCount)", value: $variationCount, in: 2...10)
            }
        }
    }

    // MARK: - Character Form

    private var characterGenerationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Character Consistency Workflow")
                .font(.headline)

            Text("Describe a character and list scenes to generate consistent images")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Character Description:")
                .font(.subheadline)

            TextEditor(text: $characterConcept)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if characterConcept.isEmpty {
                        Text("e.g., A young woman with red hair and green eyes...")
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }

            Text("Scene Descriptions (one per line):")
                .font(.subheadline)

            TextEditor(text: $sceneDescriptions)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if sceneDescriptions.isEmpty {
                        Text("walking in a park\nsitting in a cafe\nstanding on a rooftop")
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generation Settings")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Width")
                        .font(.caption)
                    TextField("", value: $width, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                VStack(alignment: .leading) {
                    Text("Height")
                        .font(.caption)
                    TextField("", value: $height, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                VStack(alignment: .leading) {
                    Text("Steps")
                        .font(.caption)
                    TextField("", value: $steps, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
        }
    }

    // MARK: - Style Section

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt Style")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(PromptStyle.allCases) { style in
                    StyleButton(
                        style: style,
                        isSelected: selectedStyle == style
                    ) {
                        selectedStyle = style
                    }
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        HStack {
            if aiViewModel.isGenerating {
                ProgressView()
                    .scaleEffect(0.8)
                Text(aiViewModel.generationProgress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Generate Workflow") {
                Task {
                    await generate()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(aiViewModel.isGenerating || !canGenerate)
        }
        .padding()
    }

    private var canGenerate: Bool {
        switch selectedTab {
        case .story, .variations:
            return !concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .character:
            return !characterConcept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !sceneDescriptions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Generate Action

    private func generate() async {
        let config = DrawThingsConfig(
            width: width,
            height: height,
            steps: steps,
            guidanceScale: 7.5
        )

        do {
            let instructions: [[String: Any]]

            switch selectedTab {
            case .story:
                instructions = try await aiViewModel.generateStoryWorkflow(
                    concept: concept,
                    sceneCount: sceneCount,
                    style: selectedStyle,
                    config: config
                )

            case .variations:
                instructions = try await aiViewModel.generateVariationWorkflow(
                    concept: concept,
                    variationCount: variationCount,
                    style: selectedStyle,
                    config: config
                )

            case .character:
                let scenes = sceneDescriptions
                    .split(separator: "\n")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                instructions = try await aiViewModel.generateCharacterWorkflow(
                    characterConcept: characterConcept,
                    sceneDescriptions: scenes,
                    style: selectedStyle,
                    config: config
                )
            }

            // Load generated instructions into the workflow
            await MainActor.run {
                loadInstructions(instructions)
                isPresented = false
            }

        } catch {
            await MainActor.run {
                aiViewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func loadInstructions(_ instructions: [[String: Any]]) {
        workflowViewModel.clearAllInstructions()

        for dict in instructions {
            if let instruction = parseInstruction(dict) {
                workflowViewModel.addInstruction(instruction)
            }
        }

        workflowViewModel.workflowName = "AI Generated Workflow"
    }

    private func parseInstruction(_ dict: [String: Any]) -> InstructionType? {
        guard let key = dict.keys.first else { return nil }

        switch key {
        case "note":
            if let value = dict[key] as? String { return .note(value) }
        case "prompt":
            if let value = dict[key] as? String { return .prompt(value) }
        case "negPrompt":
            if let value = dict[key] as? String { return .negativePrompt(value) }
        case "config":
            if let configDict = dict[key] as? [String: Any] {
                let config = DrawThingsConfig(
                    width: configDict["width"] as? Int,
                    height: configDict["height"] as? Int,
                    steps: configDict["steps"] as? Int,
                    guidanceScale: configDict["guidanceScale"] as? Float,
                    seed: configDict["seed"] as? Int,
                    model: configDict["model"] as? String
                )
                return .config(config)
            }
        case "canvasSave":
            if let value = dict[key] as? String { return .canvasSave(value) }
        case "canvasLoad":
            if let value = dict[key] as? String { return .canvasLoad(value) }
        case "canvasClear":
            return .canvasClear
        case "moodboardClear":
            return .moodboardClear
        case "moodboardCanvas":
            return .moodboardCanvas
        case "moodboardWeights":
            if let weightsDict = dict[key] as? [String: Any] {
                var weights: [Int: Float] = [:]
                for (k, v) in weightsDict {
                    if let index = Int(k.replacingOccurrences(of: "index_", with: "")),
                       let weight = v as? Float {
                        weights[index] = weight
                    } else if let weight = v as? Double {
                        if let index = Int(k.replacingOccurrences(of: "index_", with: "")) {
                            weights[index] = Float(weight)
                        }
                    }
                }
                return .moodboardWeights(weights)
            }
        case "loop":
            if let loopDict = dict[key] as? [String: Any],
               let count = loopDict["loop"] as? Int {
                let start = loopDict["start"] as? Int ?? 0
                return .loop(count: count, start: start)
            }
        case "loopEnd":
            return .loopEnd
        case "loopSave":
            if let value = dict[key] as? String { return .loopSave(value) }
        default:
            return nil
        }
        return nil
    }
}

// MARK: - Generation Type

enum GenerationType: String, CaseIterable, Identifiable {
    case story
    case variations
    case character

    var id: String { rawValue }

    var title: String {
        switch self {
        case .story: return "Story"
        case .variations: return "Variations"
        case .character: return "Character"
        }
    }
}

// MARK: - Style Button

struct StyleButton: View {
    let style: PromptStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: style.icon)
                    .font(.title3)
                Text(style.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
}
