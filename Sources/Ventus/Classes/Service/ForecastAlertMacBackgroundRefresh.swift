//
//  ForecastAlertMacBackgroundRefresh.swift
//  Ventus
//

#if os(macOS)
import Foundation

@MainActor
public enum ForecastAlertMacBackgroundRefresh {
    private static let activityIdentifier = "org.forescoop.alerts.refresh"
    private static let refreshInterval: TimeInterval = 30 * 60
    private static var scheduler: NSBackgroundActivityScheduler?

    public static func start() {
        let scheduler = NSBackgroundActivityScheduler(identifier: activityIdentifier)
        scheduler.repeats = true
        scheduler.interval = refreshInterval
        scheduler.tolerance = refreshInterval / 4
        scheduler.qualityOfService = .utility
        scheduler.schedule { completion in
            Task {
                await ForecastAlertSweep.run()
                completion(.finished)
            }
        }
        self.scheduler = scheduler
    }
}
#endif
