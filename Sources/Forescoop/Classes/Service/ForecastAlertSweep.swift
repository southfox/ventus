//
//  ForecastAlertSweep.swift
//  Forescoop
//

import Foundation

public enum ForecastAlertSweep {
    @MainActor
    public static func run() async {
        let environment = AppEnvironment()
        guard environment.forecastSevereWeatherNotificationsStore.load() else { return }
        let alerts = environment.forecastAlertStore.load().filter { $0.isActive && $0.pushNotificationEnabled }
        guard !alerts.isEmpty else { return }

        let username = environment.windguruCredentialStore.activeUsername()
        let isProUser = environment.windguruCredentialStore.activeProUser()
        let password = username.flatMap(environment.windguruCredentialStore.password(for:))
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
                environment.severeWeatherNotifier.evaluateCustomAlerts(forecast)
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
