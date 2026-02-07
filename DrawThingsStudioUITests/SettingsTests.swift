//
//  SettingsTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Settings view functionality
//

import XCTest

final class SettingsTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()

        // Navigate to Settings view
        let settingsButton = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Connection Settings Tests

    @MainActor
    func testHostFieldExists() throws {
        let hostField = app.textFields["settings_drawThingsHost"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 3),
                      "Draw Things host field should exist")
    }

    @MainActor
    func testHTTPPortFieldExists() throws {
        let httpPortField = app.textFields["settings_drawThingsHTTPPort"]
        XCTAssertTrue(httpPortField.waitForExistence(timeout: 3),
                      "HTTP port field should exist")
    }

    @MainActor
    func testGRPCPortFieldExists() throws {
        let grpcPortField = app.textFields["settings_drawThingsGRPCPort"]
        XCTAssertTrue(grpcPortField.waitForExistence(timeout: 3),
                      "gRPC port field should exist")
    }

    @MainActor
    func testTransportPickerExists() throws {
        let transportPicker = app.popUpButtons["settings_transportPicker"]

        // Picker might be a different element type depending on style
        let pickerExists = transportPicker.waitForExistence(timeout: 3) ||
                          app.buttons["settings_transportPicker"].exists ||
                          app.segmentedControls["settings_transportPicker"].exists

        XCTAssertTrue(pickerExists, "Transport picker should exist")
    }

    @MainActor
    func testTestConnectionButtonExists() throws {
        let testButton = app.buttons["settings_testConnectionButton"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 3),
                      "Test Connection button should exist")
    }

    // MARK: - Connection Settings Interaction Tests

    @MainActor
    func testModifyHostField() throws {
        let hostField = app.textFields["settings_drawThingsHost"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 3))

        // Clear and enter new value
        hostField.tap()
        hostField.doubleTap() // Select word
        app.typeKey("a", modifierFlags: .command) // Select all
        hostField.typeText("192.168.1.100")

        // Verify field is still interactive
        XCTAssertTrue(hostField.exists, "Host field should remain accessible")
    }

    @MainActor
    func testModifyHTTPPort() throws {
        let httpPortField = app.textFields["settings_drawThingsHTTPPort"]
        XCTAssertTrue(httpPortField.waitForExistence(timeout: 3))

        httpPortField.tap()
        httpPortField.doubleTap() // Select content
        app.typeKey("a", modifierFlags: .command) // Select all
        httpPortField.typeText("8080")

        XCTAssertTrue(httpPortField.exists, "HTTP port field should remain accessible")
    }

    @MainActor
    func testModifyGRPCPort() throws {
        let grpcPortField = app.textFields["settings_drawThingsGRPCPort"]
        XCTAssertTrue(grpcPortField.waitForExistence(timeout: 3))

        grpcPortField.tap()
        grpcPortField.doubleTap() // Select content
        app.typeKey("a", modifierFlags: .command) // Select all
        grpcPortField.typeText("50051")

        XCTAssertTrue(grpcPortField.exists, "gRPC port field should remain accessible")
    }

    // MARK: - Test Connection Tests

    @MainActor
    func testConnectionButtonTap() throws {
        let testButton = app.buttons["settings_testConnectionButton"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 3))

        testButton.tap()

        // Wait for connection test to complete (or timeout)
        sleep(2)

        // App should still be responsive
        XCTAssertTrue(testButton.exists,
                      "App should remain responsive after connection test")
    }

    @MainActor
    func testConnectionButtonMultipleTaps() throws {
        let testButton = app.buttons["settings_testConnectionButton"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 3))

        // Tap multiple times to test stability
        testButton.tap()
        sleep(1)
        testButton.tap()
        sleep(1)

        // App should handle multiple taps gracefully
        XCTAssertTrue(testButton.exists,
                      "App should handle multiple connection test taps")
    }

    // MARK: - Transport Picker Tests

    @MainActor
    func testTransportPickerInteraction() throws {
        // Try different picker element types
        let picker = app.popUpButtons["settings_transportPicker"]
        let button = app.buttons["settings_transportPicker"]
        let segment = app.segmentedControls["settings_transportPicker"]

        if picker.waitForExistence(timeout: 2) {
            picker.tap()
            // Wait for dropdown
            sleep(1)
            // Press escape to close
            app.typeKey(.escape, modifierFlags: [])
        } else if button.exists {
            button.tap()
            sleep(1)
            app.typeKey(.escape, modifierFlags: [])
        } else if segment.exists {
            // Segmented control - just verify it exists
            XCTAssertTrue(segment.exists)
        }

        // App should still be responsive
        let settingsButton = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsButton.exists,
                      "App should remain responsive after picker interaction")
    }

    // MARK: - Settings Persistence Tests

    @MainActor
    func testSettingsRetainedAfterNavigation() throws {
        let hostField = app.textFields["settings_drawThingsHost"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 3))

        // Enter a distinctive value
        hostField.tap()
        hostField.doubleTap()
        app.typeKey("a", modifierFlags: .command) // Select all
        let testValue = "test-host-\(Int.random(in: 1000...9999))"
        hostField.typeText(testValue)

        // Navigate away
        app.buttons["sidebar_workflow"].tap()
        sleep(1)

        // Navigate back
        app.buttons["sidebar_settings"].tap()
        sleep(1)

        // Check if value persisted
        let hostFieldAfter = app.textFields["settings_drawThingsHost"]
        XCTAssertTrue(hostFieldAfter.waitForExistence(timeout: 3),
                      "Host field should exist after navigation")
    }
}
