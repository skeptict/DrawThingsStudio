//
//  ConfigPresetsManager.swift
//  DrawThingsStudio
//
//  JSON file-based storage for config presets, compatible with Draw Things
//

import Foundation
import SwiftData
import OSLog

// MARK: - Draw Things Config Format

/// Draw Things custom_configs.json format
struct DrawThingsConfigFile: Codable {
    let name: String
    let configuration: DrawThingsConfigData
}

/// The configuration data inside a Draw Things config
struct DrawThingsConfigData: Codable {
    // Core settings we care about
    var targetImageWidth: Int?
    var targetImageHeight: Int?
    var steps: Int?
    var guidanceScale: Double?
    var sampler: Int?
    var shift: Double?
    var strength: Double?
    var clipSkip: Int?
    var seed: Int?
    var model: String?
    var batchCount: Int?
    var batchSize: Int?

    // We preserve other fields when round-tripping
    var additionalFields: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case targetImageWidth, targetImageHeight, steps, guidanceScale
        case sampler, shift, strength, clipSkip, seed, model
        case batchCount, batchSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetImageWidth = try container.decodeIfPresent(Int.self, forKey: .targetImageWidth)
        targetImageHeight = try container.decodeIfPresent(Int.self, forKey: .targetImageHeight)
        steps = try container.decodeIfPresent(Int.self, forKey: .steps)
        guidanceScale = try container.decodeIfPresent(Double.self, forKey: .guidanceScale)
        sampler = try container.decodeIfPresent(Int.self, forKey: .sampler)
        shift = try container.decodeIfPresent(Double.self, forKey: .shift)
        strength = try container.decodeIfPresent(Double.self, forKey: .strength)
        clipSkip = try container.decodeIfPresent(Int.self, forKey: .clipSkip)
        seed = try container.decodeIfPresent(Int.self, forKey: .seed)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        batchCount = try container.decodeIfPresent(Int.self, forKey: .batchCount)
        batchSize = try container.decodeIfPresent(Int.self, forKey: .batchSize)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(targetImageWidth, forKey: .targetImageWidth)
        try container.encodeIfPresent(targetImageHeight, forKey: .targetImageHeight)
        try container.encodeIfPresent(steps, forKey: .steps)
        try container.encodeIfPresent(guidanceScale, forKey: .guidanceScale)
        try container.encodeIfPresent(sampler, forKey: .sampler)
        try container.encodeIfPresent(shift, forKey: .shift)
        try container.encodeIfPresent(strength, forKey: .strength)
        try container.encodeIfPresent(clipSkip, forKey: .clipSkip)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(batchCount, forKey: .batchCount)
        try container.encodeIfPresent(batchSize, forKey: .batchSize)
    }
}

// MARK: - Studio Config Format (our native format)

/// Our native config preset format
struct StudioConfigPreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var modelName: String
    var description: String
    var width: Int
    var height: Int
    var steps: Int
    var guidanceScale: Float
    var samplerName: String
    var shift: Float?
    var clipSkip: Int?
    var strength: Float?
    var isBuiltIn: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(from modelConfig: ModelConfig) {
        self.id = modelConfig.id
        self.name = modelConfig.name
        self.modelName = modelConfig.modelName
        self.description = modelConfig.configDescription
        self.width = modelConfig.width
        self.height = modelConfig.height
        self.steps = modelConfig.steps
        self.guidanceScale = modelConfig.guidanceScale
        self.samplerName = modelConfig.samplerName
        self.shift = modelConfig.shift
        self.clipSkip = modelConfig.clipSkip
        self.strength = modelConfig.strength
        self.isBuiltIn = modelConfig.isBuiltIn
        self.createdAt = modelConfig.createdAt
        self.modifiedAt = modelConfig.modifiedAt
    }

    func toModelConfig() -> ModelConfig {
        let config = ModelConfig(
            name: name,
            modelName: modelName,
            description: description,
            width: width,
            height: height,
            steps: steps,
            guidanceScale: guidanceScale,
            samplerName: samplerName,
            shift: shift,
            clipSkip: clipSkip,
            strength: strength,
            isBuiltIn: isBuiltIn
        )
        return config
    }
}

// MARK: - Sampler Mapping

/// Map Draw Things sampler integers to names
enum SamplerMapping {
    static let samplerNames: [Int: String] = [
        0: "PLMS",
        1: "DDIM",
        2: "DPM++ 2M Karras",
        3: "Euler A",
        4: "DPM++ SDE Karras",
        5: "UniPC",
        6: "LCM",
        7: "Euler A Substep",
        8: "DPM++ SDE Substep",
        9: "TCD",
        10: "Euler A Trailing",
        11: "DPM++ SDE Trailing",
        12: "DDIM Trailing",
        13: "DPM++ 2M AYS",
        14: "Euler A AYS",
        15: "DPM++ 2M Trailing",
        16: "DPM++ 2M",
    ]

    static func name(for index: Int) -> String {
        samplerNames[index] ?? "DPM++ 2M Karras"
    }

    static func index(for name: String) -> Int {
        samplerNames.first { $0.value == name }?.key ?? 2
    }
}

// MARK: - Config Presets Manager

@MainActor
class ConfigPresetsManager: ObservableObject {
    static let shared = ConfigPresetsManager()

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "presets")
    private let fileManager = FileManager.default

    /// Directory for storing presets
    var presetsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DrawThingsStudio/Presets", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Path to our native presets file
    var presetsFilePath: URL {
        presetsDirectory.appendingPathComponent("config_presets.json")
    }

    // MARK: - Export

    /// Export all presets to our native JSON format
    func exportPresets(_ configs: [ModelConfig]) throws -> URL {
        let presets = configs.map { StudioConfigPreset(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(presets)
        try data.write(to: presetsFilePath)
        logger.info("Exported \(configs.count) presets to \(self.presetsFilePath.path)")
        return presetsFilePath
    }

    /// Export presets in Draw Things compatible format
    func exportAsDrawThingsFormat(_ configs: [ModelConfig], to url: URL) throws {
        let dtConfigs = configs.map { config -> DrawThingsConfigFile in
            let configData = DrawThingsConfigData(
                targetImageWidth: config.width,
                targetImageHeight: config.height,
                steps: config.steps,
                guidanceScale: Double(config.guidanceScale),
                sampler: SamplerMapping.index(for: config.samplerName),
                shift: config.shift.map { Double($0) },
                strength: config.strength.map { Double($0) },
                clipSkip: config.clipSkip,
                seed: nil,
                model: nil,
                batchCount: nil,
                batchSize: nil
            )
            return DrawThingsConfigFile(name: config.name, configuration: configData)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(dtConfigs)
        try data.write(to: url)
        logger.info("Exported \(configs.count) presets in Draw Things format")
    }

    // MARK: - Import

    /// Import presets from our native JSON format
    func importNativePresets(from url: URL) throws -> [StudioConfigPreset] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let presets = try decoder.decode([StudioConfigPreset].self, from: data)
        logger.info("Imported \(presets.count) native presets")
        return presets
    }

    /// Import presets from Draw Things custom_configs.json
    func importDrawThingsConfigs(from url: URL) throws -> [StudioConfigPreset] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let dtConfigs = try decoder.decode([DrawThingsConfigFile].self, from: data)

        let presets = dtConfigs.map { dt -> StudioConfigPreset in
            StudioConfigPreset(
                id: UUID(),
                name: dt.name,
                modelName: "Imported",
                description: "Imported from Draw Things",
                width: dt.configuration.targetImageWidth ?? 1024,
                height: dt.configuration.targetImageHeight ?? 1024,
                steps: dt.configuration.steps ?? 30,
                guidanceScale: Float(dt.configuration.guidanceScale ?? 7.5),
                samplerName: SamplerMapping.name(for: dt.configuration.sampler ?? 2),
                shift: dt.configuration.shift.map { Float($0) },
                clipSkip: dt.configuration.clipSkip,
                strength: dt.configuration.strength.map { Float($0) },
                isBuiltIn: false,
                createdAt: Date(),
                modifiedAt: Date()
            )
        }

        logger.info("Imported \(presets.count) presets from Draw Things format")
        return presets
    }

    /// Auto-detect format and import
    func importPresets(from url: URL) throws -> [StudioConfigPreset] {
        let data = try Data(contentsOf: url)

        // Try our native format first
        if let _ = try? JSONDecoder().decode([StudioConfigPreset].self, from: data) {
            return try importNativePresets(from: url)
        }

        // Try Draw Things format
        if let _ = try? JSONDecoder().decode([DrawThingsConfigFile].self, from: data) {
            return try importDrawThingsConfigs(from: url)
        }

        throw ConfigPresetsError.unknownFormat
    }

    // MARK: - Sync to SwiftData

    /// Import presets into SwiftData model context
    func importToModelContext(_ presets: [StudioConfigPreset], context: ModelContext, replaceExisting: Bool = false) {
        for preset in presets {
            let config = preset.toModelConfig()
            context.insert(config)
        }
        logger.info("Added \(presets.count) presets to model context")
    }

    /// Open Finder at presets directory
    func revealPresetsInFinder() {
        NSWorkspace.shared.selectFile(presetsFilePath.path, inFileViewerRootedAtPath: presetsDirectory.path)
    }
}

// MARK: - Errors

enum ConfigPresetsError: LocalizedError {
    case unknownFormat
    case exportFailed(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .unknownFormat:
            return "Unknown config file format"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        }
    }
}

// MARK: - Helper for preserving unknown JSON fields

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
