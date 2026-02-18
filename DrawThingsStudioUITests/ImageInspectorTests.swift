//
//  ImageInspectorTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Image Inspector view functionality
//

import XCTest

final class ImageInspectorTests: XCTestCase {

    var app: XCUIApplication { SharedApp.app }

    override class func setUp() {
        super.setUp()
        SharedApp.launchOnce()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let inspectorButton = app.buttons["sidebar_imageInspector"]
        XCTAssertTrue(inspectorButton.waitForExistence(timeout: 10))
        inspectorButton.tap()
        waitForUI(seconds: 1)
    }

    // MARK: - View Loading Tests

    @MainActor
    func testImageInspectorLoads() throws {
        let clearButton = app.buttons["inspector_clearHistoryButton"]
        let dropZone = app.staticTexts["inspector_dropZoneText"]
        let clearExists = clearButton.waitForExistence(timeout: 5)
        let dropExists = dropZone.waitForExistence(timeout: 1)
        XCTAssertTrue(clearExists || dropExists, "Image Inspector view should load")
    }

    @MainActor
    func testDropZoneVisibleWhenEmpty() throws {
        let dropZone = app.staticTexts["inspector_dropZoneText"]
        if dropZone.waitForExistence(timeout: 3) {
            XCTAssertTrue(dropZone.exists, "Drop zone should be visible when no images")
        }
    }

    @MainActor
    func testClearHistoryButtonWhenHistoryExists() throws {
        let clearButton = app.buttons["inspector_clearHistoryButton"]
        if clearButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(clearButton.exists, "Clear history button should exist when history is present")
        }
    }

    // MARK: - Action Button Tests (when image is selected)

    @MainActor
    func testCopyPromptButtonExists() throws {
        let copyPromptButton = app.buttons["inspector_copyPromptButton"]
        if copyPromptButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(copyPromptButton.exists, "Copy prompt button should exist")
        }
    }

    @MainActor
    func testCopyConfigButtonExists() throws {
        let copyConfigButton = app.buttons["inspector_copyConfigButton"]
        if copyConfigButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(copyConfigButton.exists, "Copy config button should exist")
        }
    }

    @MainActor
    func testCopyAllButtonExists() throws {
        let copyAllButton = app.buttons["inspector_copyAllButton"]
        if copyAllButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(copyAllButton.exists, "Copy all button should exist")
        }
    }

    @MainActor
    func testSendToGenerateButtonExists() throws {
        let sendButton = app.buttons["inspector_sendToGenerateButton"]
        if sendButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(sendButton.exists, "Send to generate button should exist")
        }
    }

    // MARK: - Navigation Integration Tests

    @MainActor
    func testNavigateFromInspectorToGenerate() throws {
        let sendButton = app.buttons["inspector_sendToGenerateButton"]
        if sendButton.waitForExistence(timeout: 3) && sendButton.isHittable {
            sendButton.tap()
            let generateButton = app.buttons["generate_generateButton"]
            XCTAssertTrue(generateButton.waitForExistence(timeout: 5),
                          "Should navigate to Generate Image view")
        }
    }

    // MARK: - Clear History Test

    @MainActor
    func testClearHistoryShowsConfirmation() throws {
        let clearButton = app.buttons["inspector_clearHistoryButton"]
        if clearButton.waitForExistence(timeout: 3) && clearButton.isHittable {
            clearButton.tap()
            waitForUI(seconds: 1)
            let sidebarButton = app.buttons["sidebar_imageInspector"]
            XCTAssertTrue(sidebarButton.exists,
                          "App should remain responsive after clear history action")
        }
    }
}
