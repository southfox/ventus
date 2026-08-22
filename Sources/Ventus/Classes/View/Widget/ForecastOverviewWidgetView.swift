//
//  ForecastOverviewWidgetView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/22/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if canImport(WidgetKit) && !os(watchOS)
import SwiftUI
import WidgetKit

struct ForecastOverviewWidgetView: View, ForecastConditionsCard {
    let entry: ForecastWidgetEntry
    let theme: VentusTheme
    var detailedHours: [ForecastOverviewHour] = []
    var temperatureUnit: Binding<TemperatureUnit> = .constant(.celsius)
    var onSelectLocation: () -> Void = {}
    var onShowMap: () -> Void = {}

    @Environment(\.colorScheme) var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif

    var body: some View {
        styledContent
            .background { widgetBackground }
    }

    @ViewBuilder private var styledContent: some View {
        Group {
            if let errorMessage = entry.errorMessage {
                errorCard(errorMessage)
            } else {
                content
            }
        }
        .foregroundStyle(theme.primaryTextColor(for: colorScheme))
        .tint(theme.accentColor(for: colorScheme))
        .modifier(ForecastWidgetFontDesign(design: theme.fontDesign))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Open Ventus for the full forecast.")
        .accessibilityIdentifier("forecast.widget")
    }

    private var stacksSections: Bool {
#if os(iOS)
        horizontalSizeClass == .compact && verticalSizeClass == .regular
#else
        false
#endif
    }

    @ViewBuilder private var content: some View {
        if stacksSections {
            stackedContent
        } else {
            columnContent
        }
    }

    private var columnContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    weatherHeader
                    Divider()
                    ScrollView(.horizontal, showsIndicators: false) {
                        hourlyForecast
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Label("10-Day Forecast".localized, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accentColor(for: colorScheme))
                    dailyForecast(limit: 10, columns: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Conditions", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accentColor(for: colorScheme))

                expandedConditions(compact: false, rowSpacing: 12, valueSpacing: 12)
            }
            Divider()
            insightCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            weatherHeader
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                hourlyForecast
            }

            Divider()
            Label("10-Day Forecast".localized, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))
            dailyForecast(limit: 10)

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label("Conditions", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accentColor(for: colorScheme))

                expandedConditions(compact: true, rowSpacing: 12, valueSpacing: 12)
            }

            Divider()
            insightCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Forecast insight".localized, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(theme.accentColor(for: colorScheme))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(entry.insight.markdownSections.enumerated()), id: \.offset) { _, section in
                    Text(markdown: section)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var weatherHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                ForecastLocationHeader(
                    locationName: entry.locationName,
                    onSelectLocation: onSelectLocation,
                    onShowMap: onShowMap
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                ForecastUnitSelector(
                    "Temperature unit",
                    selection: temperatureUnit,
                    unitTitle: \.label
                ) {
                    HStack(spacing: 10) {
                        ThermalLabel(entry.temperature, celsius: entry.temperatureCelsius)
                            .font(.system(.title, design: .rounded).weight(.light))
                            .minimumScaleFactor(0.5)
                        RealTemperatureLabel(entry.realTemperature, celsius: entry.realTemperatureCelsius)
                            .font(.system(.title, design: .rounded).weight(.light))
                            .minimumScaleFactor(0.5)
                        Text(temperatureUnit.wrappedValue.label)
                            .font(.system(.title, design: .rounded).weight(.light))
                            .foregroundStyle(theme.accentColor(for: colorScheme))
                            .minimumScaleFactor(0.5)
                    }
                }
                .accessibilityLabel("Temperature")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var hourlyForecast: some View {
        if detailedHours.isEmpty {
            HStack(alignment: .top, spacing: 25) {
                ForEach(entry.hourly) { hour in
                    hourlyForecastHour(hour)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 18) {
                ForEach(detailedHours) { hour in
                    detailedHourColumn(hour)
                }
            }
        }
    }

    private func detailedHourColumn(_ hour: ForecastOverviewHour) -> some View {
        VStack(spacing: 4) {
            if !hour.dayLabel.isEmpty {
                Text(hour.dayLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(hour.timeLabel)
                .font(.caption.bold())
                .lineLimit(1)
            if let daylightTime = hour.daylightTime, let daylightSymbolName = hour.daylightSymbolName {
                HStack(spacing: 4) {
                    Image(systemName: daylightSymbolName)
                        .foregroundStyle(.orange)
                    Text(daylightTime)
                }
                .font(.caption2)
            }
            Image(systemName: hour.symbolName)
                .font(.title3)
                .widgetAccentable()
                .padding(.vertical, 2)
            Text(hour.temperature)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 3) {
                detailedHourRow("wind", hour.wind)
                detailedHourRow("wind.circle", hour.gust)
                detailedHourRow("arrow.down", "\(Int(hour.windDirectionDegrees.rounded()))°")
                if let windChill = hour.windChill {
                    detailedHourRow("thermometer.snowflake", windChill)
                }
                detailedHourRow("snowflake", hour.freezingLevel)
                if let rain = hour.rain {
                    detailedHourRow("drop.fill", rain)
                }
                if let sleet = hour.sleet {
                    detailedHourRow("cloud.sleet.fill", sleet)
                }
                if let snow = hour.snow {
                    detailedHourRow("cloud.snow.fill", snow)
                }
            }
        }
        .frame(width: 108, alignment: .top)
    }

    private func detailedHourRow(_ symbol: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .center)
            Text(value)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#if DEBUG
#Preview("Overview widget card") {
    ForecastOverviewWidgetView(entry: .stormPreview, theme: .ocean)
        .frame(width: 720, height: 500)
        .padding()
        .background(.blue.gradient)
}
#endif
#endif
