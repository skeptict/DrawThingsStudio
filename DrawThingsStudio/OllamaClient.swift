//
//  OllamaClient.swift
//  DrawThingsStudio
//
//  HTTP client for Ollama API
//

import Foundation
import Combine
import OSLog

/// Client for Ollama HTTP API
class OllamaClient: LLMProvider, ObservableObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "ollama")

    @Published var connectionStatus: LLMConnectionStatus = .disconnected
    @Published var availableModels: [LLMModel] = []

    var host: String
    var port: Int
    var defaultModel: String

    private var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    private let session: URLSession

    // MARK: - LLMProvider Protocol

    var providerName: String { "Ollama" }

    // MARK: - Initialization

    init(host: String = "localhost", port: Int = 11434, defaultModel: String = "llama3.2") {
        self.host = host
        self.port = port
        self.defaultModel = defaultModel

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection Check

    func checkConnection() async -> Bool {
        await MainActor.run {
            connectionStatus = .connecting
        }

        do {
            let url = baseURL.appendingPathComponent("api/tags")
            let (_, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    connectionStatus = .error("Invalid response")
                }
                return false
            }

            await MainActor.run {
                connectionStatus = .connected
            }
            logger.info("Connected to Ollama at \(self.host):\(self.port)")
            return true
        } catch {
            await MainActor.run {
                connectionStatus = .error(error.localizedDescription)
            }
            logger.error("Failed to connect to Ollama: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - List Models

    func listModels() async throws -> [LLMModel] {
        let url = baseURL.appendingPathComponent("api/tags")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.requestFailed("Failed to list models")
        }

        let result = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)

        let models = result.models.map { model in
            LLMModel(
                name: model.name,
                size: model.size,
                modifiedAt: parseDate(model.modifiedAt),
                digest: model.digest
            )
        }

        await MainActor.run {
            self.availableModels = models
        }

        return models
    }

    // MARK: - Generate Text

    func generateText(prompt: String) async throws -> String {
        try await generateText(prompt: prompt, model: defaultModel, options: .default)
    }

    func generateText(
        prompt: String,
        model: String,
        options: LLMGenerationOptions = .default
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": options.temperature,
                "top_p": options.topP,
                "num_predict": options.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        logger.debug("Generating text with model: \(model)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.requestFailed("Status \(httpResponse.statusCode): \(errorMessage)")
        }

        let result = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

        logger.debug("Generated \(result.response.count) characters")

        if result.response.isEmpty {
            logger.warning("Model '\(model)' returned empty response. Vision models (VL) require image input.")
            throw LLMError.requestFailed("Model returned empty response. If using a vision model (VL), try a text-only model instead.")
        }

        return result.response
    }

    // MARK: - Generate Text Streaming

    func generateTextStreaming(
        prompt: String,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        try await generateTextStreaming(prompt: prompt, model: defaultModel, options: .default, onToken: onToken)
    }

    func generateTextStreaming(
        prompt: String,
        model: String,
        options: LLMGenerationOptions = .default,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true,
            "options": [
                "temperature": options.temperature,
                "top_p": options.topP,
                "num_predict": options.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        logger.debug("Starting streaming generation with model: \(model)")

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.requestFailed("Streaming request failed")
        }

        var fullResponse = ""

        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8) else { continue }

            do {
                let chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
                fullResponse += chunk.response
                onToken(chunk.response)

                if chunk.done {
                    break
                }
            } catch {
                // Skip malformed chunks
                logger.warning("Failed to parse stream chunk: \(error.localizedDescription)")
            }
        }

        return fullResponse
    }

    // MARK: - Chat Completion

    func chat(
        messages: [ChatMessage],
        model: String? = nil,
        options: LLMGenerationOptions = .default
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("api/chat")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model ?? defaultModel,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": false,
            "options": [
                "temperature": options.temperature,
                "top_p": options.topP,
                "num_predict": options.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.requestFailed("Chat request failed")
        }

        let result = try JSONDecoder().decode(OllamaChatResponse.self, from: data)

        return result.message.content
    }

    // MARK: - Helpers

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
}

// MARK: - Chat Message

struct ChatMessage {
    let role: String
    let content: String

    static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: "system", content: content)
    }

    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: "user", content: content)
    }

    static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: "assistant", content: content)
    }
}

// MARK: - Ollama API Response Types

private struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

private struct OllamaModel: Codable {
    let name: String
    let size: Int64?
    let digest: String?
    let modifiedAt: String?

    enum CodingKeys: String, CodingKey {
        case name, size, digest
        case modifiedAt = "modified_at"
    }
}

private struct OllamaGenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
    let context: [Int]?
    let totalDuration: Int64?
    let loadDuration: Int64?
    let promptEvalCount: Int?
    let evalCount: Int?
    let evalDuration: Int64?

    enum CodingKeys: String, CodingKey {
        case model, response, done, context
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

private struct OllamaStreamChunk: Codable {
    let model: String
    let response: String
    let done: Bool
}

private struct OllamaChatResponse: Codable {
    let model: String
    let message: OllamaChatMessage
    let done: Bool
}

private struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}
