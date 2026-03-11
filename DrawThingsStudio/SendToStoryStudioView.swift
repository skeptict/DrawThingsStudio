//
//  SendToStoryStudioView.swift
//  DrawThingsStudio
//
//  Sheet for promoting a DT Browser image into Story Studio as a
//  character or setting reference. Pre-fills the prompt fragment for editing.
//

import SwiftUI
import SwiftData

struct SendToStoryStudioView: View {
    // Input from DT Browser
    let prompt: String
    let negativePrompt: String
    let thumbnail: NSImage?
    // Called with .storyStudio when the user taps "Open Story Studio"
    var onNavigate: ((SidebarItem) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StoryProject.name) private var projects: [StoryProject]

    @State private var selectedProject: StoryProject?
    @State private var targetType: TargetType = .character
    @State private var mode: Mode = .new
    @State private var selectedCharacter: StoryCharacter?
    @State private var selectedSetting: StorySetting?
    @State private var newName: String = ""
    @State private var promptFragment: String = ""
    @State private var didSave = false

    enum TargetType: String, CaseIterable {
        case character = "Character"
        case setting = "Setting"
    }

    enum Mode: String, CaseIterable {
        case existing = "Existing"
        case new = "New"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "theatermasks")
                    .foregroundColor(.neuAccent)
                Text(didSave ? "Added to Story Studio" : "Add to Story Studio")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(NeumorphicButtonStyle())
            }
            .padding(20)

            Divider()

            if didSave {
                confirmationView
            } else {
                formView
            }
        }
        .frame(width: 500)
        .background(Color.neuBackground)
        .onAppear {
            promptFragment = prompt
            selectedProject = projects.first
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                // Thumbnail
                if let img = thumbnail {
                    HStack {
                        Spacer()
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: Color.neuShadowDark.opacity(0.25), radius: 6, x: 3, y: 3)
                        Spacer()
                    }
                }

                // Project picker
                formSection("Project") {
                    if projects.isEmpty {
                        Text("No Story Studio projects yet — create one in Story Studio first.")
                            .font(.callout)
                            .foregroundColor(.orange)
                            .padding(10)
                            .neuInset(cornerRadius: 8)
                    } else {
                        Picker("Project", selection: $selectedProject) {
                            ForEach(projects) { project in
                                Text(project.name).tag(Optional(project))
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedProject) {
                            selectedCharacter = nil
                            selectedSetting = nil
                        }
                    }
                }

                // Character vs Setting
                formSection("Add as") {
                    Picker("Type", selection: $targetType) {
                        ForEach(TargetType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: targetType) {
                        selectedCharacter = nil
                        selectedSetting = nil
                    }
                }

                // New vs Existing + name/picker
                if selectedProject != nil {
                    formSection(targetType == .character ? "Character" : "Setting") {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        if mode == .existing {
                            existingPicker
                        } else {
                            TextField(
                                targetType == .character ? "New character name…" : "New setting name…",
                                text: $newName
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                // Prompt fragment editor
                formSection("Prompt fragment") {
                    Text("Trim to the identity-critical terms before saving.")
                        .font(.caption2)
                        .foregroundColor(.neuTextSecondary.opacity(0.7))

                    TextEditor(text: $promptFragment)
                        .font(.system(.body))
                        .frame(minHeight: 90)
                        .padding(8)
                        .neuInset(cornerRadius: 8)
                }

                // Save button
                Button(action: save) {
                    HStack {
                        Image(systemName: "theatermasks.fill")
                        Text(mode == .new
                             ? "Create \(targetType.rawValue) & Add Reference"
                             : "Add Reference to \(targetType.rawValue)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NeumorphicButtonStyle(isProminent: true))
                .controlSize(.large)
                .disabled(!canSave)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.neuTextSecondary)
            content()
        }
    }

    @ViewBuilder
    private var existingPicker: some View {
        if let project = selectedProject {
            if targetType == .character {
                let chars = project.characters.sorted { $0.name < $1.name }
                if chars.isEmpty {
                    Text("No characters in this project yet.")
                        .font(.callout).foregroundColor(.neuTextSecondary)
                } else {
                    Picker("Character", selection: $selectedCharacter) {
                        Text("Select a character…").tag(Optional<StoryCharacter>.none)
                        ForEach(chars) { c in
                            Text(c.name).tag(Optional(c))
                        }
                    }
                    .labelsHidden()
                }
            } else {
                let settings = project.settings.sorted { $0.name < $1.name }
                if settings.isEmpty {
                    Text("No settings in this project yet.")
                        .font(.callout).foregroundColor(.neuTextSecondary)
                } else {
                    Picker("Setting", selection: $selectedSetting) {
                        Text("Select a setting…").tag(Optional<StorySetting>.none)
                        ForEach(settings) { s in
                            Text(s.name).tag(Optional(s))
                        }
                    }
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.green)
            Text("Reference added")
                .font(.headline)
            Text("The image and prompt fragment have been saved to your \(targetType.rawValue.lowercased()).")
                .font(.callout)
                .foregroundColor(.neuTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                dismiss()
                onNavigate?(.storyStudio)
            } label: {
                HStack {
                    Image(systemName: "theatermasks")
                    Text("Open Story Studio")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeumorphicButtonStyle(isProminent: true))
            .controlSize(.large)
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.vertical, 30)
    }

    // MARK: - Logic

    private var canSave: Bool {
        guard selectedProject != nil, !projects.isEmpty else { return false }
        if mode == .new { return !newName.trimmingCharacters(in: .whitespaces).isEmpty }
        return targetType == .character ? selectedCharacter != nil : selectedSetting != nil
    }

    private func save() {
        guard let project = selectedProject else { return }

        let imageData: Data? = thumbnail.flatMap { img in
            img.tiffRepresentation.flatMap {
                NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
            }
        }

        let fragment = promptFragment.trimmingCharacters(in: .whitespacesAndNewlines)

        if targetType == .character {
            if mode == .new {
                let character = StoryCharacter(
                    name: newName.trimmingCharacters(in: .whitespaces),
                    promptFragment: fragment,
                    sortOrder: project.characters.count
                )
                character.primaryReferenceImageData = imageData
                character.project = project
                modelContext.insert(character)
            } else if let character = selectedCharacter {
                character.promptFragment = fragment
                character.primaryReferenceImageData = imageData
            }
        } else {
            if mode == .new {
                let setting = StorySetting(
                    name: newName.trimmingCharacters(in: .whitespaces),
                    promptFragment: fragment,
                    sortOrder: project.settings.count
                )
                setting.referenceImageData = imageData
                setting.project = project
                modelContext.insert(setting)
            } else if let setting = selectedSetting {
                setting.promptFragment = fragment
                setting.referenceImageData = imageData
            }
        }

        project.modifiedAt = Date()
        try? modelContext.save()
        didSave = true
    }
}
