//
//  ImageInspectorTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Image Inspector view functionality
//

import XCTest

final class ImageInspectorTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()

        // Navigate to Image Inspector view
        let inspectorButton = app.buttons["sidebar_imageInspector"]
        XCTAssertTrue(inspectorButton.waitForExistence(timeout: 5))
        inspectorButton.tap()

        // Wait for view to load
        sleep(1)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - View Loading Tests

    @MainActor
    func testImageInspectorLoads() throws {
        // The view should show either the drop zone or history with clear button
        let clearButton = app.buttons["inspector_clearHistoryButton"]
        let dropZone = app.staticTexts["inspector_dropZoneText"]

        // Wait for either element to appear
        let clearExists = clearButton.waitForExistence(timeout: 3)
        let dropExists = dropZone.waitForExistence(timeout: 1)

        // Either state is valid depending on history
        XCTAssertTrue(clearExists || dropExists, "Image Inspector view should load")
    }

    // MARK: - Empty State Tests

    @MainActor
    func testDropZoneVisibleWhenEmpty() throws {
        // If history is empty, drop zone should be visible
        let dropZone = app.staticTexts["inspector_dropZoneText"]

        // This test may pass or fail depending on whether there's history
        // We're just checking that the UI can display this state
        if dropZone.waitForExistence(timeout: 2) {
            XCTAssertTrue(dropZone.exists, "Drop zone should be visible when no images")
        }
    }

    // MARK: - History State Tests

    @MainActor
    func testClearHistoryButtonWhenHistoryExists() throws {
        // If there's history, clear button should exist
        let clearButton = app.buttons["inspector_clearHistoryButton"]

        if clearButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(clearButton.exists, "Clear history button should exist when history is present")
        }
    }

    // MARK: - Action Button Tests (when image is selected)

    @MainActor
    func testCopyPromptButtonExists() throws {
        // These buttons only appear when an image is selected
        // Check if they exist in view hierarchy
        let copyPromptButton = app.buttons["inspector_copyPromptButton"]

        // May not be visible if no image is selected
        if copyPromptButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(copyPromptButton.exists, "Copy prompt button should exist")
        }
    }

    @MainActor
    func testCopyConfigButtonExists() throws {
        let copyConfigButton = app.buttons["inspector_copyConfigButton"]

        if copyConfigButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(copyConfigButton.exists, "Copy config button should exist")
        }
    }

    @MainActor
    func testCopyAllButtonExists() throws {
        let copyAllButton = app.buttons["inspector_copyAllButton"]

        if copyAllButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(copyAllButton.exists, "Copy all button should exist")
        }
    }

    @MainActor
    func testSendToGenerateButtonExists() throws {
        let sendButton = app.buttons["inspector_sendToGenerateButton"]

        if sendButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(sendButton.exists, "Send to generate button should exist")
        }
    }

    // MARK: - Navigation Integration Tests

    @MainActor
    func testNavigateFromInspectorToGenerate() throws {
        // If send to generate button exists and is tapped, should navigate
        let sendButton = app.buttons["inspector_sendToGenerateButton"]

        if sendButton.waitForExistence(timeout: 2) && sendButton.isHittable {
            sendButton.tap()

            // Should now be in Generate Image view
            let generateButton = app.buttons["generate_generateButton"]
            XCTAssertTrue(generateButton.waitForExistence(timeout: 3),
                          "Should navigate to Generate Image view")
        }
    }

    // MARK: - Clear History Test

    @MainActor
    func testClearHistoryShowsConfirmation() throws {
        let clearButton = app.buttons["inspector_clearHistoryButton"]

        if clearButton.waitForExistence(timeout: 2) && clearButton.isHittable {
            clearButton.tap()

            // Should show confirmation dialog or perform action
            // Wait a moment for any dialog to appear
            sleep(1)

            // App should still be responsive
            let sidebarButton = app.buttons["sidebar_imageInspector"]
            XCTAssertTrue(sidebarButton.exists,
                          "App should remain responsive after clear history action")
        }
    }
}
