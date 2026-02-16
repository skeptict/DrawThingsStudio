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

            for (idx, img) in images.enumerated() {
                NSLog("[gRPC] Image %d: %dx%d pixels", idx, img.pixelWidth, img.pixelHeight)
            }
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
        cachedEchoReply = nil // Force fresh fetch
        let echoReply = try await fetchEchoReply()

        // Strategy 1: Check if files array contains model filenames
        let modelExtensions = [".ckpt", ".safetensors"]
        let filesModels = echoReply.files.filter { file in
            let lower = file.lowercased()
            return modelExtensions.contains(where: { lower.hasSuffix($0) }) &&
                   !lower.contains("lora") // Exclude LoRAs from model list
        }

        if !filesModels.isEmpty {
            NSLog("[gRPC] Found %d models from files array", filesModels.count)
            return filesModels.map { DrawThingsModel(filename: $0) }
        }

        // Strategy 2: Parse binary override data
        if echoReply.hasOverride && !echoReply.override.models.isEmpty {
            let modelNames = extractStrings(from: echoReply.override.models, withExtensions: modelExtensions)
            if !modelNames.isEmpty {
                NSLog("[gRPC] Found %d models from override binary (%d bytes)", modelNames.count, echoReply.override.models.count)
                return modelNames.map { DrawThingsModel(filename: $0) }
            }
        }

        NSLog("[gRPC] No models found - files: %d, override.models: %d bytes",
              echoReply.files.count, echoReply.override.models.count)
        return []
    }

    // MARK: - Fetch LoRAs

    func fetchLoRAs() async throws -> [DrawThingsLoRA] {
        let echoReply = try await fetchEchoReply()

        // Strategy 1: Check if files array contains LoRA filenames
        let loraExtensions = [".safetensors", ".ckpt"]
        let filesLoRAs = echoReply.files.filter { file in
            let lower = file.lowercased()
            return lower.contains("lora") && loraExtensions.contains(where: { lower.hasSuffix($0) })
        }

        if !filesLoRAs.isEmpty {
            NSLog("[gRPC] Found %d LoRAs from files array", filesLoRAs.count)
            return filesLoRAs.map { DrawThingsLoRA(filename: $0) }
        }

        // Strategy 2: Parse binary override data
        if echoReply.hasOverride && !echoReply.override.loras.isEmpty {
            let loraNames = extractStrings(from: echoReply.override.loras, withExtensions: loraExtensions)
            if !loraNames.isEmpty {
                NSLog("[gRPC] Found %d LoRAs from override binary (%d bytes)", loraNames.count, echoReply.override.loras.count)
                return loraNames.map { DrawThingsLoRA(filename: $0) }
            }
        }

        NSLog("[gRPC] No LoRAs found - files: %d, override.loras: %d bytes",
              echoReply.files.count, echoReply.override.loras.count)
        return []
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
            debug += "Files:\n"
            for file in reply.files.prefix(50) {
                debug += "  - \(file)\n"
            }
            if reply.files.count > 50 {
                debug += "  ... and \(reply.files.count - 50) more\n"
            }
        }
        debug += "hasOverride: \(reply.hasOverride)\n"
        if reply.hasOverride {
            let ov = reply.override
            debug += "Override bytes - models: \(ov.models.count), loras: \(ov.loras.count), controlNets: \(ov.controlNets.count), TIs: \(ov.textualInversions.count), upscalers: \(ov.upscalers.count)\n"

            // Try to extract strings and show what we found
            let modelExts = [".ckpt", ".safetensors"]
            if !ov.models.isEmpty {
                let extracted = extractStrings(from: ov.models, withExtensions: modelExts)
                debug += "Extracted \(extracted.count) model names from binary:\n"
                for name in extracted.prefix(20) {
                    debug += "  - \(name)\n"
                }
                if extracted.count > 20 {
                    debug += "  ... and \(extracted.count - 20) more\n"
                }
                // Also show hex preview
                let preview = ov.models.prefix(100).map { String(format: "%02x", $0) }.joined(separator: " ")
                debug += "Models hex preview (first 100 bytes): \(preview)\n"
            }

            if !ov.loras.isEmpty {
                let extracted = extractStrings(from: ov.loras, withExtensions: modelExts)
                debug += "Extracted \(extracted.count) LoRA names from binary:\n"
                for name in extracted.prefix(20) {
                    debug += "  - \(name)\n"
                }
                if extracted.count > 20 {
                    debug += "  ... and \(extracted.count - 20) more\n"
                }
                // Also show hex preview
                let preview = ov.loras.prefix(100).map { String(format: "%02x", $0) }.joined(separator: " ")
                debug += "LoRAs hex preview (first 100 bytes): \(preview)\n"
            }
        }
        let debugURL = URL(fileURLWithPath: "/tmp/dts_grpc_debug.log")
        try? debug.write(to: debugURL, atomically: true, encoding: .utf8)
        NSLog("[gRPC] Debug written to /tmp/dts_grpc_debug.log")

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

        // Strategy 1: Scan for uint32 length-prefixed strings (FlatBuffer format)
        var i = 0
        while i < bytes.count - 4 {
            let len = Int(bytes[i]) | (Int(bytes[i+1]) << 8) | (Int(bytes[i+2]) << 16) | (Int(bytes[i+3]) << 24)

            // Reasonable string length (1-500 chars) and must fit in remaining data
            if len > 0 && len < 500 && i + 4 + len <= bytes.count {
                if let str = String(bytes: bytes[(i+4)..<(i+4+len)], encoding: .utf8) {
                    let lower = str.lowercased()
                    if extensions.contains(where: { lower.hasSuffix($0) }) && !results.contains(str) {
                        results.append(str)
                        // Skip past this string to avoid re-matching
                        i += 4 + len
                        continue
                    }
                }
            }
            i += 1
        }

        // Strategy 2: If no results, try scanning for null-terminated strings
        if results.isEmpty {
            var currentString = Data()
            for byte in bytes {
                if byte == 0 {
                    if let str = String(data: currentString, encoding: .utf8), !str.isEmpty {
                        let lower = str.lowercased()
                        if extensions.contains(where: { lower.hasSuffix($0) }) && !results.contains(str) {
                            results.append(str)
                        }
                    }
                    currentString = Data()
                } else if byte >= 32 && byte < 127 { // Printable ASCII
                    currentString.append(byte)
                } else {
                    currentString = Data() // Reset on non-printable
                }
            }
        }

        // Strategy 3: If still no results, try to find extension patterns in raw bytes
        if results.isEmpty {
            let dataString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
            // Use regex to find potential filenames
            let pattern = "[a-zA-Z0-9_\\-./]+\\.(?:safetensors|ckpt)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(dataString.startIndex..., in: dataString)
                let matches = regex.matches(in: dataString, range: range)
                for match in matches {
                    if let swiftRange = Range(match.range, in: dataString) {
                        let filename = String(dataString[swiftRange])
                        if !results.contains(filename) {
                            results.append(filename)
                        }
                    }
                }
            }
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

        // Detect model family to set appropriate text encoder and shift defaults
        let modelFamily = LatentModelFamily.detect(from: config.model)
        let useT5: Bool
        let useResolutionDependentShift: Bool
        switch modelFamily {
        case .flux, .zImage:
            useT5 = true
            useResolutionDependentShift = true
        case .sd3:
            useT5 = true
            useResolutionDependentShift = false
        default:
            useT5 = false
            useResolutionDependentShift = false
        }

        NSLog("[gRPC] Model: %@, detected family: %@, t5=%d, resDependentShift=%d",
              config.model, modelFamily.rawValue, useT5 ? 1 : 0, useResolutionDependentShift ? 1 : 0)

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
            stochasticSamplingGamma: Float(config.stochasticSamplingGamma),
            resolutionDependentShift: useResolutionDependentShift,
            t5TextEncoder: useT5,
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
        let normalized = mode.lowercased().replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "legacy":
            return 0
        case "torchcpucompatible":
            return 1
        case "scalealike":
            return 2
        case "nvidiagpucompatible":
            return 3
        default:
            return 2 // Default to Scale Alike
        }
    }
}
