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
    @Published var janAPIKey: String {
        didSet { defaults.set(janAPIKey, forKey: "jan.apiKey") }
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

    // MARK: - Draw Things Settings

    @Published var drawThingsHost: String {
        didSet { defaults.set(drawThingsHost, forKey: "drawthings.host") }
    }
    @Published var drawThingsHTTPPort: Int {
        didSet { defaults.set(drawThingsHTTPPort, forKey: "drawthings.httpPort") }
    }
    @Published var drawThingsGRPCPort: Int {
        didSet { defaults.set(drawThingsGRPCPort, forKey: "drawthings.grpcPort") }
    }
    @Published var drawThingsTransport: String {
        didSet { defaults.set(drawThingsTransport, forKey: "drawthings.transport") }
    }
    @Published var drawThingsSharedSecret: String {
        didSet { defaults.set(drawThingsSharedSecret, forKey: "drawthings.sharedSecret") }
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
        self.janAPIKey = defaults.string(forKey: "jan.apiKey") ?? ""

        // Draw Things
        self.drawThingsHost = defaults.string(forKey: "drawthings.host") ?? "127.0.0.1"
        self.drawThingsHTTPPort = defaults.integer(forKey: "drawthings.httpPort") != 0 ? defaults.integer(forKey: "drawthings.httpPort") : 7860
        self.drawThingsGRPCPort = defaults.integer(forKey: "drawthings.grpcPort") != 0 ? defaults.integer(forKey: "drawthings.grpcPort") : 7859
        self.drawThingsTransport = defaults.string(forKey: "drawthings.transport") ?? DrawThingsTransport.http.rawValue
        self.drawThingsSharedSecret = defaults.string(forKey: "drawthings.sharedSecret") ?? ""

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

    var drawThingsTransportType: DrawThingsTransport {
        DrawThingsTransport(rawValue: drawThingsTransport) ?? .http
    }

    /// Creates a Draw Things client based on current settings
    func createDrawThingsClient() -> any DrawThingsProvider {
        switch drawThingsTransportType {
        case .http:
            return DrawThingsHTTPClient(
                host: drawThingsHost,
                port: drawThingsHTTPPort,
                sharedSecret: drawThingsSharedSecret
            )
        case .grpc:
            return DrawThingsGRPCClient(
                host: drawThingsHost,
                port: drawThingsGRPCPort
            )
        }
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
                port: janPort,
                apiKey: janAPIKey.isEmpty ? nil : janAPIKey
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
        janAPIKey = ""

        defaultWidth = 1024
        defaultHeight = 1024
        defaultSteps = 30
        defaultGuidanceScale = 7.5
        defaultShift = 0
        defaultSampler = ""
        defaultStyle = "creative"

        drawThingsHost = "127.0.0.1"
        drawThingsHTTPPort = 7860
        drawThingsGRPCPort = 7859
        drawThingsTransport = DrawThingsTransport.http.rawValue
        drawThingsSharedSecret = ""

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
    @State private var showAPIKey = false
    @State private var testingDTConnection = false
    @State private var dtConnectionResult: String?
    @State private var showSharedSecret = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // LLM Provider
                neuSettingsSection("LLM Provider", icon: "brain") {
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
                        Button("Test Connection") { testConnection() }
                            .buttonStyle(NeumorphicButtonStyle())
                            .disabled(testingConnection)

                        if testingConnection {
                            ProgressView().scaleEffect(0.7)
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
                    neuSettingsSection("Ollama Settings", icon: "server.rack") {
                        neuSettingsRow("Host") { TextField("", text: $settings.ollamaHost).textFieldStyle(NeumorphicTextFieldStyle()) }
                        neuSettingsRow("Port") { TextField("", value: $settings.ollamaPort, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 100) }
                        neuSettingsRow("Model") { TextField("", text: $settings.ollamaDefaultModel).textFieldStyle(NeumorphicTextFieldStyle()) }
                        Toggle("Auto-connect on launch", isOn: $settings.ollamaAutoConnect)
                            .tint(Color.neuAccent)
                    }
                }

                if settings.providerType == .lmStudio {
                    neuSettingsSection("LM Studio Settings", icon: "desktopcomputer") {
                        neuSettingsRow("Host") { TextField("", text: $settings.lmStudioHost).textFieldStyle(NeumorphicTextFieldStyle()) }
                        neuSettingsRow("Port") { TextField("", value: $settings.lmStudioPort, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 100) }
                        Text("OpenAI-compatible API on port 1234 by default.")
                            .font(.caption).foregroundColor(.neuTextSecondary)
                    }
                }

                if settings.providerType == .jan {
                    neuSettingsSection("Jan Settings", icon: "bubble.left.and.bubble.right") {
                        neuSettingsRow("Host") { TextField("", text: $settings.janHost).textFieldStyle(NeumorphicTextFieldStyle()) }
                        neuSettingsRow("Port") { TextField("", value: $settings.janPort, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 100) }
                        neuSettingsRow("API Key") {
                            HStack {
                                if showAPIKey {
                                    TextField("", text: $settings.janAPIKey).textFieldStyle(NeumorphicTextFieldStyle())
                                } else {
                                    SecureField("", text: $settings.janAPIKey).textFieldStyle(NeumorphicTextFieldStyle())
                                }
                                Button(action: { showAPIKey.toggle() }) {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye").foregroundColor(.neuTextSecondary)
                                }.buttonStyle(NeumorphicIconButtonStyle())
                            }
                        }
                    }
                }

                // Draw Things Connection
                neuSettingsSection("Draw Things Connection", icon: "paintbrush.pointed") {
                    neuSettingsRow("Host") { TextField("", text: $settings.drawThingsHost).textFieldStyle(NeumorphicTextFieldStyle()) }
                    neuSettingsRow("HTTP Port") { TextField("", value: $settings.drawThingsHTTPPort, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 100) }
                    neuSettingsRow("gRPC Port") { TextField("", value: $settings.drawThingsGRPCPort, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 100) }

                    Picker("Transport", selection: $settings.drawThingsTransport) {
                        ForEach(DrawThingsTransport.allCases) { transport in
                            Text(transport.displayName).tag(transport.rawValue)
                        }
                    }

                    neuSettingsRow("Secret") {
                        HStack {
                            if showSharedSecret {
                                TextField("", text: $settings.drawThingsSharedSecret).textFieldStyle(NeumorphicTextFieldStyle())
                            } else {
                                SecureField("", text: $settings.drawThingsSharedSecret).textFieldStyle(NeumorphicTextFieldStyle())
                            }
                            Button(action: { showSharedSecret.toggle() }) {
                                Image(systemName: showSharedSecret ? "eye.slash" : "eye").foregroundColor(.neuTextSecondary)
                            }.buttonStyle(NeumorphicIconButtonStyle())
                        }
                    }

                    Text("Enable API in Draw Things: Settings > API Server")
                        .font(.caption).foregroundColor(.neuTextSecondary)

                    HStack {
                        Button("Test Connection") { testDTConnection() }
                            .buttonStyle(NeumorphicButtonStyle())
                            .disabled(testingDTConnection)

                        if testingDTConnection {
                            ProgressView().scaleEffect(0.7)
                        }
                        if let result = dtConnectionResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("Success") ? .green : .red)
                        }
                    }
                }

                // Default Generation Settings
                neuSettingsSection("Default Generation", icon: "slider.horizontal.3") {
                    HStack(spacing: 12) {
                        neuSettingsRow("Width") { TextField("", value: $settings.defaultWidth, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 80) }
                        neuSettingsRow("Height") { TextField("", value: $settings.defaultHeight, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 80) }
                    }
                    HStack(spacing: 12) {
                        neuSettingsRow("Steps") { TextField("", value: $settings.defaultSteps, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 80) }
                        neuSettingsRow("Guidance") { TextField("", value: $settings.defaultGuidanceScale, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 80) }
                    }
                    neuSettingsRow("Shift") { TextField("", value: $settings.defaultShift, format: .number).textFieldStyle(NeumorphicTextFieldStyle()).frame(width: 80) }
                    neuSettingsRow("Sampler") { TextField("e.g., DPM++ 2M Karras", text: $settings.defaultSampler).textFieldStyle(NeumorphicTextFieldStyle()) }

                    Picker("Style", selection: $settings.defaultStyle) {
                        ForEach(PromptStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                }

                // Interface
                neuSettingsSection("Interface", icon: "paintpalette") {
                    Toggle("Show validation warnings", isOn: $settings.showValidationWarnings)
                        .tint(Color.neuAccent)
                    Toggle("Compact JSON format", isOn: $settings.compactJSON)
                        .tint(Color.neuAccent)
                }

                // Reset
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
                .buttonStyle(NeumorphicButtonStyle())
            }
            .padding(24)
        }
        .neuBackground()
        .frame(width: 480, height: 700)
    }

    // MARK: - Neumorphic Settings Helpers

    private func neuSettingsSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NeuSectionHeader(title, icon: icon)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .neuCard(cornerRadius: 16)
        }
    }

    private func neuSettingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            content()
        }
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

    private func testDTConnection() {
        testingDTConnection = true
        dtConnectionResult = nil

        Task {
            let client = settings.createDrawThingsClient()
            let success = await client.checkConnection()

            await MainActor.run {
                testingDTConnection = false
                dtConnectionResult = success ? "Success! Connected to Draw Things" : "Failed to connect"
            }
        }
    }
}
