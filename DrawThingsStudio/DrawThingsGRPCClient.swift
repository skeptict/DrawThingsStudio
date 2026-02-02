//
//  DrawThingsGRPCClient.swift
//  DrawThingsStudio
//
//  gRPC client implementation for Draw Things using DT-gRPC-Swift-Client
//

import Foundation
import AppKit
import DrawThingsClient

/// gRPC-based client for Draw Things image generation
@MainActor
final class DrawThingsGRPCClient: DrawThingsProvider {

    let transport: DrawThingsTransport = .grpc

    private let host: String
    private let port: Int
    private var client: DrawThingsClient?
    private var service: DrawThingsService?

    init(host: String = "127.0.0.1", port: Int = 7859) {
        self.host = host
        self.port = port
    }

    // MARK: - Connection

    func checkConnection() async -> Bool {
        do {
            let address = "\(host):\(port)"
            client = try DrawThingsClient(address: address, useTLS: true)
            await client?.connect()
            return client?.isConnected ?? false
        } catch {
            NSLog("[gRPC] Connection error: \(error)")
            return false
        }
    }

    // MARK: - Image Generation

    func generateImage(
        prompt: String,
        sourceImage: NSImage?,
        mask: NSImage?,
        config: DrawThingsGenerationConfig,
        onProgress: ((GenerationProgress) -> Void)?
    ) async throws -> [NSImage] {

        // Ensure we have a connected client
        if client == nil || client?.isConnected != true {
            let connected = await checkConnection()
            guard connected else {
                throw DrawThingsError.connectionFailed("Failed to connect to Draw Things via gRPC")
            }
        }

        guard let client = client else {
            throw DrawThingsError.connectionFailed("No gRPC client available")
        }

        // Convert our config to DrawThingsConfiguration
        let grpcConfig = convertConfig(config)

        onProgress?(.starting)

        let isImg2Img = sourceImage != nil
        NSLog("[gRPC] Starting \(isImg2Img ? "img2img" : "txt2img") generation")

        do {
            // Generate the image - pass source image and mask if provided
            let images = try await client.generateImage(
                prompt: prompt,
                negativePrompt: config.negativePrompt,
                configuration: grpcConfig,
                image: sourceImage,
                mask: mask
            )

            onProgress?(.complete)

            NSLog("[gRPC] Generated \(images.count) image(s) via \(isImg2Img ? "img2img" : "txt2img")")

            // PlatformImage is NSImage on macOS, so we can return directly
            return images

        } catch {
            onProgress?(.failed(error.localizedDescription))
            throw DrawThingsError.requestFailed(-1, error.localizedDescription)
        }
    }

    // MARK: - Fetch Models

    func fetchModels() async throws -> [DrawThingsModel] {
        cachedEchoReply = nil // Force fresh fetch for debugging
        let echoReply = try await fetchEchoReply()
        let modelNames = extractStrings(from: echoReply.override.models, withExtensions: [".ckpt", ".safetensors"])
        let models = modelNames.map { DrawThingsModel(filename: $0) }
        NSLog("[gRPC] Found %d models from override (%d bytes)", models.count, echoReply.override.models.count)
        return models
    }

    // MARK: - Fetch LoRAs

    func fetchLoRAs() async throws -> [DrawThingsLoRA] {
        let echoReply = try await fetchEchoReply()
        let loraNames = extractStrings(from: echoReply.override.loras, withExtensions: [".ckpt", ".safetensors"])
        let loras = loraNames.map { DrawThingsLoRA(filename: $0) }
        NSLog("[gRPC] Found %d LoRAs from override (%d bytes)", loras.count, echoReply.override.loras.count)
        return loras
    }

    // MARK: - Echo

    private var cachedEchoReply: EchoReply?

    private func fetchEchoReply() async throws -> EchoReply {
        if let cached = cachedEchoReply {
            return cached
        }

        let address = "\(host):\(port)"
        if service == nil {
            service = try DrawThingsService(address: address, useTLS: true)
        }
        guard let service = service else {
            throw DrawThingsError.connectionFailed("Failed to create gRPC service")
        }

        let reply = try await service.echo()
        cachedEchoReply = reply

        // Write debug info to file since NSLog may not appear in unified log
        var debug = "[gRPC] Echo debug at \(Date())\n"
        debug += "Message: \(reply.message)\n"
        debug += "Files count: \(reply.files.count)\n"
        if !reply.files.isEmpty {
            debug += "Files: \(reply.files.joined(separator: ", "))\n"
        }
        debug += "hasOverride: \(reply.hasOverride)\n"
        if reply.hasOverride {
            let ov = reply.override
            debug += "Override bytes - models: \(ov.models.count), loras: \(ov.loras.count), controlNets: \(ov.controlNets.count), TIs: \(ov.textualInversions.count), upscalers: \(ov.upscalers.count)\n"
            // Dump first 200 bytes of models data as hex for analysis
            if !ov.models.isEmpty {
                let preview = ov.models.prefix(200).map { String(format: "%02x", $0) }.joined(separator: " ")
                debug += "Models hex preview: \(preview)\n"
            }
            if !ov.loras.isEmpty {
                let preview = ov.loras.prefix(200).map { String(format: "%02x", $0) }.joined(separator: " ")
                debug += "LoRAs hex preview: \(preview)\n"
            }
        }
        let debugURL = URL(fileURLWithPath: "/tmp/dts_grpc_debug.log")
        try? debug.write(to: debugURL, atomically: true, encoding: .utf8)

        return reply
    }

    // MARK: - FlatBuffer String Extraction

    /// Extract readable filenames from FlatBuffer binary data.
    /// FlatBuffer strings are stored as: [uint32 length][utf8 bytes][null terminator]
    /// We scan for strings that end with known file extensions.
    private func extractStrings(from data: Data, withExtensions extensions: [String]) -> [String] {
        guard data.count > 4 else { return [] }

        var results: [String] = []
        let bytes = [UInt8](data)

        // Scan for uint32 length-prefixed strings
        var i = 0
        while i < bytes.count - 4 {
            let len = Int(bytes[i]) | (Int(bytes[i+1]) << 8) | (Int(bytes[i+2]) << 16) | (Int(bytes[i+3]) << 24)

            // Reasonable string length (1-500 chars) and must fit in remaining data
            if len > 0 && len < 500 && i + 4 + len <= bytes.count {
                if let str = String(bytes: bytes[(i+4)..<(i+4+len)], encoding: .utf8) {
                    let lower = str.lowercased()
                    if extensions.contains(where: { lower.hasSuffix($0) }) && !results.contains(str) {
                        results.append(str)
                    }
                }
            }
            i += 1
        }

        return results.sorted()
    }

    // MARK: - Config Conversion

    private func convertConfig(_ config: DrawThingsGenerationConfig) -> DrawThingsConfiguration {
        // Map sampler string to SamplerType
        let sampler = mapSampler(config.sampler)

        // Convert LoRAs
        let loras = config.loras.map { lora in
            LoRAConfig(
                file: lora.file,
                weight: Float(lora.weight),
                mode: mapLoRAMode(lora.mode)
            )
        }

        return DrawThingsConfiguration(
            width: Int32(config.width),
            height: Int32(config.height),
            steps: Int32(config.steps),
            model: config.model,
            sampler: sampler,
            guidanceScale: Float(config.guidanceScale),
            seed: config.seed >= 0 ? Int64(config.seed) : nil,
            loras: loras,
            shift: Float(config.shift),
            batchCount: Int32(config.batchCount),
            batchSize: Int32(config.batchSize),
            strength: Float(config.strength),
            seedMode: mapSeedMode(config.seedMode)
        )
    }

    private func mapSampler(_ name: String) -> SamplerType {
        let lowercased = name.lowercased().replacingOccurrences(of: " ", with: "")

        switch lowercased {
        case "dpm++2mkarras", "dpmpp2mkarras":
            return .dpmpp2mkarras
        case "eulera", "euler_a":
            return .eulera
        case "ddim":
            return .ddim
        case "plms":
            return .plms
        case "dpm++sdekarras", "dpmppsdekarras":
            return .dpmppsdekarras
        case "unipc":
            return .unipc
        case "lcm":
            return .lcm
        case "eulerasubstep":
            return .eulerasubstep
        case "dpm++sdesubstep", "dpmppsdesubstep":
            return .dpmppsdesubstep
        case "tcd":
            return .tcd
        case "euleratrailing", "euler_a_trailing":
            return .euleratrailing
        case "dpm++sdetrailing", "dpmppsdetrailing":
            return .dpmppsdetrailing
        case "dpm++2mays", "dpmpp2mays":
            return .dpmpp2mays
        case "euleraays":
            return .euleraays
        case "dpm++sdeays", "dpmppsdeays":
            return .dpmppsdeays
        case "dpm++2mtrailing", "dpmpp2mtrailing":
            return .dpmpp2mtrailing
        case "ddimtrailing":
            return .ddimtrailing
        case "unipctrailing":
            return .unipctrailing
        case "unipcays":
            return .unipcays
        default:
            // Default to DPM++ 2M Karras
            return .dpmpp2mkarras
        }
    }

    private func mapLoRAMode(_ mode: String) -> LoRAMode {
        switch mode.lowercased() {
        case "all":
            return .all
        case "base":
            return .base
        case "refiner":
            return .refiner
        default:
            return .all
        }
    }

    private func mapSeedMode(_ mode: String) -> Int32 {
        switch mode.lowercased() {
        case "legacy":
            return 0
        case "torchcpucompatible", "torch_cpu_compatible":
            return 1
        case "scalealike", "scale_alike":
            return 2
        case "nvidiatorchcompatible", "nvidia_torch_compatible":
            return 3
        default:
            return 2 // Default to Scale Alike
        }
    }
}
