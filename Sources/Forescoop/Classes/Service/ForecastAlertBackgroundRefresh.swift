//
//  ForecastAlertBackgroundRefresh.swift
//  Forescoop
//

#if os(iOS) || os(tvOS) || os(visionOS)
@preconcurrency import BackgroundTasks
import Foundation

public enum ForecastAlertBackgroundRefresh {
    public static let taskIdentifier = "org.forescoop.alerts.refresh"
    private static let refreshInterval: TimeInterval = 30 * 60

    public static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(appRefreshTask)
        }
    }

    public static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()

        let sweep = Task {
            await ForecastAlertSweep.run()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { sweep.cancel() }
    }
}
#endif
