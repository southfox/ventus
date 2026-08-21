//
//  ForescoopTests.swift
//  ForescoopTests
//
//  Created by Javier Fuchs on 07/26/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import XCTest
@testable import Forescoop
import CoreLocation

final class ForescoopTests: XCTestCase {
    private struct TestPreferencesProvider: ForecastPreferencesProviding {
        let forecastUnitPreferences: ForecastUnitPreferences
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Forescoop().text, "Hello, World!")
    }

    @MainActor
    func testDashboardViewModelUsesInjectedDevicePreferences() {
        let expected = ForecastUnitPreferences(
            temperatureUnit: .fahrenheit,
            windSpeedUnit: .milesPerHour,
            waveHeightUnit: .feet,
            pressureUnit: .inchesOfMercury,
            precipitationUnit: .inches,
            freezingLevelUnit: .feet
        )
        let viewModel = ForecastDashboardViewModel(
            forecastService: ForecastWindguruMockup(),
            preferencesProvider: TestPreferencesProvider(forecastUnitPreferences: expected),
            environment: .preview
        )

        XCTAssertEqual(viewModel.deviceUnitPreferences, expected)
    }

    @MainActor
    func testDashboardSessionCleanupClearsPersistedLocationsAndSelectedSpot() {
        // Each test gets its own in-memory environment, so there's no
        // production state to back up/restore around this test the way the
        // old static-store version needed to.
        let environment = AppEnvironment.preview

        let sessionLocation = SavedMapLocation(
            name: "Session location",
            coordinate: CLLocationCoordinate2D(latitude: -33.4489, longitude: -70.6693),
            spotID: "999999",
            placeDescription: "Chile"
        )
        environment.savedMapLocationStore.save(environment.savedMapLocationStore.load() + [sessionLocation])
        environment.selectedSpotStore.save(sessionLocation.spotID!)

        let viewModel = ForecastDashboardViewModel(forecastService: ForecastWindguruMockup(), environment: environment)
        viewModel.clearPersistedSessionData()

        XCTAssertEqual(viewModel.savedMapLocations.map(\.spotID), [SavedMapLocationStore.primarySpotID])
        XCTAssertEqual(environment.savedMapLocationStore.load().map(\.spotID), [SavedMapLocationStore.primarySpotID])
        XCTAssertEqual(environment.selectedSpotStore.load(), SavedMapLocationStore.primarySpotID)
    }
}
