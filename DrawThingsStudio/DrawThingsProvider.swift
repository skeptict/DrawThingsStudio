//
//  DrawThingsProvider.swift
//  DrawThingsStudio
//
//  Protocol and types for Draw Things image generation backends
//

import Foundation
import AppKit

// MARK: - Transport Type

enum DrawThingsTransport: String, CaseIterable, Identifiable {
    case http
    case grpc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .http: return "HTTP"
        case .grpc: return "gRPC"
        }
    }

    var defaultPort: Int {
        switch self {
        case .http: return 7860
        case .grpc: return 7859
        }
    }
}

// MARK: - Generated Image

struct GeneratedImage: Identifiable {
    let id: UUID
    let image: NSImage
    let prompt: String
    let negativePrompt: String
    let config: DrawThingsGenerationConfig
    let generatedAt: Date
    let inferenceTimeMs: Int?
    let filePath: URL?

    init(
        id: UUID = UUID(),
        image: NSImage,
        prompt: String,
        negativePrompt: String = "",
        config: DrawThingsGenerationConfig,
        generatedAt: Date = Date(),
        inferenceTimeMs: Int? = nil,
        filePath: URL? = nil
    ) {
        self.id = id
        self.image = image
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.config = config
        self.generatedAt = generatedAt
        self.inferenceTimeMs = inferenceTimeMs
        self.filePath = filePath
    }
}

// MARK: - Generation Config

struct DrawThingsGenerationConfig: Codable {
    var width: Int
    var height: Int
    var steps: Int
    var guidanceScale: Double
    var seed: Int
    var seedMode: String
    var sampler: String
    var model: String
    var shift: Double
    var strength: Double
    var batchSize: Int
    var batchCount: Int
    var negativePrompt: String
    var loras: [LoRAConfig]

    struct LoRAConfig: Codable {
        var file: String
        var weight: Double
        var mode: String

        init(file: String, weight: Double = 1.0, mode: String = "all") {
            self.file = file
            self.weight = weight
            self.mode = mode
        }
    }

    init(
        width: Int = 1024,
        height: Int = 1024,
        steps: Int = 8,
        guidanceScale: Double = 1.0,
        seed: Int = -1,
        seedMode: String = "Scale Alike",
        sampler: String = "UniPC Trailing",
        model: String = "",
        shift: Double = 3.0,
        strength: Double = 1.0,
        batchSize: Int = 1,
        batchCount: Int = 1,
        negativePrompt: String = "",
        loras: [LoRAConfig] = []
    ) {
        self.width = width
        self.height = height
        self.steps = steps
        self.guidanceScale = guidanceScale
        self.seed = seed
        self.seedMode = seedMode
        self.sampler = sampler
        self.model = model
        self.shift = shift
        self.strength = strength
        self.batchSize = batchSize
        self.batchCount = batchCount
        self.negativePrompt = negativePrompt
        self.loras = loras
    }

    /// Convert to HTTP API request body dictionary
    func toRequestBody(prompt: String) -> [String: Any] {
        var body: [String: Any] = [
            "prompt": prompt,
            "negative_prompt": negativePrompt,
            "width": width,
            "height": height,
            "steps": steps,
            "guidance_scale": guidanceScale,
            "seed": seed,
            "seed_mode": seedMode,
            "sampler": sampler,
            "shift": shift,
            "strength": strength,
            "batch_size": batchSize,
            "batch_count": batchCount
        ]

        if !model.isEmpty {
            body["model"] = model
        }

        if !loras.isEmpty {
            body["loras"] = loras.map { lora in
                ["file": lora.file, "weight": lora.weight, "mode": lora.mode] as [String: Any]
            }
        }

        return body
    }
}

// MARK: - Generation Progress

enum GenerationProgress {
    case starting
    case sampling(step: Int, totalSteps: Int)
    case decoding
    case complete
    case failed(String)

    var description: String {
        switch self {
        case .starting: return "Starting..."
        case .sampling(let step, let total): return "Sampling \(step)/\(total)"
        case .decoding: return "Decoding image..."
        case .complete: return "Complete"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }

    var fraction: Double {
        switch self {
        case .starting: return 0.0
        case .sampling(let step, let total): return Double(step) / Double(max(total, 1))
        case .decoding: return 0.95
        case .complete: return 1.0
        case .failed: return 0.0
        }
    }
}

// MARK: - Connection Status

enum DrawThingsConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var color: String {
        switch self {
        case .disconnected: return "secondary"
        case .connecting: return "orange"
        case .connected: return "green"
        case .error: return "red"
        }
    }
}

// MARK: - Errors

enum DrawThingsError: LocalizedError {
    case connectionFailed(String)
    case requestFailed(Int, String)
    case invalidResponse
    case imageDecodingFailed
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .requestFailed(let code, let msg): return "Request failed (\(code)): \(msg)"
        case .invalidResponse: return "Invalid response from Draw Things"
        case .imageDecodingFailed: return "Failed to decode generated image"
        case .timeout: return "Request timed out"
        case .cancelled: return "Generation cancelled"
        }
    }
}

// MARK: - Provider Protocol

protocol DrawThingsProvider: AnyObject {
    var transport: DrawThingsTransport { get }
    func checkConnection() async -> Bool

    /// Generate image(s) with optional source image for img2img
    /// - Parameters:
    ///   - prompt: The generation prompt
    ///   - sourceImage: Optional source image for img2img (nil = txt2img)
    ///   - mask: Optional mask for inpainting
    ///   - config: Generation configuration
    ///   - onProgress: Progress callback
    /// - Returns: Array of generated images
    func generateImage(
        prompt: String,
        sourceImage: NSImage?,
        mask: NSImage?,
        config: DrawThingsGenerationConfig,
        onProgress: ((GenerationProgress) -> Void)?
    ) async throws -> [NSImage]
}

// MARK: - Protocol Extension for Convenience

extension DrawThingsProvider {
    /// Convenience method for txt2img (no source image)
    func generateImage(
        prompt: String,
        config: DrawThingsGenerationConfig,
        onProgress: ((GenerationProgress) -> Void)?
    ) async throws -> [NSImage] {
        try await generateImage(
            prompt: prompt,
            sourceImage: nil,
            mask: nil,
            config: config,
            onProgress: onProgress
        )
    }
}
