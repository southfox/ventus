//
//  VisionVentusApp.swift
//  Ventus
//
//  Created by Javier Fuchs on 07/23/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(visionOS)
import SwiftUI
import Ventus

@main
struct VisionVentusApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let environment = AppEnvironment()

    init() {
        environment.analytics.configure()
    }

    var body: some Scene {
        WindowGroup {
            VisionForecastView(environment: environment)
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
