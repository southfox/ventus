//
//  ForecastAlertMacBackgroundRefresh.swift
//  Forescoop
//
//  BGTaskScheduler is API_UNAVAILABLE on macOS, so alert sweeps there run on
//  a recurring NSBackgroundActivityScheduler activity instead. This only
//  fires while the app process is alive (foreground or backgrounded) — macOS
//  has no equivalent to iOS's "wake the app from fully quit" background
//  refresh without a separate login-item helper.
//

#if os(macOS)
import Foundation

@MainActor
public enum ForecastAlertMacBackgroundRefresh {
    private static let activityIdentifier = "org.forescoop.alerts.refresh"
    private static let refreshInterval: TimeInterval = 30 * 60
    private static var scheduler: NSBackgroundActivityScheduler?

    /// Starts the recurring sweep. Call once from `applicationDidFinishLaunching`.
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
