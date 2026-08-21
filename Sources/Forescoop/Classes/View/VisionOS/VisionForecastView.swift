//
//  VisionForecastView.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/02/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if os(visionOS)
import SwiftUI

/// The visionOS entry point for Ventus.
///
/// It deliberately hosts the shared dashboard instead of maintaining a
/// separate summary-only experience. This keeps the forecast grid, dashboard,
/// combined workspace, model comparison, location picker, account, and unit
/// controls consistent across Apple platforms.
@MainActor
public struct VisionForecastView: View {
    private let forecastService: ForecastWindguruProtocol
    private let analytics: AnalyticsLogging

    public init(forecastService: ForecastWindguruProtocol = ForecastWindguruService(), analytics: AnalyticsLogging) {
        self.forecastService = forecastService
        self.analytics = analytics
    }

    public var body: some View {
        ForecastDashboardView(forecastService: forecastService, analytics: analytics)
            .forecastAccessibilityContainer(
                "Ventus forecast workspace",
                hint: "Use forecast controls to choose a location, hour, layout, or settings.",
                identifier: "vision.forecast.workspace"
            )
    }
}

#Preview(windowStyle: .automatic) {
    VisionForecastView(forecastService: ForecastWindguruMockup(), analytics: NoOpAnalyticsLogger())
}
#endif
