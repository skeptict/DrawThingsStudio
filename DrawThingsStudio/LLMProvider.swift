//
//  LLMProvider.swift
//  DrawThingsStudio
//
//  Protocol and types for LLM provider abstraction
//

import Foundation

// MARK: - LLM Provider Protocol

/// Protocol for LLM providers (Ollama, LM Studio, etc.)
protocol LLMProvider {
    /// Generate text from a prompt
    func generateText(prompt: String) async throws -> String

    /// Generate text with streaming callback
    func generateTextStreaming(prompt: String, onToken: @escaping (String) -> Void) async throws -> String

    /// List available models
    func listModels() async throws -> [LLMModel]

    /// Check if the provider is available/connected
    func checkConnection() async -> Bool

    /// Provider name for display
    var providerName: String { get }

    /// Default model name
    var defaultModel: String { get set }
}

// MARK: - LLM Model

/// Represents an available LLM model
struct LLMModel: Identifiable, Codable {
    var id: String { name }
    let name: String
    let size: Int64?
    let modifiedAt: Date?
    let digest: String?

    init(name: String, size: Int64? = nil, modifiedAt: Date? = nil, digest: String? = nil) {
        self.name = name
        self.size = size
        self.modifiedAt = modifiedAt
        self.digest = digest
    }

    /// Formatted size string
    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Generation Options

/// Options for text generation
struct LLMGenerationOptions {
    var temperature: Float = 0.8
    var topP: Float = 0.9
    var maxTokens: Int = 500
    var stream: Bool = false

    static let `default` = LLMGenerationOptions()

    static let creative = LLMGenerationOptions(temperature: 0.9, topP: 0.95, maxTokens: 600)
    static let precise = LLMGenerationOptions(temperature: 0.3, topP: 0.8, maxTokens: 400)
}

// MARK: - Prompt Styles

/// Predefined prompt styles for different generation needs
enum PromptStyle: String, CaseIterable, Identifiable {
    case creative
    case technical
    case photorealistic
    case artistic
    case cinematic
    case anime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .creative: return "Creative"
        case .technical: return "Technical"
        case .photorealistic: return "Photorealistic"
        case .artistic: return "Artistic"
        case .cinematic: return "Cinematic"
        case .anime: return "Anime/Illustration"
        }
    }

    var systemPrompt: String {
        switch self {
        case .creative:
            return """
            You are an expert at creating detailed, imaginative prompts for AI image generation.
            Focus on vivid descriptions, artistic style, mood, lighting, and composition.
            Keep prompts clear and under 200 words. Output only the prompt, no explanations.
            """
        case .technical:
            return """
            Create precise, technical prompts for AI image generation.
            Include specific details about camera angles, lighting setups, materials, and rendering style.
            Be concise and technical. Output only the prompt, no explanations.
            """
        case .photorealistic:
            return """
            Generate prompts for photorealistic image generation.
            Include camera settings (lens, aperture), lighting conditions, time of day, and realistic details.
            Focus on achieving photographic quality. Output only the prompt, no explanations.
            """
        case .artistic:
            return """
            Create artistic prompts inspired by famous art movements and styles.
            Reference specific artists, techniques, and artistic periods when appropriate.
            Focus on artistic expression and style. Output only the prompt, no explanations.
            """
        case .cinematic:
            return """
            Generate cinematic prompts suitable for film-like imagery.
            Include cinematic lighting, dramatic composition, color grading style, and mood.
            Think like a cinematographer. Output only the prompt, no explanations.
            """
        case .anime:
            return """
            Create prompts for anime/illustration style images.
            Include art style references (e.g., studio ghibli, makoto shinkai), character details, and scene composition.
            Focus on anime aesthetics. Output only the prompt, no explanations.
            """
        }
    }

    var icon: String {
        switch self {
        case .creative: return "paintpalette"
        case .technical: return "gearshape.2"
        case .photorealistic: return "camera"
        case .artistic: return "paintbrush"
        case .cinematic: return "film"
        case .anime: return "sparkles"
        }
    }
}

// MARK: - LLM Errors

/// Errors that can occur during LLM operations
enum LLMError: LocalizedError {
    case connectionFailed(String)
    case requestFailed(String)
    case invalidResponse
    case modelNotFound(String)
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let details):
            return "Connection failed: \(details)"
        case .requestFailed(let details):
            return "Request failed: \(details)"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .modelNotFound(let model):
            return "Model '\(model)' not found"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}

// MARK: - Provider Type

/// Supported LLM provider types
enum LLMProviderType: String, CaseIterable, Identifiable {
    case ollama
    case lmStudio
    case mstyStudio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        case .mstyStudio: return "Msty Studio"
        }
    }

    var defaultPort: Int {
        switch self {
        case .ollama: return 11434
        case .lmStudio: return 1234
        case .mstyStudio: return 10000
        }
    }

    var icon: String {
        switch self {
        case .ollama: return "server.rack"
        case .lmStudio: return "desktopcomputer"
        case .mstyStudio: return "sparkle"
        }
    }
}

// MARK: - Connection Status

/// Status of LLM provider connection
enum LLMConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var statusColor: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "yellow"
        case .connected: return "green"
        case .error: return "red"
        }
    }
}
