//
//  VentusHelpView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/02/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public struct VentusHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private let windguruHelpURL = URL(string: "https://www.windguru.cz/help.php?sec=intro")!
    private let windguruModelsURL = URL(string: "https://www.windguru.cz/help.php?sec=models")!

    public init() {}

    public var body: some View {
#if os(tvOS)
        tvHelpBody
#else
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Welcome to Ventus".localized, systemImage: "wind")
                        .font(.title.bold())
                        .foregroundStyle(.tint)
                    Text("A practical guide to Windguru-powered forecasts across your Apple devices.".localized)
                        .foregroundStyle(.secondary)
                }

                HelpSection {
                    VStack(alignment: .leading, spacing: 14) {
                        HelpStep(
                            number: 1,
                            title: "Choose a location".localized,
                            detail: "Use the location button to search Windguru spots, choose a saved place, select the map, or use your current location.".localized
                        )
                        HelpStep(
                            number: 2,
                            title: "Pick the forecast view".localized,
                            detail: "Switch between Forecast Dashboard, Forecast Grid, Grid and Dashboard, or Overview from the menu or Settings.".localized
                        )
                        HelpStep(
                            number: 3,
                            title: "Read and compare".localized,
                            detail: "Tap a grid hour to inspect it in the dashboard. Select units from their blue-tinted labels, then compare selected forecast models when available.".localized
                        )
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Quick guide".localized, systemImage: "list.number")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Ventus across Apple devices".localized, systemImage: "apple.logo")
                        .font(.headline)

                    Text("These interface previews show how the same forecast workflow adapts to each Ventus app.".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            HelpPlatformPreview(name: "iPhone".localized, systemImage: "iphone", layout: .phone)
                            HelpPlatformPreview(name: "iPad".localized, systemImage: "ipad", layout: .split)
                            HelpPlatformPreview(name: "Mac".localized, systemImage: "laptopcomputer", layout: .split)
                            HelpPlatformPreview(name: "Vision".localized, systemImage: "visionpro", layout: .spatial)
                            HelpPlatformPreview(name: "Watch".localized, systemImage: "applewatch", layout: .watch)
                            HelpPlatformPreview(name: "Apple TV".localized, systemImage: "appletv", layout: .television)
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }

                HelpSection {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpFeature(symbol: "cpu", title: "Models depend on the location".localized, detail: "Each spot exposes the forecast models that cover it. The available selection can change when you choose another location or sign in to a different account tier.".localized)
                        HelpFeature(symbol: "circle.hexagongrid", title: "Ventus Mix", detail: "When multiple sources are selected, Ventus presents a Ventus Mix: one continuous forecast assembled from the selected model data available for each hour.".localized)
                        HelpFeature(symbol: "arrow.left.and.right", title: "Compare before relying on a forecast".localized, detail: "In Forecast Grid, use Compare models to reveal source values row by row, or Compare all to expand every forecast field at once.".localized)
                        HelpFeature(symbol: "checklist", title: "Choose the sources".localized, detail: "Tap the Ventus Mix model summary below the grid to expand the checkbox list. Keep at least one model selected, then use the mix and comparison tools to judge agreement.".localized)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Understanding forecast models".localized, systemImage: "cpu")
                }

                HelpSection {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpFeature(symbol: "tablecells", title: "Forecast Grid".localized, detail: "Scroll through hours, tap a column to select it, and use the comparison control to inspect individual or all model sources.".localized)
                        HelpFeature(symbol: "rectangle.split.2x1", title: "Grid and Dashboard".localized, detail: "Drag the separator to choose your preferred balance. The selected hour, units, location, and models stay synchronized.".localized)
                        HelpFeature(symbol: "square.grid.2x2", title: "Overview".localized, detail: "Shows the same large layout as the Home Screen widget, with a written analysis of current conditions and the days ahead — flagging strong wind and chill, refreeze or ice risk, extended rain or snow, temperature extremes, and swell when relevant.".localized)
                        HelpFeature(symbol: "cpu", title: "Forecast models".localized, detail: "Ventus combines selected models into a Ventus Mix. Expand the model summary in the grid to change the selected sources.".localized)
                        HelpFeature(symbol: "map", title: "Maps and saved locations".localized, detail: "View forecast locations on the map, keep places locally, and use Windguru favorites when signed in.".localized)
                        HelpFeature(symbol: "circle.righthalf.filled", title: "Appearance and theme".localized, detail: "Choose System, Light, or Dark in Settings, plus a color theme that changes the palette and font design independently of light or dark mode.".localized)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Forecast essentials".localized, systemImage: "book")
                }

                HelpSection {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpFeature(symbol: "thermometer.variable.and.figure", title: "Real vs. raw temperature".localized, detail: "The headline temperature is the real, altitude-corrected reading (TMPE) whenever the model provides it, falling back to the raw model temperature (TMP) otherwise. Where both are shown side by side, the second value is always the unadjusted raw reading.".localized)
                        HelpFeature(symbol: "thermometer.sun.fill", title: "Thermometer icon shape and color".localized, detail: "Each thermometer icon reflects its own value: below 0°C shows a snowflake thermometer, 0–18°C a plain thermometer, 18–28°C a sun thermometer, and 28°C and above a filled sun thermometer. Its color grades from icy blue through cyan, green, and yellow to orange and red as the reading rises.".localized)
                        HelpFeature(symbol: "wind", title: "Wind icon follows the Beaufort scale".localized, detail: "The icon shows the sky condition — sun, cloud, or moon — as long as wind stays calm to moderate. Once the stronger of sustained wind or gusts reaches strong-breeze force (Beaufort 6) or higher, a dedicated wind icon takes over instead: wind through wind.circle.fill for strong breezes, tornado symbols for gales, tropical-storm symbols for storm force, and hurricane symbols at the top of the scale.".localized)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Reading the icons".localized, systemImage: "eye")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Link(destination: windguruHelpURL) {
                        Label("Open Windguru introductory help".localized, systemImage: "safari")
                    }
                    Link(destination: windguruModelsURL) {
                        Label("Open Windguru forecast model help".localized, systemImage: "safari")
                    }
                }
                .font(.footnote)
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding()
        }
        .navigationTitle("Help".localized)
#if os(macOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close".localized) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
#endif
        .trackScreenView("Help")
#endif
    }

#if os(tvOS)
    private var tvHelpBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Welcome to Ventus".localized, systemImage: "wind")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.tint)
                        Text("A practical guide to Windguru-powered forecasts across your Apple devices.".localized)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .frame(width: 52, height: 52)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close help")
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 24) {
                    tvHelpCard("Quick guide", detail: "Choose a location, select a forecast view, and inspect each hour.", symbol: "list.number") {
                        tvHelpPage("Quick guide", items: [
                            ("Choose a location", "Use the location button to search Windguru spots, choose a saved place, or use your current location.", "mappin.and.ellipse"),
                            ("Pick the forecast view", "Switch between Dashboard, Forecast Grid, Graph, and Overview from the menu or Settings.", "rectangle.3.group"),
                            ("Read and compare", "Select a grid hour for the dashboard, adjust units from row labels, and compare forecast models.", "arrow.left.and.right")
                        ])
                    }
                    tvHelpCard("Forecast essentials", detail: "Learn the grid, dashboard, overview, models, and saved locations.", symbol: "book") {
                        tvHelpPage("Forecast essentials", items: [
                            ("Forecast Grid", "Browse the forecast by hour. Header controls select hours and row labels change available units.", "tablecells"),
                            ("Overview", "Review current conditions and the days ahead in the largest forecast presentation.", "square.grid.2x2"),
                            ("Forecast models", "Ventus Mix combines selected model sources. Compare them when conditions matter.", "cpu"),
                            ("Maps and locations", "Keep locations locally and access Windguru favorites when signed in.", "map")
                        ])
                    }
                    tvHelpCard("Understanding models", detail: "See how Ventus Mix and source comparison work for a location.", symbol: "cpu") {
                        tvHelpPage("Understanding models", items: [
                            ("Models depend on the location", "Each spot exposes only the forecast models that cover it.", "cpu"),
                            ("Ventus Mix", "Ventus builds one continuous forecast from the selected sources available at each hour.", "circle.hexagongrid"),
                            ("Compare before relying", "Use Compare models in the grid to reveal source values row by row.", "arrow.left.and.right")
                        ])
                    }
                    tvHelpCard("Reading the icons", detail: "Understand real temperature, weather conditions, and wind symbols.", symbol: "eye") {
                        tvHelpPage("Reading the icons", items: [
                            ("Real vs. raw temperature", "Ventus prefers the altitude-corrected temperature when supplied by the forecast model.", "thermometer.variable.and.figure"),
                            ("Thermometer color", "Temperature icons move from icy blue through warm colors as readings rise.", "thermometer.sun.fill"),
                            ("Wind strength", "At stronger Beaufort levels, weather icons make way for dedicated wind and storm symbols.", "wind")
                        ])
                    }
                }
            }
            .padding(.horizontal, 84)
            .padding(.vertical, 54)
            .frame(maxWidth: 1_500, alignment: .leading)
        }
        .toolbar(.hidden, for: .navigationBar)
        .trackScreenView("Help")
    }

    private func tvHelpCard<Destination: View>(
        _ title: String,
        detail: String,
        symbol: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text(title).font(.title2.weight(.semibold))
                Text(detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Label("Open", systemImage: "chevron.right")
                    .font(.body.weight(.medium))
            }
            .padding(30)
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func tvHelpPage(_ title: String, items: [(String, String, String)]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(title).font(.largeTitle.bold())
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 22) {
                        Image(systemName: item.2)
                            .font(.title)
                            .foregroundStyle(.tint)
                            .frame(width: 42)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.0).font(.title2.weight(.semibold))
                            Text(item.1).font(.title3).foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(64)
            .frame(maxWidth: 1_250, alignment: .leading)
        }
        .navigationTitle(title)
    }
#endif
}

private struct HelpStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number.formatted())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.tint, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// A cross-platform replacement for GroupBox, which is unavailable on tvOS.
private struct HelpSection<Content: View, Label: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.content = content
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            label()
                .font(.headline)
            content()
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }
}

private struct HelpFeature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
        }
    }
}

private struct HelpPlatformPreview: View {
    enum Layout { case phone, split, spatial, watch, television }

    let name: String
    let systemImage: String
    let layout: Layout
    @Environment(\.ventusTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(theme.accentColor.opacity(0.35))
                    }

                previewContent
                    .padding(12)
            }
            .frame(width: 156, height: 190)

            Label(name, systemImage: systemImage)
                .font(.caption.bold())
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch layout {
        case .phone:
            VStack(spacing: 7) {
                previewTitle
                miniGrid
                miniDashboard
            }
        case .split:
            VStack(spacing: 7) {
                previewTitle
                HStack(spacing: 5) {
                    miniGrid
                    miniDashboard
                }
            }
        case .spatial:
            VStack(spacing: 10) {
                previewTitle
                HStack(spacing: 7) {
                    miniPanel
                    miniPanel
                }
                miniDashboard
            }
        case .watch:
            VStack(spacing: 9) {
                Image(systemName: "wind")
                    .font(.title)
                    .foregroundStyle(.tint)
                Text("Ventus")
                    .font(.caption.bold())
                Text("12 kn")
                    .font(.title3.monospacedDigit())
                Text("Cloudy".localized)
                    .font(.caption2)
            }
        case .television:
            VStack(spacing: 8) {
                previewTitle
                HStack(spacing: 6) {
                    miniGrid
                    miniDashboard
                }
                Label("Remote-friendly forecast".localized, systemImage: "rectangle.on.rectangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var previewTitle: some View {
        HStack {
            Image(systemName: "wind")
            Text("Ventus").font(.caption.bold())
            Spacer()
        }
        .foregroundStyle(.tint)
    }

    private var miniGrid: some View {
        VStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 2) {
                    Capsule().fill(theme.accentColor.opacity(0.55)).frame(width: 24, height: 5)
                    ForEach(0..<3, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 1)
                            .fill((row + column).isMultiple(of: 2) ? theme.accentColor.opacity(0.24) : Color.secondary.opacity(0.15))
                            .frame(width: 17, height: 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var miniDashboard: some View {
        VStack(spacing: 5) {
            Image(systemName: "cloud.sun.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            Text("14°")
                .font(.title3.bold())
            Capsule().fill(Color.secondary.opacity(0.2)).frame(width: 58, height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniPanel: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(theme.accentColor.opacity(0.12))
            .overlay {
                Image(systemName: "wind")
                    .foregroundStyle(.tint)
            }
            .frame(height: 56)
    }
}

#Preview("Ventus help") {
    NavigationStack {
        VentusHelpView()
    }
}
