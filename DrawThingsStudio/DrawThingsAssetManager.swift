//
//  DrawThingsAssetManager.swift
//  DrawThingsStudio
//
//  Shared manager for fetching and caching Draw Things assets (models, LoRAs, etc.)
//

import Foundation
import AppKit
import Combine
import OSLog

/// Shared manager for Draw Things assets like models and LoRAs
@MainActor
final class DrawThingsAssetManager: ObservableObject {

    static let shared = DrawThingsAssetManager()

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "asset-manager")

    // MARK: - Published State

    @Published private(set) var models: [DrawThingsModel] = []
    @Published private(set) var loras: [DrawThingsLoRA] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastFetchDate: Date?

    // MARK: - Initialization

    private init() {}

    // MARK: - Fetch Assets

    /// Fetch all available assets from Draw Things using the configured transport
    func fetchAssets() async {
        let client = AppSettings.shared.createDrawThingsClient()

        isLoading = true
        lastError = nil

        // First check connection
        let connected = await client.checkConnection()
        guard connected else {
            lastError = "Cannot connect to Draw Things (\(client.transport.displayName))"
            isLoading = false
            return
        }

        // Fetch models
        do {
            let fetchedModels = try await client.fetchModels()
            if !fetchedModels.isEmpty {
                models = fetchedModels
            }
            lastError = "Connected via \(client.transport.displayName) - \(fetchedModels.count) models found"
        } catch {
            lastError = "Model fetch failed: \(error.localizedDescription)"
        }

        // Fetch LoRAs
        do {
            let fetchedLoRAs = try await client.fetchLoRAs()
            if !fetchedLoRAs.isEmpty {
                loras = fetchedLoRAs
            }
            let modelCount = models.count
            let loraCount = fetchedLoRAs.count
            lastError = "Connected via \(client.transport.displayName) - \(modelCount) models, \(loraCount) LoRAs"
        } catch {
            let prev = lastError ?? ""
            lastError = "\(prev) | LoRA fetch failed: \(error.localizedDescription)"
        }

        isLoading = false
        lastFetchDate = Date()
    }

    /// Refresh assets if stale (older than 5 minutes) or never fetched
    func refreshIfNeeded() async {
        if let lastFetch = lastFetchDate {
            let staleInterval: TimeInterval = 5 * 60 // 5 minutes
            if Date().timeIntervalSince(lastFetch) < staleInterval {
                return // Not stale yet
            }
        }
        await fetchAssets()
    }

    /// Force refresh assets
    func forceRefresh() async {
        await fetchAssets()
    }

    // MARK: - Helpers

    /// Get model display name for a filename
    func modelDisplayName(for filename: String) -> String {
        if let model = models.first(where: { $0.filename == filename }) {
            return model.name
        }
        return filename
    }

    /// Get LoRA display name for a filename
    func loraDisplayName(for filename: String) -> String {
        if let lora = loras.first(where: { $0.filename == filename }) {
            return lora.name
        }
        return filename
    }
}
