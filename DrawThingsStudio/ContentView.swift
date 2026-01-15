//
//  ContentView.swift
//  DrawThingsStudio
//
//  Main content view for the application
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView()
                .frame(minWidth: 200)
        } detail: {
            // Main content
            WorkflowBuilderView()
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @State private var selectedItem: SidebarItem? = .workflow

    var body: some View {
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
    }
}

enum SidebarItem: String, Identifiable {
    case workflow
    case library
    case templates
    case settings

    var id: String { rawValue }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
