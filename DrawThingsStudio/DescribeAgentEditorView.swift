//
//  DescribeAgentEditorView.swift
//  DrawThingsStudio
//
//  In-app editor for viewing, creating, editing, and deleting image description agents.
//

import SwiftUI

struct DescribeAgentEditorView: View {
    @ObservedObject var agentsManager = DescribeAgentsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAgentID: String?
    @State private var editName: String = ""
    @State private var editTargetModel: String = ""
    @State private var editSystemPrompt: String = ""
    @State private var editUserMessage: String = ""
    @State private var editPreferredVisionModel: String = ""
    @State private var editIcon: String = "eye"
    @State private var showIconPicker = false
    @State private var showDeleteConfirmation = false

    private static let availableIcons = [
        "eye", "wand.and.stars", "paintpalette", "camera", "film", "bolt",
        "paintbrush.pointed", "rectangle.3.group", "sparkles", "photo",
        "star", "heart", "lightbulb", "flame", "leaf", "globe",
        "moon", "sun.max", "cloud", "theatermasks", "pencil", "scribble",
        "cube", "cylinder", "diamond", "gearshape.2", "brain", "cpu",
        "wand.and.rays", "magnifyingglass", "viewfinder", "scope"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Describe Agents")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Edit JSON File...") {
                    agentsManager.openAgentsFile()
                }
                .buttonStyle(NeumorphicButtonStyle())
                .help("Open describe_agents.json in default editor")

                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            HSplitView {
                agentList
                    .frame(minWidth: 200, maxWidth: 250)

                if let agentID = selectedAgentID, agentsManager.agent(for: agentID) != nil {
                    agentEditor(for: agentID)
                } else {
                    emptyState
                }
            }
        }
        .frame(width: 800, height: 540)
        .neuBackground()
        .onAppear {
            if selectedAgentID == nil, let first = agentsManager.agents.first {
                selectAgent(first)
            }
        }
    }

    // MARK: - Agent List

    private var agentList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(agentsManager.agents) { agent in
                        agentRow(agent)
                    }
                }
                .padding(8)
            }

            Divider()

            Button {
                createNewAgent()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New Agent")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeumorphicButtonStyle())
            .padding(8)
        }
        .background(Color.neuSurface.opacity(0.5))
    }

    private func agentRow(_ agent: DescribeAgent) -> some View {
        Button {
            selectAgent(agent)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: agent.icon)
                    .frame(width: 20)
                    .foregroundColor(selectedAgentID == agent.id ? .white : .primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.body)
                        .foregroundColor(selectedAgentID == agent.id ? .white : .primary)

                    HStack(spacing: 4) {
                        if agent.isBuiltIn {
                            Text("built-in")
                                .font(.caption2)
                                .foregroundColor(selectedAgentID == agent.id ? .white.opacity(0.7) : .neuTextSecondary)
                        } else if BuiltInDescribeAgent(rawValue: agent.id) != nil {
                            Text(agentsManager.isBuiltInModified(id: agent.id) ? "modified" : "built-in")
                                .font(.caption2)
                                .foregroundColor(agentsManager.isBuiltInModified(id: agent.id) ? .orange : .neuTextSecondary)
                        } else {
                            Text("custom")
                                .font(.caption2)
                                .foregroundColor(selectedAgentID == agent.id ? .white.opacity(0.7) : .accentColor)
                        }
                        if !agent.targetModel.isEmpty {
                            Text("· \(agent.targetModel)")
                                .font(.caption2)
                                .foregroundColor(selectedAgentID == agent.id ? .white.opacity(0.5) : .neuTextSecondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedAgentID == agent.id ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Agent Editor

    private func agentEditor(for agentID: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Name + Icon row
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name").font(.headline)
                        TextField("Agent name", text: $editName)
                            .textFieldStyle(NeumorphicTextFieldStyle())
                            .onChange(of: editName) { _, v in updateCurrentAgent { $0.name = v } }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Model").font(.headline)
                        TextField("e.g., FLUX, SDXL", text: $editTargetModel)
                            .textFieldStyle(NeumorphicTextFieldStyle())
                            .frame(width: 130)
                            .onChange(of: editTargetModel) { _, v in updateCurrentAgent { $0.targetModel = v } }
                    }
                }

                // Icon
                VStack(alignment: .leading, spacing: 4) {
                    Text("Icon").font(.headline)
                    HStack {
                        Image(systemName: editIcon)
                            .font(.title2)
                            .frame(width: 36, height: 36)
                            .background(Color.neuSurface)
                            .cornerRadius(8)

                        Button("Choose Icon...") { showIconPicker.toggle() }
                            .buttonStyle(NeumorphicButtonStyle())

                        Spacer()
                    }

                    if showIconPicker {
                        iconPickerGrid
                    }
                }

                // Preferred vision model
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preferred Vision Model").font(.headline)
                    Text("The Ollama model to use for this agent. Leave empty to use the provider default.")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("e.g., llava:latest, moondream", text: $editPreferredVisionModel)
                        .textFieldStyle(NeumorphicTextFieldStyle())
                        .onChange(of: editPreferredVisionModel) { _, v in updateCurrentAgent { $0.preferredVisionModel = v } }
                }

                // System Prompt
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Prompt").font(.headline)
                    Text("Instructions for the vision LLM describing its role and how to format the output.")
                        .font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $editSystemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .padding(4)
                        .neuInset(cornerRadius: 8)
                        .onChange(of: editSystemPrompt) { _, v in updateCurrentAgent { $0.systemPrompt = v } }
                }

                // User Message
                VStack(alignment: .leading, spacing: 4) {
                    Text("User Message").font(.headline)
                    Text("The request sent with the image. Can include instructions specific to the output format.")
                        .font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $editUserMessage)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .padding(4)
                        .neuInset(cornerRadius: 8)
                        .onChange(of: editUserMessage) { _, v in updateCurrentAgent { $0.userMessage = v } }
                }

                // Actions
                HStack {
                    if BuiltInDescribeAgent(rawValue: agentID) != nil,
                       agentsManager.isBuiltInModified(id: agentID) {
                        Button("Reset to Default") {
                            agentsManager.resetBuiltInAgent(id: agentID)
                            if let updated = agentsManager.agent(for: agentID) {
                                selectAgent(updated)
                            }
                        }
                        .buttonStyle(NeumorphicButtonStyle())
                    }

                    Spacer()

                    if !isBuiltInOriginal(agentID) {
                        Button("Delete Agent") {
                            showDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                        .buttonStyle(NeumorphicButtonStyle())
                    }
                }
            }
            .padding(20)
        }
        .alert("Delete Agent", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteCurrentAgent() }
        } message: {
            Text("Are you sure you want to delete this agent? This cannot be undone.")
        }
    }

    private var iconPickerGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 6) {
            ForEach(Self.availableIcons, id: \.self) { icon in
                Button {
                    editIcon = icon
                    showIconPicker = false
                    updateCurrentAgent { $0.icon = icon }
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
            Image(systemName: "eye")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select an agent to edit")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func selectAgent(_ agent: DescribeAgent) {
        selectedAgentID = agent.id
        editName = agent.name
        editTargetModel = agent.targetModel
        editSystemPrompt = agent.systemPrompt
        editUserMessage = agent.userMessage
        editPreferredVisionModel = agent.preferredVisionModel
        editIcon = agent.icon
        showIconPicker = false
    }

    private func createNewAgent() {
        let id = UUID().uuidString
        let newAgent = DescribeAgent(
            id: id,
            name: "New Agent",
            targetModel: "",
            systemPrompt: "You are an expert image analyst. Describe images for AI image generation.\nOutput only the description, no explanations.",
            userMessage: "Analyze this image and write a generation prompt that would recreate it.",
            preferredVisionModel: "llava:latest",
            icon: "eye",
            isBuiltIn: false
        )
        agentsManager.addAgent(newAgent)
        selectAgent(newAgent)
    }

    private func updateCurrentAgent(_ mutation: (inout DescribeAgent) -> Void) {
        guard let agentID = selectedAgentID,
              var agent = agentsManager.agent(for: agentID) else { return }
        if agent.isBuiltIn { agent.isBuiltIn = false }
        mutation(&agent)
        agentsManager.updateAgent(agent)
    }

    private func deleteCurrentAgent() {
        guard let agentID = selectedAgentID else { return }
        let builtInIDs = Set(BuiltInDescribeAgent.allCases.map { $0.rawValue })
        if builtInIDs.contains(agentID) {
            agentsManager.resetBuiltInAgent(id: agentID)
            if let updated = agentsManager.agent(for: agentID) {
                selectAgent(updated)
            }
        } else {
            agentsManager.removeAgent(id: agentID)
            selectedAgentID = nil
            if let first = agentsManager.agents.first {
                selectAgent(first)
            }
        }
    }

    private func isBuiltInOriginal(_ agentID: String) -> Bool {
        guard let agent = agentsManager.agent(for: agentID) else { return false }
        return agent.isBuiltIn
    }
}
