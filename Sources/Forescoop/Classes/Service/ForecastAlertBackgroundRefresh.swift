//
//  ForecastAlertBackgroundRefresh.swift
//  Forescoop
//
//  Periodically fetches forecasts for every spot with an active push alert
//  so ForecastAlert conditions can fire even while the app isn't open.
//

#if os(iOS)
@preconcurrency import BackgroundTasks
import Foundation

public enum ForecastAlertBackgroundRefresh {
    public static let taskIdentifier = "org.forescoop.alerts.refresh"
    private static let refreshInterval: TimeInterval = 30 * 60

    /// Must be called before `application(_:didFinishLaunchingWithOptions:)` returns.
    public static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(appRefreshTask)
        }
    }

    /// Requests the next background run. Safe to call repeatedly; the system
    /// coalesces requests for the same identifier.
    public static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        // Always line up the next run first: the system expects a fresh
        // request even if this one fails or is cut short.
        schedule()

        let sweep = Task {
            await runAlertSweep()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { sweep.cancel() }
    }

    /// Fetches a forecast for each spot referenced by an active, push-enabled
    /// alert and hands it to `ForecastSevereWeatherNotifier` for evaluation.
    static func runAlertSweep() async {
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
#endif
