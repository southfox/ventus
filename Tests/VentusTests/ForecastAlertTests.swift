import XCTest
@testable import Ventus

@MainActor
final class ForecastAlertTests: XCTestCase {
    private final class NotificationsStore: ForecastSevereWeatherNotificationsStoring, @unchecked Sendable {
        var isEnabled: Bool

        init(isEnabled: Bool = true) {
            self.isEnabled = isEnabled
        }

        func load() -> Bool { isEnabled }
        func save(_ isEnabled: Bool) { self.isEnabled = isEnabled }
    }

    private final class AlertsStore: ForecastAlertStoring, @unchecked Sendable {
        var alerts = [ForecastAlert]()

        func load() -> [ForecastAlert] { alerts }
        func save(_ alert: ForecastAlert) { alerts.append(alert) }
        func remove(_ alert: ForecastAlert) { alerts.removeAll { $0.id == alert.id } }
        func setActive(_ isActive: Bool, for alertID: UUID) {
            guard let index = alerts.firstIndex(where: { $0.id == alertID }) else { return }
            alerts[index].isActive = isActive
        }
    }

    private final class PreferencesStore: VentusPreferenceStoring, @unchecked Sendable {
        private var values = [String: String]()

        func value(forKey key: String) -> String? { values[key] }
        func save(_ value: String, forKey key: String) { values[key] = value }
    }

    func testPrecipitationPhaseUsesFreezingLevelBeforeTemperature() {
        XCTAssertEqual(
            PrecipitationPhase(freezingLevelMeters: 750, altitudeMeters: 900, temperatureCelsius: 5),
            .snow
        )
        XCTAssertEqual(
            PrecipitationPhase(freezingLevelMeters: 1_200, altitudeMeters: 900, temperatureCelsius: 2),
            .sleet
        )
        XCTAssertEqual(
            PrecipitationPhase(freezingLevelMeters: nil, altitudeMeters: 0, temperatureCelsius: 8),
            .rain
        )
    }

    func testSevereNotifierDetectsHeavySnow() throws {
        let notifier = makeNotifier()
        let forecast = try makeForecast(temperature: -2, precipitation: 9, freezingLevel: 500, altitude: 800)

        let alert = notifier.evaluate(forecast)

        XCTAssertEqual(alert?.kind, "heavy-snow")
        XCTAssertEqual(alert?.hour, "0")
        XCTAssertTrue(alert?.title.contains("Heavy snow") == true)
    }

    func testSevereNotifierDetectsExtremeColdAndHeat() throws {
        let notifier = makeNotifier()

        XCTAssertEqual(notifier.evaluate(try makeForecast(temperature: -12))?.kind, "extreme-cold")
        XCTAssertEqual(notifier.evaluate(try makeForecast(temperature: 36))?.kind, "extreme-heat")
    }

    func testSevereNotifierDoesNothingWhenNotificationsAreDisabled() throws {
        let notifier = makeNotifier(notificationsEnabled: false)

        XCTAssertNil(notifier.evaluate(try makeForecast(temperature: 38)))
    }

    func testCustomAlertEvaluatorFindsTheFirstMatchingFutureHour() throws {
        let forecast = try makeForecast(temperature: 10, windSpeedByHour: ["0": 8, "3": 24, "6": 30])
        let alert = ForecastAlert(
            spotID: "test-spot",
            spotDisplayName: "Test spot",
            conditions: [ForecastAlertCondition(variable: .windSpeed, comparator: .greaterThanOrEqual, value: 20)],
            considerForecastUpToDay: 1
        )

        let match = ForecastAlertEvaluator.matchingHour(for: alert, in: forecast)

        XCTAssertEqual(match?.hour, "3")
    }

    func testCustomAlertEvaluatorRequiresEveryCondition() throws {
        let forecast = try makeForecast(temperature: 22, precipitation: 0, windSpeedByHour: ["0": 8, "3": 24, "6": 30])
        let alert = ForecastAlert(
            spotID: "test-spot",
            spotDisplayName: "Test spot",
            conditions: [
                ForecastAlertCondition(variable: .windSpeed, comparator: .greaterThanOrEqual, value: 20),
                ForecastAlertCondition(variable: .precipitation, comparator: .greaterThanOrEqual, value: 1)
            ],
            considerForecastUpToDay: 1
        )

        XCTAssertNil(ForecastAlertEvaluator.matchingHour(for: alert, in: forecast))
    }

    func testCustomAlertEvaluatorIgnoresInactiveAlerts() throws {
        let forecast = try makeForecast(temperature: 10, windSpeedByHour: ["0": 8, "3": 24])
        let alert = ForecastAlert(
            spotID: "test-spot",
            spotDisplayName: "Test spot",
            conditions: [ForecastAlertCondition(variable: .windSpeed, comparator: .greaterThanOrEqual, value: 20)],
            isActive: false
        )

        XCTAssertNil(ForecastAlertEvaluator.matchingHour(for: alert, in: forecast))
    }

    func testCustomAlertEvaluatorHonorsForecastHorizon() throws {
        let forecast = try makeForecast(temperature: 10, windSpeedByHour: ["0": 8, "3": 24])
        let alert = ForecastAlert(
            spotID: "test-spot",
            spotDisplayName: "Test spot",
            conditions: [ForecastAlertCondition(variable: .windSpeed, comparator: .greaterThanOrEqual, value: 20)],
            considerForecastUpToDay: 0
        )

        XCTAssertNil(ForecastAlertEvaluator.matchingHour(for: alert, in: forecast))
    }

    func testCustomAlertEvaluatorHonorsWeekdayFilter() throws {
        let forecast = try makeForecast(temperature: 10, windSpeedByHour: ["0": 8, "3": 24])
        let matchingWeekday = Calendar.current.component(.weekday, from: Date().addingTimeInterval(2 * 3_600))
        let excludedWeekdays = Set(1...7).subtracting(Set([matchingWeekday]))
        let alert = ForecastAlert(
            spotID: "test-spot",
            spotDisplayName: "Test spot",
            conditions: [ForecastAlertCondition(variable: .windSpeed, comparator: .greaterThanOrEqual, value: 20)],
            considerForecastUpToDay: 1,
            weekdays: excludedWeekdays
        )

        XCTAssertNil(ForecastAlertEvaluator.matchingHour(for: alert, in: forecast))
    }

    func testNotificationPreferenceDefaultsToEnabledAndPersistsChanges() {
        let store = ForecastSevereWeatherNotificationsStore(preferenceStore: PreferencesStore())

        XCTAssertTrue(store.load())
        store.save(false)
        XCTAssertFalse(store.load())
        store.save(true)
        XCTAssertTrue(store.load())
    }

    func testAlertComparatorBoundariesAreInclusive() {
        XCTAssertTrue(ForecastAlertComparator.greaterThanOrEqual.isSatisfied(20, 20))
        XCTAssertFalse(ForecastAlertComparator.greaterThanOrEqual.isSatisfied(19.9, 20))
        XCTAssertTrue(ForecastAlertComparator.lessThanOrEqual.isSatisfied(-10, -10))
        XCTAssertFalse(ForecastAlertComparator.lessThanOrEqual.isSatisfied(-9.9, -10))
    }

    private func makeNotifier(notificationsEnabled: Bool = true) -> ForecastSevereWeatherNotifier {
        ForecastSevereWeatherNotifier(
            notificationsStore: NotificationsStore(isEnabled: notificationsEnabled),
            alertStore: AlertsStore()
        )
    }

    private func makeForecast(
        temperature: Double,
        precipitation: Double = 0,
        freezingLevel: Double = 2_000,
        altitude: Int = 0,
        windSpeedByHour: [String: Double] = ["0": 10, "3": 10, "6": 10]
    ) throws -> SpotForecast {
        let initializationDate = Date().addingTimeInterval(-3_600)
        let hours = Dictionary(uniqueKeysWithValues: windSpeedByHour.keys.map { ($0, temperature) })
        let precipitationByHour = Dictionary(uniqueKeysWithValues: windSpeedByHour.keys.map { ($0, precipitation) })
        let freezingLevels = Dictionary(uniqueKeysWithValues: windSpeedByHour.keys.map { ($0, freezingLevel) })

        return try XCTUnwrap(SpotForecast(map: [
            "id_spot": "test-spot",
            "spotname": "Test spot",
            "country": "Testland",
            "alt": altitude,
            "models": ["3"],
            "forecast": [
                "3": [
                    "initstamp": Int(initializationDate.timeIntervalSince1970),
                    "model_name": "Test model",
                    "WINDSPD": windSpeedByHour,
                    "TMP": hours,
                    "TMPE": hours,
                    "APCP1": precipitationByHour,
                    "FLHGT": freezingLevels
                ]
            ]
        ]))
    }
}
