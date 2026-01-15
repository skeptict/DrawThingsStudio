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
                    TemplatesLibraryView()
                } else if selectedItem == .settings {
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
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

struct TemplatesLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Templates Library")
                .font(.title2)
            Text("Access templates from the Templates button in the Workflow Builder toolbar.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
