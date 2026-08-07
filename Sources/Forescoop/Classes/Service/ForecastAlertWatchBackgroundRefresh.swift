//
//  ForecastAlertWatchBackgroundRefresh.swift
//  Forescoop
//
//  BGTaskScheduler is API_UNAVAILABLE on watchOS. WatchKit's own background
//  refresh mechanism (WKApplicationRefreshBackgroundTask) is the equivalent
//  here. The host app still needs a small WKApplicationDelegate that calls
//  schedule() on launch and handle(_:) from its `handle(_ backgroundTasks:)`
//  callback — see ForescoopWatchOnlyApp's extension delegate.
//

#if os(watchOS)
import Foundation
import WatchKit

public enum ForecastAlertWatchBackgroundRefresh {
    private static let refreshInterval: TimeInterval = 30 * 60

    /// Requests the next background run. Safe to call repeatedly.
    public static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: refreshInterval),
            userInfo: nil,
            scheduledCompletion: { _ in }
        )
    }

    /// Runs the sweep for every `WKApplicationRefreshBackgroundTask` in the
    /// set, completing each task and lining up the next run.
    public static func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) async {
        var didRunSweep = false
        for task in backgroundTasks {
            guard let refreshTask = task as? WKApplicationRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            if !didRunSweep {
                await ForecastAlertSweep.run()
                didRunSweep = true
            }
            schedule()
            refreshTask.setTaskCompletedWithSnapshot(false)
        }
    }
}
#endif
