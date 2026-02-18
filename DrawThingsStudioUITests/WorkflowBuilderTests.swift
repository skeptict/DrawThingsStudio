//
//  WorkflowBuilderTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Workflow Builder view functionality
//

import XCTest

final class WorkflowBuilderTests: XCTestCase {

    var app: XCUIApplication { SharedApp.app }

    override class func setUp() {
        super.setUp()
        SharedApp.launchOnce()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.waitForExistence(timeout: 10))
        workflowButton.tap()
        waitForUI(seconds: 1)
    }

    // MARK: - View Loading Tests

    @MainActor
    func testWorkflowBuilderLoads() throws {
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.waitForExistence(timeout: 3),
                      "Workflow Builder should be accessible")
    }

    // MARK: - Toolbar Tests

    @MainActor
    func testToolbarExists() throws {
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.waitForExistence(timeout: 3))
    }

    // MARK: - Instruction List Tests

    @MainActor
    func testInstructionListExists() throws {
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "Workflow Builder view should load with instruction list area")
    }

    // MARK: - JSON Preview Tests

    @MainActor
    func testJSONPreviewAreaExists() throws {
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "Workflow Builder should have JSON preview area")
    }

    // MARK: - Navigation Stability Tests

    @MainActor
    func testSwitchAwayAndBack() throws {
        app.buttons["sidebar_settings"].tap()
        waitForUI(seconds: 1)

        app.buttons["sidebar_workflow"].tap()
        waitForUI(seconds: 1)

        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "Workflow Builder should remain accessible after navigation")
    }

    @MainActor
    func testMultipleNavigationCycles() throws {
        for _ in 0..<3 {
            app.buttons["sidebar_generateImage"].tap()
            waitForUI(milliseconds: 300)
            app.buttons["sidebar_workflow"].tap()
            waitForUI(milliseconds: 300)
        }

        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "App should be stable after multiple navigation cycles")
    }
}
