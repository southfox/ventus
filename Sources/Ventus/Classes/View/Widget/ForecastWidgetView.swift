//
//  ForecastWidgetView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/19/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if canImport(WidgetKit)
import SwiftUI
import WidgetKit

public struct ForecastWidgetView: View {
    public let entry: ForecastWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif
    private let theme: VentusTheme
    private let previewFamily: WidgetFamily?
    private let onSelectLocation: () -> Void
    private let onShowMap: () -> Void

    public init(
        entry: ForecastWidgetEntry,
        theme: VentusTheme,
        previewFamily: WidgetFamily? = nil,
        onSelectLocation: @escaping () -> Void = {},
        onShowMap: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.theme = theme
        self.previewFamily = previewFamily
        self.onSelectLocation = onSelectLocation
        self.onShowMap = onShowMap
    }

    @ViewBuilder public var body: some View {
        if isInAppPreview {
            styledContent
                .background { widgetBackground }
        } else {
            styledContent
                .containerBackground(for: .widget) { widgetBackground }
        }
    }

    @ViewBuilder private var styledContent: some View {
        Group {
            if let errorMessage = entry.errorMessage {
                errorContent(errorMessage)
            } else {
                normalContent
            }
        }
        .foregroundStyle(theme.primaryTextColor(for: colorScheme))
        .tint(theme.accentColor(for: colorScheme))
        .modifier(ForecastWidgetFontDesign(design: theme.fontDesign))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.errorMessage ?? "\(entry.locationName). Temperature \(entry.temperature). Wind \(entry.wind), gusts \(entry.gust), from \(entry.windDirection). Rain \(entry.rain). Humidity \(entry.humidity). Cloud cover \(entry.cloudCover). Pressure \(entry.pressure).\(entry.windChill.map { " Wind chill \($0)." } ?? "")\(entry.wave.map { " Wave \($0)." } ?? "")")
        .accessibilityHint("Open Ventus for the full forecast.")
        .accessibilityIdentifier("forecast.widget")
    }

    private var displayedFamily: WidgetFamily { previewFamily ?? family }

    public var isInAppPreview: Bool { previewFamily != nil }

    @ViewBuilder private var normalContent: some View {
#if os(watchOS) || os(iOS)
        switch displayedFamily {
        case .accessoryCircular:
            Image(systemName: entry.symbolName)
                .font(.title2)
                .widgetAccentable()
        case .accessoryInline:
            Text("\(entry.temperature) · \(entry.wind)")
                .lineLimit(0)
        case .accessoryRectangular:
            HStack {
                Image(systemName: entry.symbolName).widgetAccentable()
                VStack(alignment: .leading) {
                    Text(entry.locationName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(entry.temperature) · \(entry.wind)").font(.caption)
                }
            }
        case .systemSmall:
            smallWidgetContent
        case .systemMedium:
            mediumWidgetContent
        case .systemLarge:
            largeWidgetContent
        case .systemExtraLarge:
            extraLargeWidgetContent
        default:
            mediumWidgetContent
        }
#else
        switch displayedFamily {
        case .systemSmall:
            smallWidgetContent
        case .systemMedium:
            mediumWidgetContent
        case .systemLarge:
            largeWidgetContent
        case .systemExtraLarge:
            extraLargeWidgetContent
        default:
            mediumWidgetContent
        }
#endif
    }

    @ViewBuilder private func errorContent(_ message: String) -> some View {
        switch displayedFamily {
#if os(watchOS) || os(iOS)
        case .accessoryCircular:
            Image(systemName: "exclamationmark.circle")
                .font(.title2)
                .widgetAccentable()
        case .accessoryInline:
            Text(message).lineLimit(1)
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle").widgetAccentable()
                Text(message).font(.caption2).lineLimit(2)
            }
#endif
        default:
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
    }

    @ViewBuilder private var widgetBackground: some View {
        if theme.usesMaterial {
            Rectangle().fill(.ultraThinMaterial)
        } else {
            theme.backgroundColor(for: colorScheme)
        }
    }

    private var smallWidgetContent: some View {
        VStack(alignment: .leading, spacing: 4) {
#if !os(watchOS)
            ForecastLocationHeader(locationName: entry.locationName)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
#else
            Text(entry.locationName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
#endif

            HStack(spacing: 8) {
                Image(systemName: entry.symbolName)
                    .font(.default)
                    .widgetAccentable()
                ThermalLabel(entry.temperature, celsius: entry.temperatureCelsius)
                    .font(.system(.title3, design: .rounded).weight(.light))
                    .minimumScaleFactor(0.5)
            }
            VStack(alignment: .leading, spacing: 8) {
                windGustsMetric
                HStack(alignment: .bottom, spacing: 8) {
                    widgetMetric(entry.rain, symbol: "drop.fill")
                    widgetMetric(entry.cloudCover, symbol: "cloud.fill")
                }
            }
        }
    }

    private var mediumWidgetContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            weatherHeader
            Divider()
            hourlyForecast(limit: 6)
        }
    }

    private var largeWidgetContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            weatherHeader
            Divider()
            hourlyForecast(limit: 6)
            Divider()
            dailyForecast(limit: 5)
        }
    }

    private var stacksExtraLargeSections: Bool {
#if os(iOS)
        horizontalSizeClass == .compact && verticalSizeClass == .regular
#else
        false
#endif
    }

    @ViewBuilder private var extraLargeWidgetContent: some View {
        if stacksExtraLargeSections {
            extraLargeStackedContent
        } else {
            extraLargeColumnContent
        }
    }

    private var extraLargeColumnContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    weatherHeader
                        Divider()
                    if isInAppPreview {
                        ScrollView(.horizontal, showsIndicators: false) {
                            hourlyForecast(limit: entry.hourly.count)
                        }
                    } else {
                        hourlyForecast(limit: 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Label("10-Day Forecast".localized, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accentColor(for: colorScheme))
                    dailyForecast(limit: 10, columns: isInAppPreview ? 1 : 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()

            Label("Conditions", systemImage: "list.bullet.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))

            expandedConditions(compact: false)
            Divider()
            insightCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var extraLargeStackedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            weatherHeader
            Divider()
            if isInAppPreview {
                ScrollView(.horizontal, showsIndicators: false) {
                    hourlyForecast(limit: entry.hourly.count)
                }
            } else {
                hourlyForecast(limit: 10)
            }

            Divider()
            Label("10-Day Forecast".localized, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))
            dailyForecast(limit: 10)

            Divider()
            Label("Conditions", systemImage: "list.bullet.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))

            expandedConditions(compact: true)

            Divider()
            insightCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: isInAppPreview ? 8 : 4) {
            Label("Forecast insight".localized, systemImage: "sparkles")
                .font(isInAppPreview ? .headline : .subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))
#if !os(watchOS)
            if isInAppPreview {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entry.insight.markdownSections.enumerated()), id: \.offset) { _, section in
                        Text(markdown: section)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(entry.insight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
#else
            Text(entry.insight)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
#endif
        }
    }

    private func expandedConditions(compact: Bool) -> some View {
        let metricColumns = compact ? 2 : 4
        let valueSpacing: CGFloat = isInAppPreview ? 12 : 4
        let columns = (0..<metricColumns).flatMap { _ in
            [
                GridItem(.flexible(), spacing: 3, alignment: .trailing),
                GridItem(.flexible(), spacing: valueSpacing, alignment: .leading)
            ]
        }
        return LazyVGrid(columns: columns, alignment: .leading, spacing: isInAppPreview ? 12 : 4) {
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

    private func expandedMetricIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .frame(width: 14, alignment: .center)
    }

    private func expandedMetricLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label {
            Text(title) + Text(":")
        } icon: {
            expandedMetricIcon(symbol)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private func expandedMetricValue(_ value: String) -> some View {
        Text(value)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func expandedDirectionLabel(_ title: LocalizedStringKey, degrees: Double) -> some View {
        Label {
            Text(title)
        } icon: {
            expandedMetricIcon("arrow.down")
                .rotationEffect(.degrees(degrees))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private func expandedDirectionValue(degrees: Double) -> some View {
        Text("\(Int(degrees.rounded()))°")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var weatherHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
#if !os(watchOS)
                ForecastLocationHeader(
                    locationName: entry.locationName,
                    onSelectLocation: isInAppPreview ? onSelectLocation : nil,
                    onShowMap: isInAppPreview ? onShowMap : nil
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
#else
                Text(entry.locationName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
#endif
                HStack(spacing: 10) {
                    ThermalLabel(entry.temperature, celsius: entry.temperatureCelsius)
                        .font(.system(isInAppPreview ? .title : .title2, design: .rounded).weight(.light))
                        .minimumScaleFactor(0.5)

#if !os(watchOS)
                    if isInAppPreview {
                    // if displayedFamily == .systemLarge || displayedFamily == .systemExtraLarge {
                        RealTemperatureLabel(entry.realTemperature, celsius: entry.realTemperatureCelsius)
                            .font(.system(.title, design: .rounded).weight(.light))
                            .minimumScaleFactor(0.5)
                    } else if displayedFamily == .systemExtraLarge {
                        ThermalLabel(entry.low, celsius: entry.lowCelsius)
                        ThermalLabel(entry.high, celsius: entry.highCelsius)
                    }
                    if !isInAppPreview && displayedFamily != .systemSmall {
                        Spacer()
                        windGustsMetric
                            .layoutPriority(1)
                    }
#else
                    ThermalLabel(entry.low, celsius: entry.lowCelsius)
                    ThermalLabel(entry.high, celsius: entry.highCelsius)
#endif
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var windGustsMetric: some View {
        HStack(alignment: .center, spacing: 6) {
            windGustsLine("Wind", symbol: "wind", value: String(entry.wind.split(separator: " ").first!))
            windGustsLine("Gusts", symbol: "wind.circle", value: entry.gust)
        }
    }

    private func windGustsLine(_ title: LocalizedStringKey, symbol: String, value: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)
#if !os(watchOS)
            if displayedFamily != .systemSmall {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }
#endif
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func hourlyForecast(limit: Int) -> some View {
        HStack(alignment: .top, spacing: isInAppPreview ? 25 : 5) {
            ForEach(Array(entry.hourly.prefix(limit))) { hour in
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
        }
    }

    @ViewBuilder
    private func dailyForecast(limit: Int, columns: Int = 1) -> some View {
        let range = temperatureRange
        let days = Array(entry.daily.prefix(limit))
        if columns > 1 {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns),
                alignment: .leading,
                spacing: 5
            ) {
                ForEach(days) { day in
                    dailyForecastRow(day, range: range, compact: true)
                }
            }
        } else {
            VStack(spacing: 8) {
                ForEach(days) { day in
                    dailyForecastRow(day, range: range, compact: false)
                }
            }
        }
    }

    private func dailyForecastRow(
        _ day: ForecastWidgetDay,
        range: ClosedRange<Double>,
        compact: Bool
    ) -> some View {
        HStack(spacing: compact ? 5 : 10) {
            Text(day.label)
                .font((compact ? Font.caption2 : .caption).weight(.medium))
                .frame(width: compact ? 34 : 42, alignment: .leading)
            Image(systemName: day.symbolName)
                .font(compact ? .caption : .body)
                .widgetAccentable()
                .frame(width: 22)
            Text(day.low)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
            temperatureTrack(for: day, in: range)
                .frame(height: 5)
            Text(day.high)
                .font((compact ? Font.caption2 : .caption).weight(.semibold))
                .frame(width: 30, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var temperatureRange: ClosedRange<Double> {
        let lows = entry.daily.map(\.lowValue)
        let highs = entry.daily.map(\.highValue)
        let lower = lows.min() ?? 0
        let upper = max(highs.max() ?? lower, lower + 1)
        return lower...upper
    }

    private func temperatureTrack(for day: ForecastWidgetDay, in range: ClosedRange<Double>) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let span = max(range.upperBound - range.lowerBound, 1)
            let lowFraction = min(max((day.lowValue - range.lowerBound) / span, 0), 1)
            let highFraction = min(max((day.highValue - range.lowerBound) / span, 0), 1)
            let segmentWidth = max(width * CGFloat(highFraction - lowFraction), 6)
            let leading = min(max(width * CGFloat(lowFraction), 0), width - segmentWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.accentColor(for: colorScheme).opacity(0.16))

                temperatureGradient
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: segmentWidth)
                            .offset(x: leading)
                    }
            }
        }
    }

    private var temperatureGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.78, blue: 0.98),
                Color(red: 0.42, green: 0.85, blue: 0.62),
                .yellow,
                .orange,
                .red
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func nameOnly(_ locationName: String) -> String {
        guard let range = locationName.range(of: " #") else { return locationName }
        return String(locationName[..<range.lowerBound])
    }

    private func widgetMetric(_ value: String, symbol: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func windAndGustText(_ wind: String, _ gust: String) -> String {
        let windValue = wind.split(separator: " ").first.map(String.init) ?? wind
        let gustParts = gust.split(separator: " ")
        let gustValue = gustParts.first.map(String.init) ?? gust
        let unit = gustParts.dropFirst().joined(separator: " ")
        return unit.isEmpty ? "\(windValue) / \(gustValue)" : "\(windValue) / \(gustValue) \(unit)"
    }
}

private struct ForecastWidgetFontDesign: ViewModifier {
    let design: Font.Design?

    @ViewBuilder func body(content: Content) -> some View {
        if let design {
            content.fontDesign(design)
        } else {
            content
        }
    }
}

#if DEBUG && !os(watchOS)
#Preview("Small widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemSmall)
        .frame(width: 158, height: 158)
        .padding()
        .background(.blue.gradient)
}

#Preview("Medium widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemMedium)
        .frame(width: 338, height: 158)
        .padding()
        .background(.blue.gradient)
}

#Preview("Large widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemLarge)
        .frame(width: 338, height: 354)
        .padding()
        .background(.blue.gradient)
}

#Preview("iPad extra-large widget") {
    ForecastWidgetView(entry: .stormPreview, theme: .ocean, previewFamily: .systemExtraLarge)
        .frame(width: 720, height: 338)
        .padding()
        .background(.blue.gradient)
}

#endif
#endif

