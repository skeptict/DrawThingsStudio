//
//  CloudModelCatalog.swift
//  DrawThingsStudio
//
//  Fetches and caches the official Draw Things model catalog from GitHub
//

import Foundation
import Combine
import OSLog

protocol CloudCatalogFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: CloudCatalogFetching {}

enum CloudCatalogError: LocalizedError {
    case invalidResponse
    case badStatusCode(Int)
    case invalidContentType(String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid cloud catalog response"
        case .badStatusCode(let code):
            return "Cloud catalog request failed with status \(code)"
        case .invalidContentType(let value):
            return "Unexpected cloud catalog content type: \(value ?? "unknown")"
        }
    }
}

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
    private let fetcher: CloudCatalogFetching

    // MARK: - Initialization

    init(fetcher: CloudCatalogFetching = URLSession.shared) {
        self.fetcher = fetcher
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
            logger.info("Keeping existing cached cloud catalog after fetch failure")
            logger.error("Cloud catalog fetch failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func fetchFromGitHub() async throws -> [String] {
        var allModels: Set<String> = []

        allModels.formUnion(try await fetchModelList(from: modelsURL))
        allModels.formUnion(try await fetchModelList(from: builtinURL))

        // Sort alphabetically
        return allModels.sorted()
    }

    private func fetchModelList(from url: URL) async throws -> [String] {
        let data = try await fetchWithRetry(url: url, maxAttempts: 3)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CloudCatalogError.invalidResponse
        }
        return parseModelList(text)
    }

    private func fetchWithRetry(url: URL, maxAttempts: Int) async throws -> Data {
        var attempt = 0
        var lastError: Error?

        while attempt < maxAttempts {
            attempt += 1
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                let (data, response) = try await fetcher.data(for: request)
                try validateResponse(response, sourceURL: url)
                return data
            } catch {
                lastError = error
                if !isRetryable(error) || attempt == maxAttempts {
                    throw error
                }
                let delayNanos = UInt64(pow(2.0, Double(attempt - 1)) * 500_000_000)
                try await Task.sleep(nanoseconds: delayNanos)
            }
        }

        throw lastError ?? CloudCatalogError.invalidResponse
    }

    private func validateResponse(_ response: URLResponse, sourceURL: URL) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CloudCatalogError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw CloudCatalogError.badStatusCode(http.statusCode)
        }

        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        if let contentType,
           !contentType.contains("text/plain"),
           !contentType.contains("text/"),
           !contentType.contains("application/octet-stream") {
            logger.warning("Unexpected content type from \(sourceURL.absoluteString): \(contentType)")
            throw CloudCatalogError.invalidContentType(contentType)
        }
    }

    private func isRetryable(_ error: Error) -> Bool {
        if case CloudCatalogError.badStatusCode(let code) = error {
            return code == 429 || code == 500 || code == 502 || code == 503 || code == 504
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorCannotConnectToHost || nsError.code == NSURLErrorNetworkConnectionLost
        }
        return false
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
