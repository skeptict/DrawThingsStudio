//
//  DrawThingsStudioApp.swift
//  DrawThingsStudio
//
//  Created by skeptict on 1/14/26.
//

import SwiftUI

@main
struct DrawThingsStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                // New workflow command
                Button("New Workflow") {
                    // Handled by the WorkflowBuilderView
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
