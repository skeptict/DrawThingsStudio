//
//  ContentView.swift
//  DrawThingsStudio
//
//  Main content view for the application
//

import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .workflow
    @StateObject private var workflowViewModel = WorkflowBuilderViewModel()

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedItem) {
                Section("Create") {
                    Label("Workflow Builder", systemImage: "hammer")
                        .tag(SidebarItem.workflow)
                }

                Section("Library") {
                    Label("Saved Workflows", systemImage: "folder")
                        .tag(SidebarItem.library)

                    Label("Templates", systemImage: "doc.on.doc")
                        .tag(SidebarItem.templates)
                }

                Section("Settings") {
                    Label("Preferences", systemImage: "gearshape")
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Draw Things Studio")
        } detail: {
            // Main content based on selection
            // Keep WorkflowBuilderView alive by using opacity instead of conditional
            ZStack {
                WorkflowBuilderView(viewModel: workflowViewModel)
                    .opacity(selectedItem == .workflow || selectedItem == nil ? 1 : 0)
                    .allowsHitTesting(selectedItem == .workflow || selectedItem == nil)

                if selectedItem == .library {
                    SavedWorkflowsView()
                } else if selectedItem == .templates {
                    TemplatesLibraryView(
                        viewModel: workflowViewModel,
                        selectedItem: $selectedItem
                    )
                } else if selectedItem == .settings {
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .focusedSceneValue(\.workflowViewModel, workflowViewModel)
    }
}

enum SidebarItem: String, Identifiable {
    case workflow
    case library
    case templates
    case settings

    var id: String { rawValue }
}

// MARK: - Placeholder Views

struct SavedWorkflowsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Saved Workflows")
                .font(.title2)
            Text("Your saved workflows will appear here.\nUse the Save button in the toolbar to save workflows.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Templates Library View

struct TemplatesLibraryView: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel
    @Binding var selectedItem: SidebarItem?
    @State private var searchText = ""
    @State private var selectedCategory: TemplateCategory? = nil
    @State private var selectedTemplate: WorkflowTemplate? = nil

    var body: some View {
        HSplitView {
            // Left side: Categories and template list
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search templates...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .padding()

                // Categories
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(TemplateCategory.allCases, id: \.self) { category in
                            TemplateCategorySection(
                                category: category,
                                templates: filteredTemplates(for: category),
                                selectedTemplate: $selectedTemplate
                            )
                        }
                    }
                    .padding()
                }
            }
            .frame(minWidth: 300, idealWidth: 350)

            // Right side: Template details/preview
            TemplateDetailView(
                template: selectedTemplate,
                onUseTemplate: { template in
                    loadTemplate(template)
                    selectedItem = .workflow
                }
            )
            .frame(minWidth: 400)
        }
        .navigationTitle("Templates Library")
    }

    private func filteredTemplates(for category: TemplateCategory) -> [WorkflowTemplate] {
        let categoryTemplates = WorkflowTemplate.allTemplates.filter { $0.category == category }

        if searchText.isEmpty {
            return categoryTemplates
        }

        return categoryTemplates.filter { template in
            template.title.localizedCaseInsensitiveContains(searchText) ||
            template.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadTemplate(_ template: WorkflowTemplate) {
        switch template.id {
        case "story":
            viewModel.loadStoryTemplate()
        case "batch_variations":
            viewModel.loadBatchVariationTemplate()
        case "character_consistency":
            viewModel.loadCharacterConsistencyTemplate()
        case "img2img":
            viewModel.loadImg2ImgTemplate()
        case "inpainting":
            viewModel.loadInpaintingTemplate()
        case "upscaling":
            viewModel.loadUpscaleTemplate()
        case "batch_folder":
            viewModel.loadBatchFolderTemplate()
        case "video_frames":
            viewModel.loadVideoFramesTemplate()
        case "model_comparison":
            viewModel.loadModelComparisonTemplate()
        default:
            break
        }
    }
}

// MARK: - Template Category Section

struct TemplateCategorySection: View {
    let category: TemplateCategory
    let templates: [WorkflowTemplate]
    @Binding var selectedTemplate: WorkflowTemplate?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.secondary)
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 4)

            if templates.isEmpty {
                Text("No templates found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            } else {
                ForEach(templates) { template in
                    TemplateRowView(
                        template: template,
                        isSelected: selectedTemplate?.id == template.id
                    )
                    .onTapGesture {
                        selectedTemplate = template
                    }
                }
            }
        }
    }
}

// MARK: - Template Row View

struct TemplateRowView: View {
    let template: WorkflowTemplate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.icon)
                .font(.title2)
                .frame(width: 36, height: 36)
                .foregroundColor(isSelected ? .white : .accentColor)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(template.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    let template: WorkflowTemplate?
    let onUseTemplate: (WorkflowTemplate) -> Void

    var body: some View {
        if let template = template {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: template.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text(template.title)
                        .font(.title)
                        .fontWeight(.semibold)

                    Text(template.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 32)

                Divider()

                // Details
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Instructions preview
                        DetailSection(title: "What this template creates") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(template.instructionPreview, id: \.self) { instruction in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 6, height: 6)
                                        Text(instruction)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                }
                            }
                        }

                        // Use cases
                        DetailSection(title: "Best for") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(template.useCases, id: \.self) { useCase in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text(useCase)
                                    }
                                }
                            }
                        }

                        // Tips
                        if !template.tips.isEmpty {
                            DetailSection(title: "Tips") {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(template.tips, id: \.self) { tip in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "lightbulb.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                            Text(tip)
                                                .font(.callout)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }

                Divider()

                // Action button
                HStack {
                    Spacer()
                    Button(action: { onUseTemplate(template) }) {
                        Label("Use This Template", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Spacer()
                }
                .padding()
            }
        } else {
            // No template selected
            VStack(spacing: 16) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Select a Template")
                    .font(.title2)
                Text("Choose a template from the list to see details and use it.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

// MARK: - Template Data Models

enum TemplateCategory: String, CaseIterable {
    case basic = "Basic"
    case imageProcessing = "Image Processing"
    case batchProcessing = "Batch Processing"

    var icon: String {
        switch self {
        case .basic: return "star"
        case .imageProcessing: return "photo"
        case .batchProcessing: return "square.stack.3d.up"
        }
    }
}

struct WorkflowTemplate: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: TemplateCategory
    let instructionPreview: [String]
    let useCases: [String]
    let tips: [String]

    static let allTemplates: [WorkflowTemplate] = [
        // Basic
        WorkflowTemplate(
            id: "story",
            title: "Simple Story",
            description: "3-scene story sequence with prompts and saves",
            icon: "book",
            category: .basic,
            instructionPreview: [
                "note: Story sequence",
                "config: Default settings",
                "prompt + canvasSave (x3 scenes)"
            ],
            useCases: [
                "Creating visual stories",
                "Comic/manga panels",
                "Storyboarding scenes"
            ],
            tips: [
                "Replace placeholder prompts with detailed scene descriptions",
                "Keep character descriptions consistent across scenes"
            ]
        ),
        WorkflowTemplate(
            id: "batch_variations",
            title: "Batch Variations",
            description: "Generate multiple variations of a single prompt",
            icon: "square.stack.3d.up",
            category: .basic,
            instructionPreview: [
                "note: Batch variations",
                "config: Default settings",
                "prompt: Your base prompt",
                "loop (5 iterations)",
                "loopSave: variation_"
            ],
            useCases: [
                "Exploring prompt variations",
                "Finding the best seed",
                "A/B testing compositions"
            ],
            tips: [
                "Use a fixed seed in config to compare model differences only",
                "Adjust loop count based on how many variations you need"
            ]
        ),
        WorkflowTemplate(
            id: "character_consistency",
            title: "Character Consistency",
            description: "Create consistent character across scenes using moodboard",
            icon: "person.2",
            category: .basic,
            instructionPreview: [
                "config + character prompt",
                "canvasSave: character_ref",
                "moodboardClear + moodboardCanvas",
                "moodboardWeights",
                "scene prompts (x2)"
            ],
            useCases: [
                "Character-focused stories",
                "Maintaining visual consistency",
                "Reference-based generation"
            ],
            tips: [
                "Create a detailed character reference first",
                "Higher moodboard weights = stronger character resemblance",
                "Include character description in every scene prompt"
            ]
        ),

        // Image Processing
        WorkflowTemplate(
            id: "img2img",
            title: "Img2Img",
            description: "Transform an input image with a prompt",
            icon: "photo.on.rectangle",
            category: .imageProcessing,
            instructionPreview: [
                "config: strength 0.7",
                "canvasLoad: input.png",
                "prompt: Enhancement",
                "canvasSave: output.png"
            ],
            useCases: [
                "Style transfer",
                "Image enhancement",
                "Artistic transformation"
            ],
            tips: [
                "Lower strength (0.3-0.5) preserves more of original",
                "Higher strength (0.7-0.9) allows more creative changes",
                "Place input image in Pictures folder"
            ]
        ),
        WorkflowTemplate(
            id: "inpainting",
            title: "Inpainting",
            description: "Replace parts of an image using AI masking",
            icon: "paintbrush",
            category: .imageProcessing,
            instructionPreview: [
                "config: Default",
                "canvasLoad: input.png",
                "maskAsk: object to mask",
                "inpaintTools: strength 0.8",
                "prompt: Replacement",
                "canvasSave: inpainted.png"
            ],
            useCases: [
                "Object removal",
                "Background replacement",
                "Selective editing"
            ],
            tips: [
                "Be specific with maskAsk for better results",
                "Use maskBlur to blend edges naturally",
                "Multiple passes can improve results"
            ]
        ),
        WorkflowTemplate(
            id: "upscaling",
            title: "Upscaling",
            description: "High-resolution output with enhanced details",
            icon: "arrow.up.left.and.arrow.down.right",
            category: .imageProcessing,
            instructionPreview: [
                "config: 2048x2048",
                "canvasLoad: input.png",
                "adaptSize: max 2048",
                "prompt: High detail",
                "canvasSave: upscaled.png"
            ],
            useCases: [
                "Print-quality images",
                "Detail enhancement",
                "Resolution increase"
            ],
            tips: [
                "Use tiling for very large images",
                "Lower guidance can reduce artifacts",
                "Works best with already good images"
            ]
        ),

        // Batch Processing
        WorkflowTemplate(
            id: "batch_folder",
            title: "Batch Folder",
            description: "Process all images in a folder with same prompt",
            icon: "folder",
            category: .batchProcessing,
            instructionPreview: [
                "config: strength 0.6",
                "loop with loopLoad",
                "prompt: Enhancement",
                "loopSave: output_"
            ],
            useCases: [
                "Bulk style transfer",
                "Photo batch processing",
                "Consistent edits across images"
            ],
            tips: [
                "Create input_folder in Pictures with your images",
                "Use consistent naming for easy organization",
                "Test on one image first before batch"
            ]
        ),
        WorkflowTemplate(
            id: "video_frames",
            title: "Video Frames",
            description: "Stylize video frames for animation",
            icon: "film",
            category: .batchProcessing,
            instructionPreview: [
                "config: strength 0.5",
                "loop with loopLoad: frames",
                "prompt: Stylization",
                "frames: 24",
                "loopSave: styled_frame_"
            ],
            useCases: [
                "Video stylization",
                "Animation creation",
                "Frame-by-frame editing"
            ],
            tips: [
                "Extract frames with ffmpeg first",
                "Lower strength for temporal consistency",
                "Use same seed across all frames"
            ]
        ),
        WorkflowTemplate(
            id: "model_comparison",
            title: "Model Comparison",
            description: "Compare same prompt across multiple models",
            icon: "square.grid.2x2",
            category: .batchProcessing,
            instructionPreview: [
                "prompt: Comparison prompt",
                "config (model_1) + save",
                "config (model_2) + save",
                "config (model_3) + save"
            ],
            useCases: [
                "Model evaluation",
                "Finding best model for style",
                "Quality comparison"
            ],
            tips: [
                "Use same seed for fair comparison",
                "Replace model names with your actual models",
                "Same prompt + same seed = pure model difference"
            ]
        )
    ]
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
