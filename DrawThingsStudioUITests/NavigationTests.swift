//
//  NavigationTests.swift
//  DrawThingsStudioUITests
//
//  Tests for sidebar navigation and view switching
//

import XCTest

final class NavigationTests: XCTestCase {

    var app: XCUIApplication { SharedApp.app }

    override class func setUp() {
        super.setUp()
        SharedApp.launchOnce()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Sidebar Navigation Tests

    @MainActor
    func testSidebarExists() throws {
        XCTAssertTrue(app.buttons["sidebar_workflow"].waitForExistence(timeout: 10),
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
        app.buttons["sidebar_generateImage"].tap()
        let generateButton = app.buttons["generate_generateButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5),
                      "Generate button should be visible after navigating to Generate Image")
    }

    @MainActor
    func testNavigateToImageInspector() throws {
        app.buttons["sidebar_imageInspector"].tap()
        let clearButton = app.buttons["inspector_clearHistoryButton"]
        let dropZone = app.staticTexts["inspector_dropZoneText"]
        let clearExists = clearButton.waitForExistence(timeout: 5)
        let dropExists = dropZone.waitForExistence(timeout: 1)
        XCTAssertTrue(clearExists || dropExists, "Image Inspector view should be visible")
    }

    @MainActor
    func testNavigateToSettings() throws {
        app.buttons["sidebar_settings"].tap()
        let testConnectionButton = app.buttons["settings_testConnectionButton"]
        XCTAssertTrue(testConnectionButton.waitForExistence(timeout: 5),
                      "Test Connection button should be visible in Settings")
    }

    @MainActor
    func testNavigateToSavedWorkflows() throws {
        app.buttons["sidebar_library"].tap()
        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field should be visible in Saved Workflows")
    }

    @MainActor
    func testNavigateToTemplates() throws {
        app.buttons["sidebar_templates"].tap()
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Search field should be visible in Templates")
    }

    @MainActor
    func testNavigateBackToWorkflowBuilder() throws {
        app.buttons["sidebar_settings"].tap()
        waitForUI(seconds: 1)
        app.buttons["sidebar_workflow"].tap()
        XCTAssertTrue(app.buttons["sidebar_workflow"].exists)
    }

    @MainActor
    func testRapidNavigationDoesNotCrash() throws {
        for _ in 0..<3 {
            app.buttons["sidebar_generateImage"].tap()
            app.buttons["sidebar_imageInspector"].tap()
            app.buttons["sidebar_settings"].tap()
            app.buttons["sidebar_workflow"].tap()
        }
        XCTAssertTrue(app.buttons["sidebar_workflow"].exists,
                      "App should remain responsive after rapid navigation")
    }
}
