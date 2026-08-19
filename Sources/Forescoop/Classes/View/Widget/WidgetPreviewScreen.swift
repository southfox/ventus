//
//  WidgetPreviewScreen.swift
//  Forescoop package
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
    @Environment(\.dismiss) private var dismiss

    private var entry: ForecastWidgetEntry {
        ForecastWidgetEntryBuilder.entry(from: forecast, coordinateLocationName: coordinateLocationName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ForecastWidgetView(entry: entry, theme: theme, previewFamily: .systemExtraLarge)
                    .frame(minHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding()
            }
            .navigationTitle("Widget".localized)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
#if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
#endif
        }
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
        if let forecast = ForecastWindguruMockup().dashboardPreviewForecast {
            WidgetPreviewScreen(forecast: forecast, coordinateLocationName: nil, theme: .ocean)
        } else {
            ContentUnavailableView("Preview forecast unavailable", systemImage: "exclamationmark.triangle")
        }
    }
}
#endif
#endif
