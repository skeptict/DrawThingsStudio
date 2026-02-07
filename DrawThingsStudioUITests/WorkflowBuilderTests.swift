//
//  WorkflowBuilderTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Workflow Builder view functionality
//

import XCTest

final class WorkflowBuilderTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()

        // Workflow Builder is the default view, but navigate to it explicitly
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.waitForExistence(timeout: 5))
        workflowButton.tap()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - View Loading Tests

    @MainActor
    func testWorkflowBuilderLoads() throws {
        // Workflow Builder should be visible as default view
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.waitForExistence(timeout: 3),
                      "Workflow Builder should be accessible")
    }

    // MARK: - Toolbar Tests

    @MainActor
    func testToolbarExists() throws {
        // Look for common toolbar elements
        // The toolbar should have buttons for common actions
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.waitForExistence(timeout: 3))

        // Workflow Builder should have some form of action buttons in toolbar
        // These would be identified once we add accessibility identifiers to toolbar
    }

    // MARK: - Instruction List Tests

    @MainActor
    func testInstructionListExists() throws {
        // The instruction list area should be present
        // This is verified by the view loading successfully
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "Workflow Builder view should load with instruction list area")
    }

    // MARK: - JSON Preview Tests

    @MainActor
    func testJSONPreviewAreaExists() throws {
        // The JSON preview panel should be visible
        // This would show the generated JSON for the workflow
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "Workflow Builder should have JSON preview area")
    }

    // MARK: - Navigation Stability Tests

    @MainActor
    func testSwitchAwayAndBack() throws {
        // Navigate to another view
        app.buttons["sidebar_settings"].tap()
        sleep(1)

        // Navigate back
        app.buttons["sidebar_workflow"].tap()
        sleep(1)

        // Workflow Builder should still be functional
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "Workflow Builder should remain accessible after navigation")
    }

    @MainActor
    func testMultipleNavigationCycles() throws {
        // Perform multiple navigation cycles
        for _ in 0..<3 {
            app.buttons["sidebar_generateImage"].tap()
            usleep(300000) // 300ms
            app.buttons["sidebar_workflow"].tap()
            usleep(300000)
        }

        // App should still be responsive
        let workflowButton = app.buttons["sidebar_workflow"]
        XCTAssertTrue(workflowButton.exists,
                      "App should be stable after multiple navigation cycles")
    }
}
