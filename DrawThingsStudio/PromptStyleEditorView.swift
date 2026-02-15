//
//  PromptStyleEditorView.swift
//  DrawThingsStudio
//
//  In-app editor for viewing, creating, editing, and deleting prompt styles
//

import SwiftUI

struct PromptStyleEditorView: View {
    @ObservedObject var styleManager = PromptStyleManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStyleID: String?
    @State private var editName: String = ""
    @State private var editIcon: String = ""
    @State private var editSystemPrompt: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var showIconPicker: Bool = false

    private static let availableIcons = [
        "paintpalette", "gearshape.2", "camera", "paintbrush", "film", "sparkles",
        "wand.and.stars", "photo", "eye", "lightbulb", "star", "heart",
        "bolt", "flame", "leaf", "globe", "moon", "sun.max",
        "cloud", "drop", "snowflake", "wind", "theatermasks", "music.note",
        "pencil", "scribble", "highlighter", "lasso", "rectangle.3.group",
        "cube", "cylinder", "cone", "pyramid", "diamond"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Prompt Styles")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // Main content
            HSplitView {
                // Left: style list
                styleList
                    .frame(minWidth: 200, maxWidth: 250)

                // Right: editor
                if let styleID = selectedStyleID,
                   styleManager.style(for: styleID) != nil {
                    styleEditor(for: styleID)
                } else {
                    emptyState
                }
            }
        }
        .frame(width: 750, height: 520)
        .neuBackground()
        .onAppear {
            if selectedStyleID == nil, let first = styleManager.styles.first {
                selectStyle(first)
            }
        }
    }

    // MARK: - Style List

    private var styleList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(styleManager.styles) { style in
                        styleRow(style)
                    }
                }
                .padding(8)
            }

            Divider()

            Button {
                createNewStyle()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New Style")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeumorphicButtonStyle())
            .padding(8)
        }
        .background(Color.neuSurface.opacity(0.5))
    }

    private func styleRow(_ style: CustomPromptStyle) -> some View {
        Button {
            selectStyle(style)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: style.icon)
                    .frame(width: 20)
                    .foregroundColor(selectedStyleID == style.id ? .white : .primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.name)
                        .font(.body)
                        .foregroundColor(selectedStyleID == style.id ? .white : .primary)

                    HStack(spacing: 4) {
                        if style.isBuiltIn {
                            Text("built-in")
                                .font(.caption2)
                                .foregroundColor(selectedStyleID == style.id ? .white.opacity(0.7) : .neuTextSecondary)
                        } else if PromptStyle(rawValue: style.id) != nil {
                            Text("modified")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("custom")
                                .font(.caption2)
                                .foregroundColor(selectedStyleID == style.id ? .white.opacity(0.7) : .accentColor)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedStyleID == style.id ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Style Editor

    private func styleEditor(for styleID: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.headline)
                    TextField("Style name", text: $editName)
                        .textFieldStyle(NeumorphicTextFieldStyle())
                        .onChange(of: editName) { _, newValue in
                            updateCurrentStyle { $0.name = newValue }
                        }
                }

                // Icon
                VStack(alignment: .leading, spacing: 4) {
                    Text("Icon")
                        .font(.headline)
                    HStack {
                        Image(systemName: editIcon)
                            .font(.title2)
                            .frame(width: 36, height: 36)
                            .background(Color.neuSurface)
                            .cornerRadius(8)

                        Button("Choose Icon...") {
                            showIconPicker.toggle()
                        }
                        .buttonStyle(NeumorphicButtonStyle())

                        Spacer()
                    }

                    if showIconPicker {
                        iconPickerGrid
                    }
                }

                // System Prompt
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Prompt")
                        .font(.headline)
                    Text("This is the instruction sent to the LLM when enhancing prompts with this style.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $editSystemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 180)
                        .padding(4)
                        .neuInset(cornerRadius: 8)
                        .onChange(of: editSystemPrompt) { _, newValue in
                            updateCurrentStyle { $0.systemPrompt = newValue }
                        }
                }

                // Actions
                HStack {
                    if PromptStyle(rawValue: styleID) != nil,
                       styleManager.isBuiltInModified(id: styleID) {
                        Button("Reset to Default") {
                            styleManager.resetBuiltInStyle(id: styleID)
                            if let updated = styleManager.style(for: styleID) {
                                selectStyle(updated)
                            }
                        }
                        .buttonStyle(NeumorphicButtonStyle())
                    }

                    Spacer()

                    if !isBuiltInOriginal(styleID) {
                        Button("Delete Style") {
                            showDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                        .buttonStyle(NeumorphicButtonStyle())
                    }
                }
            }
            .padding(20)
        }
        .alert("Delete Style", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteCurrentStyle()
            }
        } message: {
            Text("Are you sure you want to delete this style? This cannot be undone.")
        }
    }

    private var iconPickerGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 6) {
            ForEach(Self.availableIcons, id: \.self) { icon in
                Button {
                    editIcon = icon
                    showIconPicker = false
                    updateCurrentStyle { $0.icon = icon }
                } label: {
                    Image(systemName: icon)
                        .font(.body)
                        .frame(width: 32, height: 32)
                        .background(editIcon == icon ? Color.accentColor.opacity(0.2) : Color.neuSurface)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(editIcon == icon ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .neuCard(cornerRadius: 10)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Image(systemName: "paintpalette")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a style to edit")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func selectStyle(_ style: CustomPromptStyle) {
        selectedStyleID = style.id
        editName = style.name
        editIcon = style.icon
        editSystemPrompt = style.systemPrompt
        showIconPicker = false
    }

    private func createNewStyle() {
        let id = UUID().uuidString
        let newStyle = CustomPromptStyle(
            id: id,
            name: "New Style",
            systemPrompt: "You are an expert at creating detailed prompts for AI image generation.\nOutput only the prompt, no explanations.",
            icon: "sparkles",
            isBuiltIn: false
        )
        styleManager.addStyle(newStyle)
        selectStyle(newStyle)
    }

    private func updateCurrentStyle(_ mutation: (inout CustomPromptStyle) -> Void) {
        guard let styleID = selectedStyleID,
              var style = styleManager.style(for: styleID) else { return }

        // If modifying a built-in, mark it as custom so it gets persisted
        if style.isBuiltIn {
            style.isBuiltIn = false
        }

        mutation(&style)
        styleManager.updateStyle(style)
    }

    private func deleteCurrentStyle() {
        guard let styleID = selectedStyleID else { return }
        let builtInIDs = Set(PromptStyle.allCases.map { $0.rawValue })

        if builtInIDs.contains(styleID) {
            // Modified built-in — reset to default instead
            styleManager.resetBuiltInStyle(id: styleID)
            if let updated = styleManager.style(for: styleID) {
                selectStyle(updated)
            }
        } else {
            styleManager.removeStyle(id: styleID)
            selectedStyleID = nil
            if let first = styleManager.styles.first {
                selectStyle(first)
            }
        }
    }

    /// Returns true if the style is a built-in that has NOT been modified
    private func isBuiltInOriginal(_ styleID: String) -> Bool {
        guard let style = styleManager.style(for: styleID) else { return false }
        return style.isBuiltIn
    }
}
