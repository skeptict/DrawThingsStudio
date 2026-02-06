//
//  ImageGenerationView.swift
//  DrawThingsStudio
//
//  UI for generating images via Draw Things (Neumorphic style)
//

import SwiftUI
import SwiftData

struct ImageGenerationView: View {
    @ObservedObject var viewModel: ImageGenerationViewModel
    @StateObject private var assetManager = DrawThingsAssetManager.shared
    @Query(sort: \ModelConfig.name) private var modelConfigs: [ModelConfig]
    @State private var selectedPresetID: String = ""

    var body: some View {
        HStack(spacing: 20) {
            // Left panel: Controls
            controlsPanel
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)

            // Right panel: Gallery
            galleryPanel
                .frame(minWidth: 400)
        }
        .padding(20)
        .neuBackground()
        .task {
            await viewModel.checkConnection()
            await assetManager.fetchAssets()
        }
    }

    // MARK: - Controls Panel

    private var controlsPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Connection status
                connectionStatusBadge

                // Preset picker
                presetSection

                // Prompt
                promptSection

                // Config controls
                configSection

                // Generate button
                generateSection
            }
            .padding(20)
        }
        .neuCard(cornerRadius: 24)
    }

    // MARK: - Connection Status

    private var connectionStatusBadge: some View {
        HStack(spacing: 8) {
            NeuStatusBadge(color: connectionColor, text: viewModel.connectionStatus.displayText)
                .accessibilityLabel("Connection status: \(viewModel.connectionStatus.displayText)")

            Spacer()

            Button("Refresh") {
                Task { await viewModel.checkConnection() }
            }
            .font(.caption)
            .foregroundColor(.neuTextSecondary)
            .buttonStyle(NeumorphicPlainButtonStyle())
            .accessibilityLabel("Refresh connection status")
        }
    }

    private var connectionColor: Color {
        switch viewModel.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    // MARK: - Preset Section

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NeuSectionHeader("Config Preset", icon: "slider.horizontal.3")

            Picker("Preset", selection: $selectedPresetID) {
                Text("Custom").tag("")
                ForEach(modelConfigs) { config in
                    Text(config.name).tag(config.id.uuidString)
                }
            }
            .labelsHidden()
            .onChange(of: selectedPresetID) { _, newValue in
                if let config = modelConfigs.first(where: { $0.id.uuidString == newValue }) {
                    viewModel.loadPreset(config)
                }
            }

            if !modelConfigs.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(modelConfigs.prefix(3))) { config in
                        Button(config.name) {
                            viewModel.loadPreset(config)
                            selectedPresetID = config.id.uuidString
                        }
                        .font(.caption)
                        .buttonStyle(NeumorphicButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NeuSectionHeader("Prompt", icon: "text.quote")

            TextEditor(text: $viewModel.prompt)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 150)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.neuBackground.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.neuShadowDark.opacity(0.1), lineWidth: 0.5)
                )

            NeuSectionHeader("Negative Prompt")

            TextField("Things to avoid...", text: $viewModel.negativePrompt)
                .textFieldStyle(NeumorphicTextFieldStyle())
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NeuSectionHeader("Generation Settings", icon: "gearshape")

            if let error = assetManager.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.neuTextSecondary)
            }

            // Model (searchable dropdown)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model").font(.caption).foregroundColor(.neuTextSecondary)
                    if assetManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    Spacer()
                    Button {
                        Task { await assetManager.forceRefresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.neuTextSecondary)
                    }
                    .buttonStyle(NeumorphicIconButtonStyle())
                    .help("Refresh models from Draw Things")
                    .accessibilityLabel("Refresh models from Draw Things")
                }
                if assetManager.models.isEmpty {
                    TextField("e.g., z_image_turbo_1.0_q8p.ckpt", text: $viewModel.config.model)
                        .textFieldStyle(NeumorphicTextFieldStyle())
                } else {
                    SearchableDropdown(
                        title: "Model",
                        items: assetManager.models,
                        itemLabel: { $0.name },
                        selection: $viewModel.config.model,
                        placeholder: "Search models..."
                    )
                }
            }

            // Sampler (searchable dropdown)
            VStack(alignment: .leading, spacing: 4) {
                Text("Sampler").font(.caption).foregroundColor(.neuTextSecondary)
                SimpleSearchableDropdown(
                    title: "Sampler",
                    items: DrawThingsSampler.builtIn.map { $0.name },
                    selection: $viewModel.config.sampler,
                    placeholder: "Search samplers..."
                )
            }

            // Dimensions
            HStack(spacing: 12) {
                neuConfigField("Width", value: $viewModel.config.width)
                neuConfigField("Height", value: $viewModel.config.height)
                Spacer()
            }

            // Steps & Guidance
            HStack(spacing: 12) {
                neuConfigField("Steps", value: $viewModel.config.steps)
                neuConfigFieldDouble("Guidance", value: $viewModel.config.guidanceScale)
                Spacer()
            }

            // Seed & Shift
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seed").font(.caption).foregroundColor(.neuTextSecondary)
                    TextField("", value: $viewModel.config.seed, format: .number)
                        .textFieldStyle(NeumorphicTextFieldStyle())
                        .frame(width: 90)
                }
                neuConfigFieldDouble("Shift", value: $viewModel.config.shift)
                Spacer()
            }

            // Strength
            VStack(alignment: .leading, spacing: 4) {
                Text("Strength").font(.caption).foregroundColor(.neuTextSecondary)
                HStack(spacing: 8) {
                    Slider(value: $viewModel.config.strength, in: 0...1, step: 0.05)
                        .tint(Color.neuAccent)
                        .accessibilityLabel("Strength")
                        .accessibilityValue(String(format: "%.0f percent", viewModel.config.strength * 100))
                    Text(String(format: "%.2f", viewModel.config.strength))
                        .font(.caption)
                        .foregroundColor(.neuTextSecondary)
                        .frame(width: 35)
                }
            }

            // LoRAs
            Divider()
                .padding(.vertical, 4)

            LoRAConfigurationView(
                availableLoRAs: assetManager.loras,
                selectedLoRAs: $viewModel.config.loras
            )
        }
    }

    // MARK: - Generate Section

    private var generateSection: some View {
        VStack(spacing: 10) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .neuInset(cornerRadius: 8)
            }

            if viewModel.isGenerating {
                VStack(spacing: 6) {
                    NeumorphicProgressBar(value: viewModel.progressFraction)
                        .accessibilityLabel("Generation progress")
                        .accessibilityValue("\(Int(viewModel.progressFraction * 100)) percent")
                    Text(viewModel.progress.description)
                        .font(.caption)
                        .foregroundColor(.neuTextSecondary)
                }

                Button("Cancel") {
                    viewModel.cancelGeneration()
                }
                .buttonStyle(NeumorphicButtonStyle())
                .accessibilityLabel("Cancel generation")
            } else {
                Button(action: { viewModel.generate() }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Generate")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NeumorphicButtonStyle(isProminent: true))
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Generate image")
                .accessibilityHint("Sends prompt to Draw Things for image generation")
            }
        }
    }

    // MARK: - Gallery Panel

    private var galleryPanel: some View {
        VStack(spacing: 0) {
            // Gallery header
            HStack {
                NeuSectionHeader("Generated Images", icon: "photo.stack")

                Spacer()

                Text("\(viewModel.generatedImages.count)")
                    .font(.caption)
                    .foregroundColor(.neuTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .neuInset(cornerRadius: 6)

                Button(action: { viewModel.openOutputFolder() }) {
                    Image(systemName: "folder")
                        .foregroundColor(.neuTextSecondary)
                }
                .buttonStyle(NeumorphicIconButtonStyle())
                .help("Open output folder")
                .accessibilityLabel("Open output folder")
            }
            .padding(16)

            if viewModel.generatedImages.isEmpty {
                emptyGalleryView
            } else {
                HStack(spacing: 16) {
                    // Thumbnail grid
                    thumbnailGrid
                        .frame(minWidth: 180)

                    // Selected image detail
                    if let selected = viewModel.selectedImage {
                        imageDetailView(selected)
                            .frame(minWidth: 280)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .neuCard(cornerRadius: 24)
    }

    private var emptyGalleryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.neuTextSecondary.opacity(0.5))
            Text("No Images Generated")
                .font(.title3)
                .foregroundColor(.neuTextSecondary)
            Text("Enter a prompt and click Generate.")
                .font(.callout)
                .foregroundColor(.neuTextSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var thumbnailGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                ForEach(viewModel.generatedImages) { generatedImage in
                    thumbnailView(generatedImage)
                }
            }
        }
    }

    private func thumbnailView(_ generatedImage: GeneratedImage) -> some View {
        Image(nsImage: generatedImage.image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 110, height: 110)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.neuShadowDark.opacity(viewModel.selectedImage?.id == generatedImage.id ? 0.4 : 0.2),
                    radius: viewModel.selectedImage?.id == generatedImage.id ? 8 : 4,
                    x: 3, y: 3)
            .shadow(color: Color.neuShadowLight.opacity(0.6), radius: 4, x: -2, y: -2)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        viewModel.selectedImage?.id == generatedImage.id ? Color.neuAccent.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
            .onTapGesture {
                viewModel.selectedImage = generatedImage
            }
            .contextMenu {
                Button("Copy Image") { viewModel.copyToClipboard(generatedImage) }
                Button("Reveal in Finder") { viewModel.revealInFinder(generatedImage) }
                Divider()
                Button("Use Prompt") { viewModel.prompt = generatedImage.prompt }
                Divider()
                Button("Delete", role: .destructive) { viewModel.deleteImage(generatedImage) }
            }
            .accessibilityLabel("Generated image")
            .accessibilityHint("Double-tap to select")
            .accessibilityAddTraits(viewModel.selectedImage?.id == generatedImage.id ? .isSelected : [])
    }

    private func imageDetailView(_ generatedImage: GeneratedImage) -> some View {
        VStack(spacing: 12) {
            // Large image preview
            Image(nsImage: generatedImage.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.neuShadowDark.opacity(0.2), radius: 8, x: 4, y: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Image info card
            VStack(alignment: .leading, spacing: 8) {
                if !generatedImage.prompt.isEmpty {
                    Text(generatedImage.prompt)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                HStack(spacing: 12) {
                    neuInfoChip("\(generatedImage.config.width)x\(generatedImage.config.height)")
                    neuInfoChip("\(generatedImage.config.steps) steps")
                    neuInfoChip(String(format: "%.1f cfg", generatedImage.config.guidanceScale))
                }

                Text(generatedImage.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.neuTextSecondary)

                HStack(spacing: 8) {
                    Button("Copy") { viewModel.copyToClipboard(generatedImage) }
                        .font(.caption)
                        .buttonStyle(NeumorphicButtonStyle())
                    Button("Reveal") { viewModel.revealInFinder(generatedImage) }
                        .font(.caption)
                        .buttonStyle(NeumorphicButtonStyle())
                    Button("Use Prompt") {
                        viewModel.prompt = generatedImage.prompt
                        viewModel.negativePrompt = generatedImage.negativePrompt
                    }
                    .font(.caption)
                    .buttonStyle(NeumorphicButtonStyle())
                }
            }
            .padding(12)
            .neuInset(cornerRadius: 14)
        }
    }

    // MARK: - Helper Views

    private func neuConfigField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.neuTextSecondary)
            TextField("", value: value, format: .number)
                .textFieldStyle(NeumorphicTextFieldStyle())
                .frame(width: 70)
        }
    }

    private func neuConfigFieldDouble(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.neuTextSecondary)
            TextField("", value: value, format: .number.precision(.fractionLength(1)))
                .textFieldStyle(NeumorphicTextFieldStyle())
                .frame(width: 70)
        }
    }

    private func neuInfoChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.neuTextSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.neuBackground.opacity(0.6))
            )
    }
}
