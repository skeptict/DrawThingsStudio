//
//  CloudModelCatalog.swift
//  DrawThingsStudio
//
//  Fetches and caches the official Draw Things model catalog from GitHub
//

import Foundation
import Combine
import OSLog

/// Manages fetching and caching of the cloud model catalog from Draw Things GitHub
@MainActor
final class CloudModelCatalog: ObservableObject {
    static let shared = CloudModelCatalog()

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "cloud-catalog")

    // MARK: - Published State

    @Published private(set) var models: [DrawThingsModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastFetchDate: Date?
    @Published private(set) var lastError: String?

    // MARK: - Configuration

    private let modelsURL = URL(string: "https://raw.githubusercontent.com/drawthingsai/community-models/main/models.txt")!
    private let builtinURL = URL(string: "https://raw.githubusercontent.com/drawthingsai/community-models/main/builtin.txt")!

    private let cacheKey = "cloudModelCatalog"
    private let cacheDateKey = "cloudModelCatalogDate"
    private let cacheMaxAge: TimeInterval = 24 * 60 * 60  // 24 hours

    // MARK: - Initialization

    init() {
        loadFromCache()
    }

    // MARK: - Public Methods

    /// Fetch models if cache is stale (older than 24 hours)
    func fetchIfNeeded() async {
        if let lastFetch = lastFetchDate, Date().timeIntervalSince(lastFetch) < cacheMaxAge {
            logger.info("Using cached cloud models (last fetch: \(lastFetch.formatted()))")
            return
        }
        await forceRefresh()
    }

    /// Force refresh from GitHub, bypassing cache
    func forceRefresh() async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        do {
            let modelNames = try await fetchFromGitHub()
            models = modelNames.map { name in
                DrawThingsModel(
                    name: formatDisplayName(name),
                    filename: name
                )
            }
            lastFetchDate = Date()
            saveToCache()
            logger.info("Fetched \(self.models.count) cloud models")
        } catch {
            lastError = "Failed to fetch cloud catalog: \(error.localizedDescription)"
            logger.error("Cloud catalog fetch failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func fetchFromGitHub() async throws -> [String] {
        var allModels: Set<String> = []

        // Fetch curated models
        let (modelsData, _) = try await URLSession.shared.data(from: modelsURL)
        if let modelsText = String(data: modelsData, encoding: .utf8) {
            let names = parseModelList(modelsText)
            allModels.formUnion(names)
        }

        // Fetch builtin models
        let (builtinData, _) = try await URLSession.shared.data(from: builtinURL)
        if let builtinText = String(data: builtinData, encoding: .utf8) {
            let names = parseModelList(builtinText)
            allModels.formUnion(names)
        }

        // Sort alphabetically
        return allModels.sorted()
    }

    private func parseModelList(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }  // Skip empty lines and comments
    }

    private func formatDisplayName(_ filename: String) -> String {
        // Convert hyphenated names to title case
        // e.g., "flux-1-dev" → "Flux 1 Dev"
        // e.g., "sd3-large-turbo-3.5" → "SD3 Large Turbo 3.5"

        let cleaned = filename
            .replacingOccurrences(of: ".ckpt", with: "")
            .replacingOccurrences(of: ".safetensors", with: "")

        let words = cleaned.components(separatedBy: "-")
        let formatted = words.map { word -> String in
            // Keep version numbers and abbreviations as-is
            if word.allSatisfy({ $0.isNumber || $0 == "." }) {
                return word
            }
            // Uppercase common abbreviations
            let upper = word.uppercased()
            if ["SD", "XL", "SDXL", "SD3", "FLUX", "LORA", "VAE", "IP", "VL", "LCM", "SVD"].contains(upper) {
                return upper
            }
            // Title case other words
            return word.capitalized
        }

        return formatted.joined(separator: " ")
    }

    // MARK: - Cache Management

    private func loadFromCache() {
        if let cachedNames = UserDefaults.standard.stringArray(forKey: cacheKey) {
            models = cachedNames.map { name in
                DrawThingsModel(
                    name: formatDisplayName(name),
                    filename: name
                )
            }
            lastFetchDate = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
            logger.info("Loaded \(self.models.count) cached cloud models")
        }
    }

    private func saveToCache() {
        let names = models.map { $0.filename }
        UserDefaults.standard.set(names, forKey: cacheKey)
        UserDefaults.standard.set(lastFetchDate, forKey: cacheDateKey)
    }
}
