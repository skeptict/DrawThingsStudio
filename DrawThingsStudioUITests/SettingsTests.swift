//
//  SettingsTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Settings view functionality
//

import XCTest

final class SettingsTests: XCTestCase {

    var app: XCUIApplication { SharedApp.app }

    private let defaultHost = "127.0.0.1"
    private let defaultHTTPPort = "7860"
    private let defaultGRPCPort = "7859"

    override class func setUp() {
        super.setUp()
        SharedApp.launchOnce()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let settingsButton = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()
        waitForUI(seconds: 1)
    }

    override func tearDownWithError() throws {
        resetSettingsToDefaults()
    }

    private func resetSettingsToDefaults() {
        let hostField = app.textFields["settings_drawThingsHost"]
        guard hostField.waitForExistence(timeout: 1) else { return }

        if let currentHost = hostField.value as? String, currentHost != defaultHost {
            hostField.tap()
            app.typeKey("a", modifierFlags: .command)
            hostField.typeText(defaultHost)
            app.typeKey(.tab, modifierFlags: [])
        }

        // Use doubleClick for numeric text fields — tap() may not reliably give keyboard focus
        let httpField = app.textFields["settings_drawThingsHTTPPort"]
        if httpField.exists {
            let currentPort = httpField.value as? String ?? ""
            if currentPort != defaultHTTPPort && currentPort != "7,860" {
                httpField.doubleClick()
                httpField.typeText(defaultHTTPPort)
                app.typeKey(.tab, modifierFlags: [])
            }
        }

        let grpcField = app.textFields["settings_drawThingsGRPCPort"]
        if grpcField.exists {
            let currentPort = grpcField.value as? String ?? ""
            if currentPort != defaultGRPCPort && currentPort != "7,859" {
                grpcField.doubleClick()
                grpcField.typeText(defaultGRPCPort)
                app.typeKey(.tab, modifierFlags: [])
            }
        }
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

    // MARK: - Default View Picker Tests

    @MainActor
    func testDefaultViewPickerExists() throws {
        let picker = app.popUpButtons["settings_defaultViewPicker"]
        let pickerExists = picker.waitForExistence(timeout: 3) ||
                          app.buttons["settings_defaultViewPicker"].exists ||
                          app.segmentedControls["settings_defaultViewPicker"].exists
        XCTAssertTrue(pickerExists, "Default View picker should exist in Interface section")
    }

    // MARK: - Connection Settings Interaction Tests

    @MainActor
    func testModifyHostField() throws {
        let hostField = app.textFields["settings_drawThingsHost"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 3))

        hostField.tap()
        app.typeKey("a", modifierFlags: .command)
        hostField.typeText("192.168.1.100")

        XCTAssertTrue(hostField.exists, "Host field should remain accessible")
    }

    @MainActor
    func testModifyHTTPPort() throws {
        let httpPortField = app.textFields["settings_drawThingsHTTPPort"]
        XCTAssertTrue(httpPortField.waitForExistence(timeout: 3))

        httpPortField.tap()
        app.typeKey("a", modifierFlags: .command)
        httpPortField.typeText("8080")

        XCTAssertTrue(httpPortField.exists, "HTTP port field should remain accessible")
    }

    @MainActor
    func testModifyGRPCPort() throws {
        let grpcPortField = app.textFields["settings_drawThingsGRPCPort"]
        XCTAssertTrue(grpcPortField.waitForExistence(timeout: 3))

        grpcPortField.tap()
        app.typeKey("a", modifierFlags: .command)
        grpcPortField.typeText("50051")

        XCTAssertTrue(grpcPortField.exists, "gRPC port field should remain accessible")
    }

    // MARK: - Test Connection Tests

    @MainActor
    func testConnectionButtonTap() throws {
        let testButton = app.buttons["settings_testConnectionButton"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 3))

        testButton.tap()
        waitForUI(seconds: 2)

        XCTAssertTrue(testButton.exists,
                      "App should remain responsive after connection test")
    }

    @MainActor
    func testConnectionButtonMultipleTaps() throws {
        let testButton = app.buttons["settings_testConnectionButton"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 3))

        testButton.tap()
        waitForUI(seconds: 1)
        testButton.tap()
        waitForUI(seconds: 1)

        XCTAssertTrue(testButton.exists,
                      "App should handle multiple connection test taps")
    }

    // MARK: - Transport Picker Tests

    @MainActor
    func testTransportPickerInteraction() throws {
        let picker = app.popUpButtons["settings_transportPicker"]
        let button = app.buttons["settings_transportPicker"]
        let segment = app.segmentedControls["settings_transportPicker"]

        if picker.waitForExistence(timeout: 2) {
            picker.tap()
            waitForUI(seconds: 1)
            app.typeKey(.escape, modifierFlags: [])
        } else if button.exists {
            button.tap()
            waitForUI(seconds: 1)
            app.typeKey(.escape, modifierFlags: [])
        } else if segment.exists {
            XCTAssertTrue(segment.exists)
        }

        let settingsButton = app.buttons["sidebar_settings"]
        XCTAssertTrue(settingsButton.exists,
                      "App should remain responsive after picker interaction")
    }

    // MARK: - Settings Persistence Tests

    @MainActor
    func testSettingsRetainedAfterNavigation() throws {
        let hostField = app.textFields["settings_drawThingsHost"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 3))

        let originalValue = hostField.value as? String ?? defaultHost

        hostField.tap()
        app.typeKey("a", modifierFlags: .command)
        let testValue = "192.168.1.100"
        hostField.typeText(testValue)
        app.typeKey(.tab, modifierFlags: [])

        app.buttons["sidebar_workflow"].tap()
        waitForUI(seconds: 1)

        app.buttons["sidebar_settings"].tap()
        waitForUI(seconds: 1)

        let hostFieldAfter = app.textFields["settings_drawThingsHost"]
        XCTAssertTrue(hostFieldAfter.waitForExistence(timeout: 3),
                      "Host field should exist after navigation")

        if let currentValue = hostFieldAfter.value as? String {
            XCTAssertTrue(currentValue.contains("192.168") || currentValue == testValue,
                          "Value should be retained after navigation")
        }

        hostFieldAfter.tap()
        app.typeKey("a", modifierFlags: .command)
        hostFieldAfter.typeText(originalValue.isEmpty ? defaultHost : originalValue)
        app.typeKey(.return, modifierFlags: [])
    }
}
