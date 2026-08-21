//
//  ReadForecastInsightIntent.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/20/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct ReadForecastInsightIntent: AppIntent {
    public static let title: LocalizedStringResource = "Forecast Insight"
    public static let description = IntentDescription(
        "Reads Ventus's forecast insight for your selected location."
    )
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let environment = AppEnvironment()
        environment.analytics.configure()
        environment.analytics.log(.siriInsightRequested)
        let spotID = environment.selectedSpotStore.load()
        let username = environment.windguruCredentialStore.activeUsername()
        let isProUser = environment.windguruCredentialStore.activeProUser()
        let password = username.flatMap(environment.windguruCredentialStore.password(for:))
        let service = ForecastWindguruService()

        guard let forecast = try? await service.bestForecast(
            bySpotId: spotID,
            model: nil,
            username: isProUser ? username : nil,
            password: isProUser ? password : nil
        ), !forecast.availableForecastHours.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: "I couldn't load the forecast right now.".localized))
        }

        let units = environment.ventusForecastUnitStore.load(fallback: DeviceForecastPreferenceProvider().forecastUnitPreferences)
        let insight = ForecastIntelligenceText.summary(
            forecast: forecast,
            hour: forecast.currentForecastHour,
            temperatureUnit: units.temperatureUnit,
            windSpeedUnit: units.windSpeedUnit,
            precipitationUnit: units.precipitationUnit,
            freezingLevelUnit: units.freezingLevelUnit,
            pressureUnit: units.pressureUnit,
            waveHeightUnit: units.waveHeightUnit
        )
        return .result(dialog: IntentDialog(stringLiteral: insight))
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct VentusShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadForecastInsightIntent(),
            phrases: [
                "What's the forecast insight in \(.applicationName)",
                "Read the forecast in \(.applicationName)",
                "\(.applicationName) forecast insight"
            ],
            shortTitle: "Forecast Insight",
            systemImageName: "sparkles"
        )
    }
}
#endif
