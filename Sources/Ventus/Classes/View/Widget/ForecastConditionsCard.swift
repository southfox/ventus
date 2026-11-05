//
//  ForecastConditionsCard.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/22/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if canImport(WidgetKit)
import SwiftUI
import WidgetKit

@MainActor
protocol ForecastConditionsCard {
    var entry: ForecastWidgetEntry { get }
    var theme: VentusTheme { get }
    var colorScheme: ColorScheme { get }
}

extension ForecastConditionsCard {
    func expandedMetricIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .frame(width: 14, alignment: .center)
    }

    func expandedMetricLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label {
            Text(title) + Text(":")
        } icon: {
            expandedMetricIcon(symbol)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    func expandedMetricValue(_ value: String) -> some View {
        Text(value)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    func expandedDirectionLabel(_ title: LocalizedStringKey, degrees: Double) -> some View {
        Label {
            Text(title)
        } icon: {
            Text(WindDirectionDisplayMode.arrow.text(forWindFrom: degrees))
                .font(.body)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    func expandedDirectionValue(degrees: Double) -> some View {
        Text("\(Int(degrees.rounded()))°")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    func expandedConditions(compact: Bool, rowSpacing: CGFloat, valueSpacing: CGFloat) -> some View {
        let metricColumns = compact ? 2 : 4
        let columns = (0..<metricColumns).flatMap { _ in
            [
                GridItem(.flexible(), spacing: 3, alignment: .trailing),
                GridItem(.flexible(), spacing: valueSpacing, alignment: .leading)
            ]
        }
        return LazyVGrid(columns: columns, alignment: .leading, spacing: rowSpacing) {
            expandedMetricLabel("Wind", symbol: "wind")
            expandedMetricValue(entry.wind)
            expandedMetricLabel("Gusts", symbol: "wind.circle")
            expandedMetricValue(entry.gust)
            expandedDirectionLabel("Direction", degrees: entry.windDirectionDegrees)
            expandedDirectionValue(degrees: entry.windDirectionDegrees)
            expandedMetricLabel("Rain", symbol: "drop.fill")
            expandedMetricValue(entry.rain)
            expandedMetricLabel("Humidity", symbol: "humidity")
            expandedMetricValue(entry.humidity)
            expandedMetricLabel("Clouds", symbol: "cloud.fill")
            expandedMetricValue(entry.cloudCover)
            expandedMetricLabel("Pressure", symbol: "gauge.medium")
            expandedMetricValue(entry.pressure)
            if let windChill = entry.windChill {
                expandedMetricLabel("Wind Chill", symbol: "thermometer.snowflake")
                expandedMetricValue(windChill)
            }
            if let wave = entry.wave {
                expandedMetricLabel("Wave", symbol: "water.waves")
                expandedMetricValue(wave)
            }
        }
    }

    private func windChillWithUnit(_ value: String) -> String {
        if value.contains("°") {
            return value.replacingOccurrences(of: "°", with: entry.temperatureUnitLabel)
        }
        return "\(value) \(entry.temperatureUnitLabel)"
    }

    func expandedNonWindConditions(
        compact: Bool,
        rowSpacing: CGFloat,
        valueSpacing: CGFloat,
        metricColumnCount: Int? = nil
    ) -> some View {
        let metricColumns = metricColumnCount ?? (compact ? 2 : 4)
        let columns = (0..<metricColumns).flatMap { _ in
            [
                GridItem(.flexible(), spacing: 3, alignment: .trailing),
                GridItem(.flexible(), spacing: valueSpacing, alignment: .leading)
            ]
        }
        return LazyVGrid(columns: columns, alignment: .leading, spacing: rowSpacing) {
            expandedMetricLabel("Rain", symbol: "drop.fill")
            expandedMetricValue(entry.rain)
            expandedMetricLabel("Humidity", symbol: "humidity")
            expandedMetricValue(entry.humidity)
            expandedMetricLabel("Clouds", symbol: "cloud.fill")
            expandedMetricValue(entry.cloudCover)
            expandedMetricLabel("Pressure", symbol: "gauge.medium")
            expandedMetricValue(entry.pressure)
            if let windChill = entry.windChill {
                expandedMetricLabel("Wind Chill", symbol: "thermometer.snowflake")
                expandedMetricValue(windChillWithUnit(windChill))
            }
            if let wave = entry.wave {
                expandedMetricLabel("Wave", symbol: "water.waves")
                expandedMetricValue(wave)
            }
        }
    }

    var temperatureRange: ClosedRange<Double> {
        let lows = entry.daily.map(\.lowValue)
        let highs = entry.daily.map(\.highValue)
        let lower = lows.min() ?? 0
        let upper = max(highs.max() ?? lower, lower + 1)
        return lower...upper
    }

    func dailyForecastRow(
        _ day: ForecastWidgetDay,
        range: ClosedRange<Double>,
        compact: Bool,
        showsDayNumber: Bool,
        pointSizeReduction: CGFloat = 0,
        dayLabelWidth: CGFloat? = nil,
        dayIconGroupWidth: CGFloat? = nil,
        windOffset: CGFloat = 0,
        windMetricsWidth: CGFloat? = nil,
        windMetricSpacing: CGFloat? = nil,
        windValueColumnWidth: CGFloat? = nil
    ) -> some View {
        ForecastWidgetDailyForecastRow(
            day: day,
            range: range,
            compact: compact,
            showsDayNumber: showsDayNumber,
            theme: theme,
            pointSizeReduction: pointSizeReduction,
            dayLabelWidth: dayLabelWidth,
            dayIconGroupWidth: dayIconGroupWidth,
            windOffset: windOffset,
            windMetricsWidth: windMetricsWidth,
            windMetricSpacing: windMetricSpacing,
            windValueColumnWidth: windValueColumnWidth
        )
    }

    @ViewBuilder
    func dailyForecast(
        limit: Int,
        columns: Int = 1,
        pointSizeReduction: CGFloat = 0,
        dayLabelWidth: CGFloat? = nil,
        dayIconGroupWidth: CGFloat? = nil,
        windOffset: CGFloat = 0,
        windMetricsWidth: CGFloat? = nil,
        windMetricSpacing: CGFloat? = nil,
        windValueColumnWidth: CGFloat? = nil
    ) -> some View {
        let range = temperatureRange
        let showsDayNumber = limit >= 7
        let sourceDays = entry.daily.dropFirst()
        let days = Array(sourceDays.prefix(limit))
        if columns > 1 {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columns),
                alignment: .leading,
                spacing: 2
            ) {
                ForEach(days) { day in
                    dailyForecastRow(day, range: range, compact: true, showsDayNumber: showsDayNumber, pointSizeReduction: pointSizeReduction, dayLabelWidth: dayLabelWidth, dayIconGroupWidth: dayIconGroupWidth, windOffset: windOffset, windMetricsWidth: windMetricsWidth, windMetricSpacing: windMetricSpacing, windValueColumnWidth: windValueColumnWidth)
                }
            }
        } else {
            VStack(spacing: 4) {
                ForEach(days) { day in
                    dailyForecastRow(day, range: range, compact: false, showsDayNumber: showsDayNumber, pointSizeReduction: pointSizeReduction, dayLabelWidth: dayLabelWidth, dayIconGroupWidth: dayIconGroupWidth, windOffset: windOffset, windMetricsWidth: windMetricsWidth, windMetricSpacing: windMetricSpacing, windValueColumnWidth: windValueColumnWidth)
                }
            }
        }
    }

    func hourlyForecastHour(_ hour: ForecastWidgetHour) -> some View {
        VStack(spacing: 5) {
            Text(hour.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 14)
            Image(systemName: hour.symbolName)
                .font(.title3)
                .widgetAccentable()
                .frame(height: 22)
            Text(hour.temperature)
                .font(.caption.weight(.semibold))
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder var widgetBackground: some View {
        if theme.usesMaterial {
            Rectangle().fill(.ultraThinMaterial)
        } else {
            theme.backgroundColor(for: colorScheme)
        }
    }

    func errorCard(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.title2)
                .widgetAccentable()
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    var accessibilityDescription: String {
        entry.errorMessage ?? "\(entry.locationName). Temperature \(entry.temperature). Wind \(entry.wind), gusts \(entry.gust), from \(entry.windDirection). Rain \(entry.rain). Humidity \(entry.humidity). Cloud cover \(entry.cloudCover). Pressure \(entry.pressure).\(entry.windChill.map { " Wind chill \($0)." } ?? "")\(entry.wave.map { " Wave \($0)." } ?? "")"
    }
}

struct ForecastWidgetFontDesign: ViewModifier {
    let design: Font.Design?

    @ViewBuilder func body(content: Content) -> some View {
        if let design {
            content.fontDesign(design)
        } else {
            content
        }
    }
}
#endif
