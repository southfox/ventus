//
//  WidgetPreviewScreen.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/19/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS) && canImport(WidgetKit)
import SwiftUI
import WidgetKit

struct WidgetPreviewScreen: View {
    let forecast: SpotForecast
    let coordinateLocationName: String?
    let theme: VentusTheme
    var onSelectLocation: () -> Void = {}
    var onShowMap: () -> Void = {}

    @Environment(\.appEnvironment) private var environment

    private var entry: ForecastWidgetEntry {
        ForecastWidgetEntryBuilder.entry(
            from: forecast,
            coordinateLocationName: coordinateLocationName,
            useDetailedInsight: true,
            hourlyLimit: forecast.availableForecastHours.count,
            environment: environment
        )
    }

    var body: some View {
        ScrollView {
            ForecastWidgetView(
                entry: entry,
                theme: theme,
                previewFamily: .systemExtraLarge,
                onSelectLocation: onSelectLocation,
                onShowMap: onShowMap
            )
            .frame(minHeight: 420)
            .padding()
        }
        .navigationTitle(entry.locationName)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .forecastAccessibilityContainer(
            "Widget preview",
            hint: "Shows how the largest Ventus widget looks with the current forecast.",
            identifier: "forecast.widgetPreview"
        )
    }
}

#if DEBUG
#Preview("Widget preview screen") {
    WidgetPreviewScreenPreview()
}

private struct WidgetPreviewScreenPreview: View {
    @ViewBuilder var body: some View {
        NavigationStack {
            if let forecast = ForecastWindguruMockup().dashboardPreviewForecast {
                WidgetPreviewScreen(forecast: forecast, coordinateLocationName: nil, theme: .ocean)
            } else {
                ContentUnavailableView("Preview forecast unavailable", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
#endif
#endif
