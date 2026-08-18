//
//  ForecastAlertSweep.swift
//  Forescoop
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
            return try await service.bestForecast(
                bySpotId: spotID,
                model: modelID,
                username: isProUser ? username : nil,
                password: isProUser ? password : nil
            )
        } catch {
            return nil
        }
    }
}
