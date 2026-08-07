//
//  ForecastAlertSweep.swift
//  Forescoop
//
//  Platform-agnostic core used by every background-refresh mechanism
//  (BGTaskScheduler on iOS/tvOS/visionOS, NSBackgroundActivityScheduler on
//  macOS, WKApplicationRefreshBackgroundTask on watchOS): fetches a forecast
//  for each spot referenced by an active, push-enabled alert and hands it to
//  ForecastSevereWeatherNotifier for evaluation.
//

import Foundation

public enum ForecastAlertSweep {
    public static func run() async {
        guard ForecastSevereWeatherNotificationsStore.load() else { return }
        let alerts = ForecastAlertStore.load().filter { $0.isActive && $0.pushNotificationEnabled }
        guard !alerts.isEmpty else { return }

        let username = WindguruCredentialStore.activeUsername()
        let isProUser = WindguruCredentialStore.activeProUser()
        let password = username.flatMap(WindguruCredentialStore.password(for:))
        let service = ForecastWindguruService()

        let alertsBySpot = Dictionary(grouping: alerts, by: \.spotID)
        for (spotID, spotAlerts) in alertsBySpot {
            let modelIDs = Set(spotAlerts.flatMap(\.modelIDs))
            let requestedModelIDs: [String?] = modelIDs.isEmpty ? [nil] : modelIDs.map { $0 }
            for modelID in requestedModelIDs {
                guard let forecast = await fetchForecast(
                    service: service,
                    spotID: spotID,
                    modelID: modelID,
                    isProUser: isProUser,
                    username: username,
                    password: password
                ) else { continue }
                ForecastSevereWeatherNotifier.evaluateCustomAlerts(forecast)
            }
        }
    }

    private static func fetchForecast(
        service: ForecastWindguruProtocol,
        spotID: String,
        modelID: String?,
        isProUser: Bool,
        username: String?,
        password: String?
    ) async -> SpotForecast? {
        do {
            if isProUser, let username, !username.isEmpty, let password {
                guard let proForecast = try await service.wforecast(bySpotId: spotID, model: modelID, username: username, password: password) else { return nil }
                return try SpotForecast.from(coordinateForecast: proForecast)
            }
            return try await service.forecast(bySpotId: spotID, model: modelID)
        } catch {
            return nil
        }
    }
}
