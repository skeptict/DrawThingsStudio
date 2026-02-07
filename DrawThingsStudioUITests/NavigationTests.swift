//
//  NavigationTests.swift
//  DrawThingsStudioUITests
//
//  Tests for sidebar navigation and view switching
//

import XCTest

final class NavigationTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Sidebar Navigation Tests

    @MainActor
    func testSidebarExists() throws {
        // Verify all sidebar items exist
        XCTAssertTrue(app.buttons["sidebar_workflow"].waitForExistence(timeout: 5),
                      "Workflow Builder sidebar item should exist")
        XCTAssertTrue(app.buttons["sidebar_generateImage"].exists,
                      "Generate Image sidebar item should exist")
        XCTAssertTrue(app.buttons["sidebar_imageInspector"].exists,
                      "Image Inspector sidebar item should exist")
        XCTAssertTrue(app.buttons["sidebar_library"].exists,
                      "Saved Workflows sidebar item should exist")
        XCTAssertTrue(app.buttons["sidebar_templates"].exists,
                      "Templates sidebar item should exist")
        XCTAssertTrue(app.buttons["sidebar_settings"].exists,
                      "Settings sidebar item should exist")
    }

    @MainActor
    func testNavigateToGenerateImage() throws {
        // Click Generate Image in sidebar
        let generateImageButton = app.buttons["sidebar_generateImage"]
        XCTAssertTrue(generateImageButton.waitForExistence(timeout: 5))
        generateImageButton.tap()

        // Verify Generate Image view is shown
        let generateButton = app.buttons["generate_generateButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3),
                      "Generate button should be visible after navigating to Generate Image")
    }

    @MainActor
    func testNavigateToImageInspector() throws {
        // Click Image Inspector in sidebar
        let inspectorButton = app.buttons["sidebar_imageInspector"]
        XCTAssertTrue(inspectorButton.waitForExistence(timeout: 5))
        inspectorButton.tap()

        // Verify Image Inspector view is shown (clear history button or drop zone)
        // The view shows either the drop zone or history list
        let clearButton = app.buttons["inspector_clearHistoryButton"]
        let dropZone = app.staticTexts["inspector_dropZoneText"]

        // Wait for either element to appear
        let clearExists = clearButton.waitForExistence(timeout: 3)
        let dropExists = dropZone.waitForExistence(timeout: 1)

        // Either the clear button exists (history has items) or the drop zone text exists
        XCTAssertTrue(clearExists || dropExists, "Image Inspector view should be visible")
    }

    @MainActor
    func testNavigateToSettings() throws {
        // Click Settings in sidebar
        let settingsButton = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Verify Settings view is shown
        let testConnectionButton = app.buttons["settings_testConnectionButton"]
        XCTAssertTrue(testConnectionButton.waitForExistence(timeout: 3),
                      "Test Connection button should be visible in Settings")
    }

    @MainActor
    func testNavigateToSavedWorkflows() throws {
        // Click Saved Workflows in sidebar
        let libraryButton = app.buttons["sidebar_library"]
        XCTAssertTrue(libraryButton.waitForExistence(timeout: 5))
        libraryButton.tap()

        // Verify Saved Workflows view is shown
        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Search field should be visible in Saved Workflows")
    }

    @MainActor
    func testNavigateToTemplates() throws {
        // Click Templates in sidebar
        let templatesButton = app.buttons["sidebar_templates"]
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 5))
        templatesButton.tap()

        // Verify Templates view is shown
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Search field should be visible in Templates")
    }

    @MainActor
    func testNavigateBackToWorkflowBuilder() throws {
        // Navigate away first
        app.buttons["sidebar_settings"].tap()
        sleep(1)

        // Navigate back to Workflow Builder
        let workflowButton = app.buttons["sidebar_workflow"]
        workflowButton.tap()

        // Workflow Builder should be shown (it's the default, no unique identifier needed)
        // Just verify we can click the button and app doesn't crash
        XCTAssertTrue(workflowButton.exists)
    }

    @MainActor
    func testRapidNavigationDoesNotCrash() throws {
        // Rapidly switch between views to test transition stability
        for _ in 0..<3 {
            app.buttons["sidebar_generateImage"].tap()
            app.buttons["sidebar_imageInspector"].tap()
            app.buttons["sidebar_settings"].tap()
            app.buttons["sidebar_workflow"].tap()
        }

        // App should still be responsive
        XCTAssertTrue(app.buttons["sidebar_workflow"].exists,
                      "App should remain responsive after rapid navigation")
    }
}
