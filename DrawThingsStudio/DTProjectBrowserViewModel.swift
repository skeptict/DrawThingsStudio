//
//  DTProjectBrowserViewModel.swift
//  DrawThingsStudio
//
//  State management for the Draw Things project database browser.
//

import Foundation
import AppKit
import Combine

// MARK: - Project Info

struct DTProjectInfo: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let fileSize: Int64
    let modifiedDate: Date
}

// MARK: - ViewModel

@MainActor
final class DTProjectBrowserViewModel: ObservableObject {
    @Published var projects: [DTProjectInfo] = []
    @Published var selectedProject: DTProjectInfo?
    @Published var entries: [DTGenerationEntry] = []
    @Published var selectedEntry: DTGenerationEntry?
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var entryCount = 0
    @Published var hasMoreEntries = false
    @Published var hasFolderAccess = false

    private let bookmarkKey = "dt.documentsBookmark"
    private var loadedOffset = 0
    private let pageSize = 200

    var filteredEntries: [DTGenerationEntry] {
        guard !searchText.isEmpty else { return entries }
        let query = searchText.lowercased()
        return entries.filter { entry in
            entry.prompt.lowercased().contains(query) ||
            entry.negativePrompt.lowercased().contains(query) ||
            entry.model.lowercased().contains(query)
        }
    }

    init() {
        restoreBookmark()
    }

    // MARK: - Folder Access

    func requestFolderAccess() {
        let panel = NSOpenPanel()
        panel.title = "Select Draw Things Documents Folder"
        panel.message = "Grant access to browse Draw Things project databases.\nTypically at: ~/Library/Containers/com.liuliu.draw-things/Data/Documents/"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        // Try to start at the Draw Things container
        let dtDocsPath = NSHomeDirectory() + "/Library/Containers/com.liuliu.draw-things/Data/Documents"
        if FileManager.default.fileExists(atPath: dtDocsPath) {
            panel.directoryURL = URL(fileURLWithPath: dtDocsPath)
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Store security-scoped bookmark
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            hasFolderAccess = true
            loadProjects(from: url)
        } catch {
            // Bookmark creation failed; still try to use the URL this session
            hasFolderAccess = true
            loadProjects(from: url)
        }
    }

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            guard url.startAccessingSecurityScopedResource() else { return }

            if isStale {
                // Re-create bookmark
                if let newData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(newData, forKey: bookmarkKey)
                }
            }

            hasFolderAccess = true
            loadProjects(from: url)
        } catch {
            // Bookmark resolution failed
        }
    }

    // MARK: - Project Listing

    private func loadProjects(from folderURL: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        projects = contents
            .filter { $0.pathExtension == "sqlite3" }
            .compactMap { url -> DTProjectInfo? in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                return DTProjectInfo(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    fileSize: Int64(values?.fileSize ?? 0),
                    modifiedDate: values?.contentModificationDate ?? Date.distantPast
                )
            }
            .sorted { $0.modifiedDate > $1.modifiedDate }
    }

    // MARK: - Entry Loading

    func selectProject(_ project: DTProjectInfo) {
        selectedProject = project
        selectedEntry = nil
        entries = []
        loadedOffset = 0
        hasMoreEntries = false
        entryCount = 0
        loadEntries()
    }

    func loadEntries() {
        guard let project = selectedProject else { return }
        isLoading = true
        let url = project.url
        let offset = loadedOffset
        let limit = pageSize

        Task {
            let result: (entries: [DTGenerationEntry], totalCount: Int) = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let db = DTProjectDatabase(fileURL: url) else {
                        continuation.resume(returning: ([], 0))
                        return
                    }
                    let totalCount = db.entryCount()
                    var entries = db.fetchEntries(offset: offset, limit: limit)
                    for i in entries.indices {
                        entries[i].thumbnail = db.fetchThumbnail(previewId: entries[i].previewId)
                    }
                    continuation.resume(returning: (entries, totalCount))
                }
            }

            if offset == 0 {
                self.entries = result.entries
                self.entryCount = result.totalCount
            } else {
                self.entries.append(contentsOf: result.entries)
            }
            self.loadedOffset = offset + result.entries.count
            self.hasMoreEntries = self.loadedOffset < result.totalCount
            self.isLoading = false
        }
    }

    func loadMoreEntries() {
        guard !isLoading, hasMoreEntries else { return }
        loadEntries()
    }

    // MARK: - Formatting Helpers

    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
