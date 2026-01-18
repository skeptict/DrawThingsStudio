//
//  ModelConfigsView.swift
//  DrawThingsStudio
//
//  UI for managing model configuration presets
//

import SwiftUI
import SwiftData

// MARK: - Model Configs View

struct ModelConfigsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ModelConfig.name) private var configs: [ModelConfig]

    @State private var searchText = ""
    @State private var selectedConfig: ModelConfig?
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var filterCategory = "All"

    private var categories: [String] {
        var cats = Set(configs.map { $0.modelName })
        cats.insert("All")
        return cats.sorted()
    }

    private var filteredConfigs: [ModelConfig] {
        configs.filter { config in
            let matchesSearch = searchText.isEmpty ||
                config.name.localizedCaseInsensitiveContains(searchText) ||
                config.modelName.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = filterCategory == "All" || config.modelName == filterCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        HSplitView {
            // Config list
            VStack(spacing: 0) {
                // Search and filter
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search configs...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    Picker("Category", selection: $filterCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                Divider()

                // Config list
                List(selection: $selectedConfig) {
                    ForEach(filteredConfigs) { config in
                        ModelConfigRow(config: config)
                            .tag(config)
                    }
                    .onDelete(perform: deleteConfigs)
                }
                .listStyle(.inset)

                Divider()

                // Bottom toolbar
                HStack {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)

                    Button(action: initializeBuiltInConfigs) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Reset built-in configs")

                    Spacer()

                    Text("\(filteredConfigs.count) configs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
            .frame(minWidth: 280, maxWidth: 350)

            // Detail view
            if let config = selectedConfig {
                ModelConfigDetailView(
                    config: config,
                    onEdit: { showingEditSheet = true },
                    onApply: { applyConfig(config) }
                )
            } else {
                VStack {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a config")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Choose a model configuration preset to view details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            initializeBuiltInConfigsIfNeeded()
        }
        .sheet(isPresented: $showingAddSheet) {
            ModelConfigEditSheet(config: nil) { newConfig in
                modelContext.insert(newConfig)
                selectedConfig = newConfig
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let config = selectedConfig {
                ModelConfigEditSheet(config: config) { _ in
                    // Config is already updated in place
                }
            }
        }
    }

    private func deleteConfigs(at offsets: IndexSet) {
        for index in offsets {
            let config = filteredConfigs[index]
            if !config.isBuiltIn {
                modelContext.delete(config)
            }
        }
    }

    private func initializeBuiltInConfigsIfNeeded() {
        let builtInCount = configs.filter { $0.isBuiltIn }.count
        if builtInCount == 0 {
            initializeBuiltInConfigs()
        }
    }

    private func initializeBuiltInConfigs() {
        // Remove existing built-in configs
        for config in configs where config.isBuiltIn {
            modelContext.delete(config)
        }

        // Add all built-in configs
        for preset in BuiltInModelConfigs.all {
            let config = BuiltInModelConfigs.createBuiltInConfig(from: preset)
            modelContext.insert(config)
        }
    }

    private func applyConfig(_ config: ModelConfig) {
        // Update app settings with this config
        let settings = AppSettings.shared
        settings.defaultWidth = config.width
        settings.defaultHeight = config.height
        settings.defaultSteps = config.steps
        settings.defaultGuidanceScale = Double(config.guidanceScale)
        settings.defaultSampler = config.samplerName
        if let shift = config.shift {
            settings.defaultShift = Double(shift)
        }
    }
}

// MARK: - Config Row

struct ModelConfigRow: View {
    let config: ModelConfig

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(config.name)
                        .fontWeight(.medium)
                    if config.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Text("\(config.width)x\(config.height) • \(config.steps) steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(config.modelName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Config Detail View

struct ModelConfigDetailView: View {
    let config: ModelConfig
    let onEdit: () -> Void
    let onApply: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(config.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(config.modelName)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !config.isBuiltIn {
                        Button("Edit", action: onEdit)
                    }
                    Button("Apply to Defaults", action: onApply)
                        .buttonStyle(.borderedProminent)
                }

                if !config.configDescription.isEmpty {
                    Text(config.configDescription)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Settings grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ConfigValueCard(label: "Width", value: "\(config.width)")
                    ConfigValueCard(label: "Height", value: "\(config.height)")
                    ConfigValueCard(label: "Steps", value: "\(config.steps)")
                    ConfigValueCard(label: "Guidance", value: String(format: "%.1f", config.guidanceScale))
                    ConfigValueCard(label: "Sampler", value: config.samplerName)
                    if let shift = config.shift {
                        ConfigValueCard(label: "Shift", value: String(format: "%.1f", shift))
                    }
                    if let clipSkip = config.clipSkip {
                        ConfigValueCard(label: "CLIP Skip", value: "\(clipSkip)")
                    }
                    if let strength = config.strength {
                        ConfigValueCard(label: "Strength", value: String(format: "%.2f", strength))
                    }
                }

                Divider()

                // JSON Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Config JSON")
                        .font(.headline)

                    let jsonDict = config.toDrawThingsConfig()
                    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        Text(jsonString)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 400)
    }
}

struct ConfigValueCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Edit Sheet

struct ModelConfigEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let config: ModelConfig?
    let onSave: (ModelConfig) -> Void

    @State private var name: String = ""
    @State private var modelName: String = ""
    @State private var description: String = ""
    @State private var width: Int = 1024
    @State private var height: Int = 1024
    @State private var steps: Int = 30
    @State private var guidanceScale: Float = 7.5
    @State private var samplerName: String = "DPM++ 2M Karras"
    @State private var shift: String = ""
    @State private var clipSkip: String = ""
    @State private var strength: String = ""

    var isEditing: Bool { config != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Config" : "New Config")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || modelName.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    TextField("Model Type (e.g., SDXL, Flux, SD 1.5)", text: $modelName)
                    TextField("Description", text: $description)
                }

                Section("Dimensions") {
                    HStack {
                        TextField("Width", value: $width, format: .number)
                        Text("x")
                        TextField("Height", value: $height, format: .number)
                    }
                }

                Section("Generation") {
                    TextField("Steps", value: $steps, format: .number)
                    TextField("Guidance Scale", value: $guidanceScale, format: .number)
                    TextField("Sampler", text: $samplerName)
                }

                Section("Optional") {
                    TextField("Shift (leave empty if not used)", text: $shift)
                    TextField("CLIP Skip (leave empty if not used)", text: $clipSkip)
                    TextField("Strength for img2img (leave empty if not used)", text: $strength)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 450, height: 550)
        .onAppear {
            if let config = config {
                name = config.name
                modelName = config.modelName
                description = config.configDescription
                width = config.width
                height = config.height
                steps = config.steps
                guidanceScale = config.guidanceScale
                samplerName = config.samplerName
                if let s = config.shift { shift = String(s) }
                if let c = config.clipSkip { clipSkip = String(c) }
                if let st = config.strength { strength = String(st) }
            }
        }
    }

    private func save() {
        if let config = config {
            // Update existing
            config.name = name
            config.modelName = modelName
            config.configDescription = description
            config.width = width
            config.height = height
            config.steps = steps
            config.guidanceScale = guidanceScale
            config.samplerName = samplerName
            config.shift = Float(shift)
            config.clipSkip = Int(clipSkip)
            config.strength = Float(strength)
            config.modifiedAt = Date()
            onSave(config)
        } else {
            // Create new
            let newConfig = ModelConfig(
                name: name,
                modelName: modelName,
                description: description,
                width: width,
                height: height,
                steps: steps,
                guidanceScale: guidanceScale,
                samplerName: samplerName,
                shift: Float(shift),
                clipSkip: Int(clipSkip),
                strength: Float(strength),
                isBuiltIn: false
            )
            onSave(newConfig)
        }
        dismiss()
    }
}

#Preview {
    ModelConfigsView()
}
