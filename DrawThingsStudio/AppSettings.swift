//
//  AppSettings.swift
//  DrawThingsStudio
//
//  App-wide settings and persistence
//

import SwiftUI
import Combine

/// App-wide settings with persistence via UserDefaults
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - LLM Provider Settings

    @Published var selectedProvider: String {
        didSet { defaults.set(selectedProvider, forKey: "llm.provider") }
    }

    // Ollama Settings
    @Published var ollamaHost: String {
        didSet { defaults.set(ollamaHost, forKey: "ollama.host") }
    }
    @Published var ollamaPort: Int {
        didSet { defaults.set(ollamaPort, forKey: "ollama.port") }
    }
    @Published var ollamaDefaultModel: String {
        didSet { defaults.set(ollamaDefaultModel, forKey: "ollama.defaultModel") }
    }
    @Published var ollamaAutoConnect: Bool {
        didSet { defaults.set(ollamaAutoConnect, forKey: "ollama.autoConnect") }
    }

    // LM Studio Settings
    @Published var lmStudioHost: String {
        didSet { defaults.set(lmStudioHost, forKey: "lmstudio.host") }
    }
    @Published var lmStudioPort: Int {
        didSet { defaults.set(lmStudioPort, forKey: "lmstudio.port") }
    }

    // Jan Settings
    @Published var janHost: String {
        didSet { defaults.set(janHost, forKey: "jan.host") }
    }
    @Published var janPort: Int {
        didSet { defaults.set(janPort, forKey: "jan.port") }
    }

    // Msty Studio Settings
    @Published var mstyStudioHost: String {
        didSet { defaults.set(mstyStudioHost, forKey: "mstystudio.host") }
    }
    @Published var mstyStudioPort: Int {
        didSet { defaults.set(mstyStudioPort, forKey: "mstystudio.port") }
    }

    // MARK: - Default Generation Settings

    @Published var defaultWidth: Int {
        didSet { defaults.set(defaultWidth, forKey: "defaults.width") }
    }
    @Published var defaultHeight: Int {
        didSet { defaults.set(defaultHeight, forKey: "defaults.height") }
    }
    @Published var defaultSteps: Int {
        didSet { defaults.set(defaultSteps, forKey: "defaults.steps") }
    }
    @Published var defaultGuidanceScale: Double {
        didSet { defaults.set(defaultGuidanceScale, forKey: "defaults.guidanceScale") }
    }
    @Published var defaultShift: Double {
        didSet { defaults.set(defaultShift, forKey: "defaults.shift") }
    }
    @Published var defaultSampler: String {
        didSet { defaults.set(defaultSampler, forKey: "defaults.sampler") }
    }
    @Published var defaultStyle: String {
        didSet { defaults.set(defaultStyle, forKey: "defaults.style") }
    }

    // MARK: - UI Settings

    @Published var showValidationWarnings: Bool {
        didSet { defaults.set(showValidationWarnings, forKey: "ui.showValidationWarnings") }
    }
    @Published var autoPreviewJSON: Bool {
        didSet { defaults.set(autoPreviewJSON, forKey: "ui.autoPreviewJSON") }
    }
    @Published var compactJSON: Bool {
        didSet { defaults.set(compactJSON, forKey: "ui.compactJSON") }
    }

    // MARK: - Init

    init() {
        // Load from defaults or use default values

        // Provider selection
        self.selectedProvider = defaults.string(forKey: "llm.provider") ?? LLMProviderType.ollama.rawValue

        // Ollama
        self.ollamaHost = defaults.string(forKey: "ollama.host") ?? "localhost"
        self.ollamaPort = defaults.integer(forKey: "ollama.port") != 0 ? defaults.integer(forKey: "ollama.port") : 11434
        self.ollamaDefaultModel = defaults.string(forKey: "ollama.defaultModel") ?? "llama3.2"
        self.ollamaAutoConnect = defaults.object(forKey: "ollama.autoConnect") as? Bool ?? true

        // LM Studio
        self.lmStudioHost = defaults.string(forKey: "lmstudio.host") ?? "localhost"
        self.lmStudioPort = defaults.integer(forKey: "lmstudio.port") != 0 ? defaults.integer(forKey: "lmstudio.port") : 1234

        // Jan
        self.janHost = defaults.string(forKey: "jan.host") ?? "localhost"
        self.janPort = defaults.integer(forKey: "jan.port") != 0 ? defaults.integer(forKey: "jan.port") : 1337

        // Msty Studio
        self.mstyStudioHost = defaults.string(forKey: "mstystudio.host") ?? "localhost"
        self.mstyStudioPort = defaults.integer(forKey: "mstystudio.port") != 0 ? defaults.integer(forKey: "mstystudio.port") : 10000

        self.defaultWidth = defaults.integer(forKey: "defaults.width") != 0 ? defaults.integer(forKey: "defaults.width") : 1024
        self.defaultHeight = defaults.integer(forKey: "defaults.height") != 0 ? defaults.integer(forKey: "defaults.height") : 1024
        self.defaultSteps = defaults.integer(forKey: "defaults.steps") != 0 ? defaults.integer(forKey: "defaults.steps") : 30
        self.defaultGuidanceScale = defaults.double(forKey: "defaults.guidanceScale") != 0 ? defaults.double(forKey: "defaults.guidanceScale") : 7.5
        self.defaultShift = defaults.double(forKey: "defaults.shift") // 0 means not set
        self.defaultSampler = defaults.string(forKey: "defaults.sampler") ?? ""
        self.defaultStyle = defaults.string(forKey: "defaults.style") ?? "creative"

        self.showValidationWarnings = defaults.object(forKey: "ui.showValidationWarnings") as? Bool ?? true
        self.autoPreviewJSON = defaults.bool(forKey: "ui.autoPreviewJSON")
        self.compactJSON = defaults.bool(forKey: "ui.compactJSON")
    }

    // MARK: - Computed Properties

    var defaultConfig: DrawThingsConfig {
        DrawThingsConfig(
            width: defaultWidth,
            height: defaultHeight,
            steps: defaultSteps,
            guidanceScale: Float(defaultGuidanceScale),
            samplerName: defaultSampler.isEmpty ? nil : defaultSampler,
            shift: defaultShift > 0 ? Float(defaultShift) : nil
        )
    }

    var defaultPromptStyle: PromptStyle {
        PromptStyle(rawValue: defaultStyle) ?? .creative
    }

    var providerType: LLMProviderType {
        LLMProviderType(rawValue: selectedProvider) ?? .ollama
    }

    /// Creates an LLM client based on current settings
    func createLLMClient() -> any LLMProvider {
        switch providerType {
        case .ollama:
            return OllamaClient(
                host: ollamaHost,
                port: ollamaPort,
                defaultModel: ollamaDefaultModel
            )
        case .lmStudio:
            return OpenAICompatibleClient(
                providerType: .lmStudio,
                host: lmStudioHost,
                port: lmStudioPort
            )
        case .jan:
            return OpenAICompatibleClient(
                providerType: .jan,
                host: janHost,
                port: janPort
            )
        case .mstyStudio:
            return OpenAICompatibleClient(
                providerType: .mstyStudio,
                host: mstyStudioHost,
                port: mstyStudioPort
            )
        }
    }

    // MARK: - Methods

    func resetToDefaults() {
        selectedProvider = LLMProviderType.ollama.rawValue

        ollamaHost = "localhost"
        ollamaPort = 11434
        ollamaDefaultModel = "llama3.2"
        ollamaAutoConnect = true

        lmStudioHost = "localhost"
        lmStudioPort = 1234

        janHost = "localhost"
        janPort = 1337

        mstyStudioHost = "localhost"
        mstyStudioPort = 10000

        defaultWidth = 1024
        defaultHeight = 1024
        defaultSteps = 30
        defaultGuidanceScale = 7.5
        defaultShift = 0
        defaultSampler = ""
        defaultStyle = "creative"

        showValidationWarnings = true
        autoPreviewJSON = false
        compactJSON = false
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var testingConnection = false
    @State private var connectionResult: String?

    var body: some View {
        Form {
            // Provider Selection
            Section("LLM Provider") {
                Picker("Provider", selection: $settings.selectedProvider) {
                    ForEach(LLMProviderType.allCases) { provider in
                        Label(provider.displayName, systemImage: provider.icon)
                            .tag(provider.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.selectedProvider) { _, _ in
                    connectionResult = nil
                }

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(testingConnection)

                    if testingConnection {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    if let result = connectionResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            }

            // Provider-specific settings
            if settings.providerType == .ollama {
                Section("Ollama Settings") {
                    TextField("Host", text: $settings.ollamaHost)
                        .textFieldStyle(.roundedBorder)

                    TextField("Port", value: $settings.ollamaPort, format: .number)
                        .textFieldStyle(.roundedBorder)

                    TextField("Default Model", text: $settings.ollamaDefaultModel)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Auto-connect on launch", isOn: $settings.ollamaAutoConnect)
                }
            }

            if settings.providerType == .lmStudio {
                Section("LM Studio Settings") {
                    TextField("Host", text: $settings.lmStudioHost)
                        .textFieldStyle(.roundedBorder)

                    TextField("Port", value: $settings.lmStudioPort, format: .number)
                        .textFieldStyle(.roundedBorder)

                    Text("LM Studio uses OpenAI-compatible API on port 1234 by default.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if settings.providerType == .jan {
                Section("Jan Settings") {
                    TextField("Host", text: $settings.janHost)
                        .textFieldStyle(.roundedBorder)

                    TextField("Port", value: $settings.janPort, format: .number)
                        .textFieldStyle(.roundedBorder)

                    Text("Jan uses OpenAI-compatible API on port 1337 by default.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if settings.providerType == .mstyStudio {
                Section("Msty Settings") {
                    TextField("Host", text: $settings.mstyStudioHost)
                        .textFieldStyle(.roundedBorder)

                    TextField("Port", value: $settings.mstyStudioPort, format: .number)
                        .textFieldStyle(.roundedBorder)

                    Text("Msty uses OpenAI-compatible API on port 10000 by default.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Default Generation Settings
            Section("Default Generation Settings") {
                HStack {
                    Text("Width")
                    Spacer()
                    TextField("", value: $settings.defaultWidth, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("Height")
                    Spacer()
                    TextField("", value: $settings.defaultHeight, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("Steps")
                    Spacer()
                    TextField("", value: $settings.defaultSteps, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("Guidance Scale")
                    Spacer()
                    TextField("", value: $settings.defaultGuidanceScale, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("Shift (0 = not set)")
                    Spacer()
                    TextField("", value: $settings.defaultShift, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("Sampler")
                    Spacer()
                    TextField("e.g., DPM++ 2M Karras", text: $settings.defaultSampler)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }

                Picker("Default Style", selection: $settings.defaultStyle) {
                    ForEach(PromptStyle.allCases) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
            }

            // UI Settings
            Section("Interface") {
                Toggle("Show validation warnings", isOn: $settings.showValidationWarnings)
                Toggle("Use compact JSON format", isOn: $settings.compactJSON)
            }

            // Reset
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 500)
        .navigationTitle("Settings")
    }

    private func testConnection() {
        testingConnection = true
        connectionResult = nil

        Task {
            let client = settings.createLLMClient()
            let success = await client.checkConnection()
            let providerName = settings.providerType.displayName

            await MainActor.run {
                testingConnection = false
                connectionResult = success ? "Success! Connected to \(providerName)" : "Failed to connect"
            }
        }
    }
}
