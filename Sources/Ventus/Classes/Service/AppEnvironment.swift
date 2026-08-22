//
//  AppEnvironment.swift
//  VentusPackage
//
//  Created by Javier Fuchs on 08/20/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation
import SwiftData
import SwiftUI

public final class AppEnvironment: Sendable {
    public let analytics: AnalyticsLogging
    public let savedMapLocationStore: SavedMapLocationStoring
    public let selectedSpotStore: SelectedWindguruSpotStoring
    public let gridHourStepStore: GridHourStepStoring
    public let weatherBackgroundStyleStore: WeatherBackgroundStyleStoring
    public let forecastViewModeStore: ForecastViewModeStoring
    public let forecastAlertStore: ForecastAlertStoring
    public let forecastSevereWeatherNotificationsStore: ForecastSevereWeatherNotificationsStoring
    public let appLanguageStore: AppLanguageStoring
#if os(watchOS)
    let watchLocationStore: WatchLocationStoring
#endif
    public let appAppearanceModeStore: AppAppearanceModeStoring
    public let ventusThemeStore: VentusThemeStoring
    public let ventusForecastUnitStore: VentusForecastUnitStoring
    public let sharedForecastSnapshotStore: SharedForecastSnapshotStoring
    public let windguruCredentialStore: WindguruCredentialStoring
    let forecastWorkspaceSplitStore: ForecastWorkspaceSplitStoring
    let severeWeatherNotifier: ForecastSevereWeatherNotifier

    public init() {
        let persistence = VentusPersistenceController()
        let preferenceStore = VentusPreferenceStore(container: persistence.mapLocationsContainer)
        let selectedSpotStore = SelectedWindguruSpotStore(container: persistence.mapLocationsContainer)
        let forecastAlertStore = ForecastAlertStore(container: persistence.alertsContainer)
        let forecastSevereWeatherNotificationsStore = ForecastSevereWeatherNotificationsStore(preferenceStore: preferenceStore)

        self.analytics = VentusFirebase(preferenceStore: preferenceStore)
        self.selectedSpotStore = selectedSpotStore
        self.savedMapLocationStore = SavedMapLocationStore(container: persistence.mapLocationsContainer, selectedSpotStore: selectedSpotStore)
        self.gridHourStepStore = GridHourStepStore(container: persistence.mapLocationsContainer)
        self.weatherBackgroundStyleStore = WeatherBackgroundStyleStore(container: persistence.mapLocationsContainer)
        self.forecastViewModeStore = ForecastViewModeStore(container: persistence.mapLocationsContainer)
        self.forecastAlertStore = forecastAlertStore
        self.forecastSevereWeatherNotificationsStore = forecastSevereWeatherNotificationsStore
        self.forecastWorkspaceSplitStore = ForecastWorkspaceSplitStore(preferenceStore: preferenceStore)
        self.severeWeatherNotifier = ForecastSevereWeatherNotifier(
            notificationsStore: forecastSevereWeatherNotificationsStore,
            alertStore: forecastAlertStore
        )
        self.appLanguageStore = AppLanguageStore(defaults: .standard)
#if os(watchOS)
        self.watchLocationStore = WatchLocationStore(defaults: .standard)
#endif
        self.appAppearanceModeStore = AppAppearanceModeStore(defaults: .standard)
        let groupDefaults = UserDefaults(suiteName: "group.org.forescoop.shared") ?? .standard
        self.ventusThemeStore = VentusThemeStore(defaults: groupDefaults)
        self.ventusForecastUnitStore = VentusForecastUnitStore(defaults: groupDefaults)
        self.sharedForecastSnapshotStore = SharedForecastSnapshotStore()
        self.windguruCredentialStore = WindguruCredentialStore()
    }

    /// An inert environment for previews and tests: in-memory SwiftData
    /// containers, an ephemeral (not `.standard`) UserDefaults suite, a
    /// no-op analytics logger, and no-op Keychain/file stores so nothing
    /// touches a real device resource just because a preview rendered.
    init(preview: Void) {
        let persistence = VentusPersistenceController(inMemory: true)
        let preferenceStore = VentusPreferenceStore(container: persistence.mapLocationsContainer)
        let selectedSpotStore = SelectedWindguruSpotStore(container: persistence.mapLocationsContainer)
        let forecastAlertStore = ForecastAlertStore(container: persistence.alertsContainer)
        let forecastSevereWeatherNotificationsStore = ForecastSevereWeatherNotificationsStore(preferenceStore: preferenceStore)
        let ephemeralDefaults = UserDefaults(suiteName: "org.forescoop.preview.\(UUID().uuidString)") ?? .standard

        self.analytics = NoOpAnalyticsLogger()
        self.selectedSpotStore = selectedSpotStore
        self.savedMapLocationStore = SavedMapLocationStore(container: persistence.mapLocationsContainer, selectedSpotStore: selectedSpotStore)
        self.gridHourStepStore = GridHourStepStore(container: persistence.mapLocationsContainer)
        self.weatherBackgroundStyleStore = WeatherBackgroundStyleStore(container: persistence.mapLocationsContainer)
        self.forecastViewModeStore = ForecastViewModeStore(container: persistence.mapLocationsContainer)
        self.forecastAlertStore = forecastAlertStore
        self.forecastSevereWeatherNotificationsStore = forecastSevereWeatherNotificationsStore
        self.forecastWorkspaceSplitStore = ForecastWorkspaceSplitStore(preferenceStore: preferenceStore)
        self.severeWeatherNotifier = ForecastSevereWeatherNotifier(
            notificationsStore: forecastSevereWeatherNotificationsStore,
            alertStore: forecastAlertStore
        )
        self.appLanguageStore = AppLanguageStore(defaults: ephemeralDefaults)
#if os(watchOS)
        self.watchLocationStore = WatchLocationStore(defaults: ephemeralDefaults)
#endif
        self.appAppearanceModeStore = AppAppearanceModeStore(defaults: ephemeralDefaults)
        self.ventusThemeStore = VentusThemeStore(defaults: ephemeralDefaults)
        self.ventusForecastUnitStore = VentusForecastUnitStore(defaults: ephemeralDefaults)
        self.sharedForecastSnapshotStore = NoOpSharedForecastSnapshotStore()
        self.windguruCredentialStore = NoOpWindguruCredentialStore()
    }

    public static var preview: AppEnvironment { AppEnvironment(preview: ()) }
}

private final class NoOpSharedForecastSnapshotStore: SharedForecastSnapshotStoring {
    func save(_ snapshot: SharedForecastSnapshot) {}
    func load() -> SharedForecastSnapshot? { nil }
}

private final class NoOpWindguruCredentialStore: WindguruCredentialStoring {
    func activeUsername() -> String? { nil }
    func saveActiveUsername(_ username: String) throws {}
    func removeActiveUsername() {}
    func activeProUser() -> Bool { false }
    func saveActiveProUser(_ isProUser: Bool) throws {}
    func removeActiveProUser() {}
    func password(for username: String) -> String? { nil }
    func save(password: String, for username: String) throws {}
    func removePassword(for username: String) {}
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.preview
}

public extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
