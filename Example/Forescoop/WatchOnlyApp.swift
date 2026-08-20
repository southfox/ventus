//
//  WatchOnlyApp.swift
//  Forescoop
//
//  Created by Javier Fuchs on 07/23/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(watchOS)
import SwiftUI
import WatchKit
import Forescoop

@main
struct ForescoopWatchOnlyApp: App {
    @WKApplicationDelegateAdaptor(WatchExtensionDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchForecastView()
        }
    }
}

class WatchExtensionDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        VentusFirebase.configure()
        ForecastAlertWatchBackgroundRefresh.schedule()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        Task {
            await ForecastAlertWatchBackgroundRefresh.handle(backgroundTasks)
        }
    }
}

#if DEBUG
#Preview {
    WatchForecastView(forecastService: ForecastWindguruMockup())
}
#endif

#endif
