//
//  VisionForescoopApp.swift
//  Forescoop
//
//  Created by Javier Fuchs on 07/23/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(visionOS)
import SwiftUI
import Forescoop

@main
struct VisionForescoopApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let analytics = VentusFirebase()

    init() {
        analytics.configure()
    }

    var body: some Scene {
        WindowGroup {
            VisionForecastView(analytics: analytics)
        }
        .defaultSize(width: 1_280, height: 900)
        .backgroundTask(.appRefresh(ForecastAlertBackgroundRefresh.taskIdentifier)) {
            await ForecastAlertSweep.run()
            ForecastAlertBackgroundRefresh.schedule()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                ForecastAlertBackgroundRefresh.schedule()
            }
        }
    }
}
#endif
