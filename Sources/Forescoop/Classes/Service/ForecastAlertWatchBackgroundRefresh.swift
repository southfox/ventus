//
//  ForecastAlertWatchBackgroundRefresh.swift
//  Forescoop

#if os(watchOS)
import Foundation
import WatchKit

public enum ForecastAlertWatchBackgroundRefresh {
    private static let refreshInterval: TimeInterval = 30 * 60

    public static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: refreshInterval),
            userInfo: nil,
            scheduledCompletion: { _ in }
        )
    }

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
