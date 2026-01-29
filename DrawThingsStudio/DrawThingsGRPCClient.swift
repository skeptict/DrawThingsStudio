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
            print("[gRPC] Connection error: \(error)")
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
        print("[gRPC] Starting \(isImg2Img ? "img2img" : "txt2img") generation")

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

            print("[gRPC] Generated \(images.count) image(s) via \(isImg2Img ? "img2img" : "txt2img")")

            // PlatformImage is NSImage on macOS, so we can return directly
            return images

        } catch {
            onProgress?(.failed(error.localizedDescription))
            throw DrawThingsError.requestFailed(-1, error.localizedDescription)
        }
    }

    // MARK: - Fetch Models

    func fetchModels() async throws -> [DrawThingsModel] {
        let files = try await fetchFileList()

        // Filter for model files (not LoRAs, control nets, etc.)
        let modelExtensions = [".ckpt", ".safetensors", ".bin"]
        let loraIndicators = ["/loras/", "/lora/", "lora_", "_lora"]

        let modelFiles = files.filter { file in
            let lower = file.lowercased()
            let hasModelExtension = modelExtensions.contains { lower.hasSuffix($0) }
            let isLora = loraIndicators.contains { lower.contains($0) }
            return hasModelExtension && !isLora
        }

        let models = modelFiles.map { DrawThingsModel(filename: $0) }
        print("[gRPC] Found \(models.count) models from echo files (\(files.count) total files)")
        return models
    }

    // MARK: - Fetch LoRAs

    func fetchLoRAs() async throws -> [DrawThingsLoRA] {
        let files = try await fetchFileList()

        // Filter for LoRA files
        let loraIndicators = ["/loras/", "/lora/", "lora_", "_lora"]
        let modelExtensions = [".ckpt", ".safetensors", ".bin"]

        let loraFiles = files.filter { file in
            let lower = file.lowercased()
            let hasModelExtension = modelExtensions.contains { lower.hasSuffix($0) }
            let isLora = loraIndicators.contains { lower.contains($0) }
            return hasModelExtension && isLora
        }

        let loras = loraFiles.map { DrawThingsLoRA(filename: $0) }
        print("[gRPC] Found \(loras.count) LoRAs from echo files")
        return loras
    }

    // MARK: - Echo File List

    private func fetchFileList() async throws -> [String] {
        let address = "\(host):\(port)"

        if service == nil {
            service = try DrawThingsService(address: address, useTLS: true)
        }

        guard let service = service else {
            throw DrawThingsError.connectionFailed("Failed to create gRPC service")
        }

        let echoReply = try await service.echo()
        return echoReply.files
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
