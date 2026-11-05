//
//  ForecastCachedSnapshotView.swift
//  Ventus package
//
//  Created by Codex on 09/09/26.
//

#if !os(watchOS)
import SwiftUI

/// A lightweight, immediately available dashboard while the full forecast is
/// refreshed. The widget snapshot is intentionally used as-is: it is a record
/// of the last successful forecast and never implies that it is live data.
struct ForecastCachedSnapshotView: View {
    let snapshot: SharedForecastSnapshot
    let viewMode: ForecastViewMode

    @Environment(\.ventusTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let conditions: [(String, String)]

    init(snapshot: SharedForecastSnapshot, viewMode: ForecastViewMode = .dashboard) {
        self.snapshot = snapshot
        self.viewMode = viewMode
        conditions = [
            ("Wind", snapshot.wind),
            ("Gusts", snapshot.gust),
            ("Direction", snapshot.windDirection),
            ("Rain", snapshot.rain),
            ("Humidity", snapshot.humidity),
            ("Clouds", snapshot.cloudCover),
            ("Pressure", snapshot.pressure)
        ]
    }

    var body: some View {
        Group {
            switch viewMode {
            case .grid:
                cachedGrid
            case .workspace:
                cachedWorkspace
            case .graph:
                cachedGraph
            case .dashboard, .overview:
                cachedDashboard
            }
        }
        .accessibilityIdentifier("forecast.cachedSnapshot")
    }

    private var cachedDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                hourlyForecast
                dailyForecast
                conditionsGrid
                if !snapshot.insight.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Forecast insight", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(theme.accentColor(for: colorScheme))
                        Text(snapshot.insight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var cachedGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                Label(snapshot.locationName, systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundStyle(theme.accentColor(for: colorScheme))

                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 46)
                        cachedGridLabel("Weather")
                        cachedGridLabel("Temperature")
                    }
                    .frame(width: 112, alignment: .leading)

                    ForEach(Array(snapshot.hourly.enumerated()), id: \.offset) { _, hour in
                        VStack(spacing: 0) {
                            Text(hour.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(height: 46)
                            Image(systemName: hour.symbolName)
                                .foregroundStyle(theme.accentColor(for: colorScheme))
                                .frame(width: 64, height: 40)
                                .background(.quaternary, in: Rectangle())
                            Text(hour.temperature)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 64, height: 36)
                                .background(.quaternary.opacity(0.65), in: Rectangle())
                        }
                    }
                }

                Text("Detailed grid data is updating in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var cachedWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                hourlyForecast
                Text("Forecast grid")
                    .font(.headline)
                cachedGridRows
                Text("Detailed grid data is updating in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 1_100, alignment: .leading)
        }
    }

    private var cachedGraph: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Forecast graph", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .foregroundStyle(theme.accentColor(for: colorScheme))
                header
                hourlyForecast
                Text("The graph is updating with the latest forecast data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var cachedGridRows: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 34)
                    cachedGridLabel("Weather")
                    cachedGridLabel("Temperature")
                }
                .frame(width: 112, alignment: .leading)

                ForEach(Array(snapshot.hourly.enumerated()), id: \.offset) { _, hour in
                    VStack(spacing: 0) {
                        Text(hour.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(height: 34)
                        Image(systemName: hour.symbolName)
                            .foregroundStyle(theme.accentColor(for: colorScheme))
                            .frame(width: 56, height: 34)
                            .background(.quaternary, in: Rectangle())
                        Text(hour.temperature)
                            .font(.caption.weight(.semibold))
                            .frame(width: 56, height: 30)
                            .background(.quaternary.opacity(0.65), in: Rectangle())
                    }
                }
            }
        }
    }

    private func cachedGridLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 40, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: snapshot.symbolName)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(theme.accentColor(for: colorScheme))
                .frame(width: 52)

            VStack(alignment: .leading, spacing: 5) {
                Label(snapshot.locationName, systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundStyle(theme.accentColor(for: colorScheme))
                    .lineLimit(2)
                Text(snapshot.condition)
                    .foregroundStyle(.secondary)
                Text(snapshot.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(snapshot.temperature)
                    .font(.system(size: 42, weight: .light, design: .rounded))
                Text("\(snapshot.low) – \(snapshot.high)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hourlyForecast: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(snapshot.hourly.enumerated()), id: \.offset) { _, hour in
                        VStack(spacing: 6) {
                            Text(hour.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: hour.symbolName)
                                .foregroundStyle(theme.accentColor(for: colorScheme))
                            Text(hour.temperature)
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(minWidth: 48)
                    }
                }
            }
        }
    }

    private var dailyForecast: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forecast")
                .font(.headline)
            ForEach(Array(snapshot.daily.prefix(10).enumerated()), id: \.offset) { _, day in
                HStack(spacing: 12) {
                    Text(day.label)
                        .frame(width: 46, alignment: .leading)
                    Image(systemName: day.symbolName)
                        .foregroundStyle(theme.accentColor(for: colorScheme))
                        .frame(width: 20)
                    Spacer()
                    Text(day.low)
                        .foregroundStyle(.secondary)
                    Text(day.high)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
    }

    private var conditionsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conditions")
                .font(.headline)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: 12, alignment: .leading)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(conditions, id: \.0) { title, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }
}
#endif
