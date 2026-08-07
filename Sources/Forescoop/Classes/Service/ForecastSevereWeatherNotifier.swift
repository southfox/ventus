//
//  ForecastSevereWeatherNotifier.swift
//  Forescoop
//
//  Local notifications for exceptional conditions in the selected forecast.
//

import Foundation
#if canImport(UserNotifications) && !os(tvOS)
import UserNotifications
#endif

/// Evaluates the selected location's nearest forecast hour and informs the
/// user about weather conditions that merit immediate attention.
@MainActor
enum ForecastSevereWeatherNotifier {
#if canImport(UserNotifications) && !os(tvOS)
    private nonisolated static let deliveredAlertsKey = "forecastSevereWeatherNotifier.deliveredAlerts"
#endif

    static func evaluate(_ spotForecast: SpotForecast) -> ForecastSevereWeatherAlert? {
        guard ForecastSevereWeatherNotificationsStore.load(),
              let forecast = spotForecast.forecast,
              let hour = closestHour(in: spotForecast),
              let temperature = forecast.temperatureReal(hh: hour) ?? forecast.temperature(hh: hour) else {
            return nil
        }

        let precipitation = forecast.precipitation1(hh: hour) ?? forecast.precipitation(hh: hour) ?? 0
        let location = spotForecast.locationDisplayName()
        let alert: ForecastSevereWeatherAlert?

        // Windguru reports precipitation in millimetres. Below freezing, a
        // substantial amount is treated as a heavy-snow risk.
        if temperature <= 0, precipitation >= 8 {
            alert = ForecastSevereWeatherAlert(
                kind: "heavy-snow",
                title: "Heavy snow near \(location)",
                body: "Snowfall is forecast near \(String(format: "%.0f", temperature))°C. Consider delaying travel and checking local conditions.",
                hour: hour
            )
        } else if temperature <= -10 {
            alert = ForecastSevereWeatherAlert(
                kind: "extreme-cold",
                title: "Extreme cold near \(location)",
                body: "Temperatures near \(String(format: "%.0f", temperature))°C are forecast. Dress for severe cold and protect exposed equipment.",
                hour: hour
            )
        } else if temperature >= 35 {
            alert = ForecastSevereWeatherAlert(
                kind: "extreme-heat",
                title: "Extreme heat near \(location)",
                body: "Temperatures near \(String(format: "%.0f", temperature))°C are forecast. Hydrate and avoid prolonged heat exposure.",
                hour: hour
            )
        } else {
            return nil
        }

        guard let alert else { return nil }
#if canImport(UserNotifications) && !os(tvOS)
        let locationIdentifier = spotForecast.identifier ?? location
        scheduleNotification(
            identifier: "forecast-severe-weather.\(locationIdentifier).\(alert.kind).\(alert.hour)",
            categoryIdentifier: "forecast-severe-weather",
            title: alert.title,
            body: alert.body
        )
#endif
        return alert
    }

    /// Evaluates the user's custom ForecastAlert definitions for this spot and
    /// fires a push notification for each one whose conditions are met by an
    /// upcoming forecast hour. Unlike `evaluate(_:)`, this never surfaces an
    /// in-app banner — custom alerts are push-only.
    nonisolated static func evaluateCustomAlerts(_ spotForecast: SpotForecast) {
#if canImport(UserNotifications) && !os(tvOS)
        guard ForecastSevereWeatherNotificationsStore.load(), let spotID = spotForecast.identifier else { return }
        let alerts = ForecastAlertStore.load().filter { $0.isActive && $0.pushNotificationEnabled && $0.spotID == spotID }
        guard !alerts.isEmpty else { return }

        let location = spotForecast.locationDisplayName()
        for alert in alerts {
            guard let match = ForecastAlertEvaluator.matchingHour(for: alert, in: spotForecast) else { continue }
            scheduleNotification(
                identifier: "forecast-custom-alert.\(alert.id).\(match.hour)",
                categoryIdentifier: "forecast-custom-alert",
                title: alert.name.isEmpty ? "Forecast alert near \(location)" : alert.name,
                body: "\(alert.conditionsSummary) forecast near \(location)."
            )
        }
#endif
    }

    private static func closestHour(in spotForecast: SpotForecast) -> String? {
        spotForecast.availableForecastHours.last(where: {
            (spotForecast.forecastDate(hour: $0) ?? .distantFuture) <= Date()
        }) ?? spotForecast.availableForecastHours.first
    }

#if canImport(UserNotifications) && !os(tvOS)
    private nonisolated static func scheduleNotification(identifier: String, categoryIdentifier: String, title: String, body: String) {
        Task {
            var delivered = Set(UserDefaults.standard.stringArray(forKey: deliveredAlertsKey) ?? [])
            guard delivered.insert(identifier).inserted else { return }
            guard let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]), granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(Array(delivered.suffix(100)), forKey: deliveredAlertsKey)
        }
    }
#endif
}

struct ForecastSevereWeatherAlert: Equatable {
    let kind: String
    let title: String
    let body: String
    let hour: String
}

/// Persists whether the user has opted in to severe weather notifications.
/// Defaults to enabled so the alert banner and local notification behave the
/// same as before this preference existed.
public enum ForecastSevereWeatherNotificationsStore {
    private static let key = "forecastSevereWeatherNotificationsEnabled"

    public static func load() -> Bool {
        VentusPreferenceStore.value(forKey: key).map { $0 == "true" } ?? true
    }

    public static func save(_ isEnabled: Bool) {
        VentusPreferenceStore.save(isEnabled ? "true" : "false", forKey: key)
    }
}
