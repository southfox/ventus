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
    private let environment: AppEnvironment

    public init(forecastService: ForecastWindguruProtocol = ForecastWindguruService(), environment: AppEnvironment) {
        self.forecastService = forecastService
        self.environment = environment
    }

    public var body: some View {
        ForecastDashboardView(forecastService: forecastService, environment: environment)
            .forecastAccessibilityContainer(
                "Ventus forecast workspace",
                hint: "Use forecast controls to choose a location, hour, layout, or settings.",
                identifier: "vision.forecast.workspace"
            )
    }
}

#Preview(windowStyle: .automatic) {
    VisionForecastView(forecastService: ForecastWindguruMockup(), environment: .preview)
}
#endif
