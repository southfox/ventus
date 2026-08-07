//
//  ForecastAlertBackgroundRefresh.swift
//  Forescoop
//
//  Schedules ForecastAlertSweep via BGTaskScheduler so alerts can fire even
//  when the app isn't open. Available on iOS, tvOS, and visionOS; macOS and
//  watchOS use their own scheduling mechanisms (see
//  ForecastAlertMacBackgroundRefresh, ForecastAlertWatchBackgroundRefresh).
//

#if os(iOS) || os(tvOS) || os(visionOS)
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
            await ForecastAlertSweep.run()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { sweep.cancel() }
    }
}
#endif
