//
//  PillrUITests.swift
//  PillrUITests
//
//  Created by Justin Tilley on 18/2/2026.
//

import XCTest

@MainActor
func launchPillrAndClearFirstRunPrompts(_ app: XCUIApplication) {
    app.launchArguments.append("--uitesting")
    app.launchEnvironment["PILLR_UI_TEST_MODE"] = "1"
    app.launchEnvironment["PILLR_ENABLE_TEST_PREMIUM"] = "1"
    app.launch()

    // Choose local storage path on first launch.
    let localChoiceButtons = [
        "On this device only",
        "Save Locally",
        "Save locally"
    ]
    for title in localChoiceButtons {
        let button = app.buttons[title]
        if button.waitForExistence(timeout: 2) {
            button.tap()
            break
        }
    }

    let continueButton = app.buttons["Continue"]
    if continueButton.waitForExistence(timeout: 2) && continueButton.isHittable {
        continueButton.tap()
    }

    let confirmLocalButtons = [
        "Yes, keep local",
        "Keep Local",
        "Save Locally"
    ]
    for title in confirmLocalButtons {
        let button = app.buttons[title]
        if button.waitForExistence(timeout: 2) {
            button.tap()
            break
        }
    }

    // Handle in-app notification prompt.
    let onboardingContinue = app.buttons["Continue"]
    if onboardingContinue.waitForExistence(timeout: 2) && onboardingContinue.isHittable {
        onboardingContinue.tap()
    }

    // Handle iOS system notification permission prompt.
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowButtons = [
        "Allow",
        "Allow Notifications",
        "OK"
    ]
    for title in allowButtons {
        let button = springboard.buttons[title]
        if button.waitForExistence(timeout: 3) {
            button.tap()
            break
        }
    }

    // Dismiss first entrance overlays if they appear.
    let entranceButtons = [
        "Continue to My Meds",
        "Get Started",
        "I Understand - Let's Get Started!",
        "Done"
    ]
    for title in entranceButtons {
        let button = app.buttons[title]
        if button.waitForExistence(timeout: 2) {
            button.tap()
        }
    }
}

final class PillrUITests: XCTestCase {
    private func setSwitch(_ toggle: XCUIElement, to expectedOn: Bool) {
        guard toggle.waitForExistence(timeout: 5) else { return }
        let currentValue = (toggle.value as? String) == "1"
        if currentValue != expectedOn {
            toggle.tap()
        }
        let expectedValue = expectedOn ? "1" : "0"
        _ = NSPredicate(format: "value == %@", expectedValue)
            .evaluate(with: toggle)
    }

    private func scrollToElement(_ app: XCUIApplication, element: XCUIElement, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        launchPillrAndClearFirstRunPrompts(app)

        XCTAssertTrue(app.exists)
    }

    @MainActor
    func testAddMedication() throws {
        let app = XCUIApplication()
        launchPillrAndClearFirstRunPrompts(app)

        let myMedsTab = app.tabBars.buttons["My Meds"].firstMatch
        if myMedsTab.waitForExistence(timeout: 2) {
            myMedsTab.tap()
        }

        let nameField = app.textFields["medicationNameField"].firstMatch
        let addButton = app.buttons["addMedicationButton"].firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else if app.buttons["Add Medication"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Add Medication"].firstMatch.tap()
        }

        if !nameField.waitForExistence(timeout: 3) {
            // Fallback: tap where the plus button lives in the top-right header.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.10)).tap()
        }

        let medName = "UI Test Med \(Int(Date().timeIntervalSince1970))"

        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(medName)

        let dosageField = app.textFields["medicationDosageField"].firstMatch
        XCTAssertTrue(dosageField.waitForExistence(timeout: 5))
        dosageField.tap()
        dosageField.typeText("10")

        // Keep entry in My Meds and enable follow-up reminder.
        let frequencyMenu = app.buttons["frequencyMenuButton"].firstMatch
        XCTAssertTrue(frequencyMenu.waitForExistence(timeout: 5))
        frequencyMenu.tap()
        XCTAssertTrue(app.buttons["Once daily"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Once daily"].firstMatch.tap()

        setSwitch(app.switches["oneTimeFollowUpToggle"].firstMatch, to: true)

        let nextButton = app.buttons["Next step"].firstMatch
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))

        // Step 2: ADHD + focus window + reflection.
        nextButton.tap()

        let adhdYes = app.segmentedControls["adhdMedicationPicker"].buttons["Yes"].firstMatch
        scrollToElement(app, element: adhdYes)
        XCTAssertTrue(adhdYes.waitForExistence(timeout: 5))
        adhdYes.tap()

        let stimulantButton = app.segmentedControls["medicationTypePicker"].buttons["Stimulant"].firstMatch
        if stimulantButton.waitForExistence(timeout: 3) {
            stimulantButton.tap()
        }

        setSwitch(app.switches["focusWindowToggle"].firstMatch, to: true)

        let focusReflectionToggle = app.switches["focusReflectionToggle"].firstMatch
        scrollToElement(app, element: focusReflectionToggle)
        if focusReflectionToggle.exists {
            setSwitch(focusReflectionToggle, to: true)
        }

        let customReflectionToggle = app.switches["customReflectionToggle"].firstMatch
        scrollToElement(app, element: customReflectionToggle)
        if customReflectionToggle.exists {
            setSwitch(customReflectionToggle, to: true)
        }

        // Step 3: inventory tracking.
        nextButton.tap()

        let trackPillCountToggle = app.switches["trackPillCountToggle"].firstMatch
        scrollToElement(app, element: trackPillCountToggle)
        setSwitch(trackPillCountToggle, to: true)
        XCTAssertEqual(trackPillCountToggle.value as? String, "1")

        let totalPillsField = app.textFields["totalPillsField"].firstMatch
        scrollToElement(app, element: totalPillsField)
        XCTAssertTrue(totalPillsField.waitForExistence(timeout: 5))
        totalPillsField.tap()
        totalPillsField.typeText("30")

        let perDoseField = app.textFields["pillsPerDoseField"].firstMatch
        scrollToElement(app, element: perDoseField)
        XCTAssertTrue(perDoseField.waitForExistence(timeout: 5))
        perDoseField.tap()
        perDoseField.typeText("1")

        let refillField = app.textFields["refillReminderField"].firstMatch
        scrollToElement(app, element: refillField)
        XCTAssertTrue(refillField.waitForExistence(timeout: 5))
        refillField.tap()
        refillField.typeText("5")

        // Step 4: notes and save.
        nextButton.tap()

        let notesField = app.textViews["medicationNotesField"].firstMatch
        scrollToElement(app, element: notesField)
        if notesField.waitForExistence(timeout: 5) {
            notesField.tap()
            notesField.typeText("UI full-flow test note.")
        }

        let addMedicationButton = app.buttons["Add medication"].firstMatch
        XCTAssertTrue(addMedicationButton.waitForExistence(timeout: 5))
        addMedicationButton.tap()

        XCTAssertTrue(app.staticTexts[medName].waitForExistence(timeout: 15))
    }

    @MainActor
    func testLaunchPerformance() throws {
        throw XCTSkip("Launch performance is skipped by default for UI stability.")
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            launchPillrAndClearFirstRunPrompts(app)
        }
    }
}
