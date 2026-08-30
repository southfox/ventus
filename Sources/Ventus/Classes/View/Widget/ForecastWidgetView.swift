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

public struct ForecastWidgetView: View, ForecastConditionsCard {
    public let entry: ForecastWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif
    let theme: VentusTheme
    let preferredReadingSize: PreferredReadingSize
    private let previewFamily: WidgetFamily?

    public init(
        entry: ForecastWidgetEntry,
        theme: VentusTheme,
        preferredReadingSize: PreferredReadingSize = .standard,
        previewFamily: WidgetFamily? = nil
    ) {
        self.entry = entry
        self.theme = theme
        self.preferredReadingSize = preferredReadingSize
        self.previewFamily = previewFamily
    }

    public var body: some View {
        styledContent
            .containerBackground(for: .widget) { widgetBackground }
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
        .preferredReadingSize(preferredReadingSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Open Ventus for the full forecast.")
        .accessibilityIdentifier("forecast.widget")
    }

    private var displayedFamily: WidgetFamily { previewFamily ?? family }
    private var usesSmallSystemWidgetFamily: Bool {
#if os(watchOS)
        false
#else
        displayedFamily != .systemExtraLarge
#endif
    }

    @ViewBuilder private var normalContent: some View {
#if os(watchOS)
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
        default:
            mediumWidgetContent
        }
#elseif os(iOS)
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
            errorCard(message)
        }
    }

    private var smallWidgetContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: entry.symbolName)
                    .font(.default)
                    .widgetAccentable()
#if !os(watchOS)
                ForecastLocationHeader(locationName: entry.locationName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
#else
                Text(entry.locationName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
#endif
            }

            HStack(spacing: 4) {
                ThermalLabel(entry.temperature, celsius: entry.temperatureCelsius)
                    .font(.system(.title3, design: .rounded).weight(.light))
                    .minimumScaleFactor(0.5)

                if entry.low != entry.high {
                    VStack(alignment: .leading, spacing: 1) {
                        Label(entry.low, systemImage: "thermometer.low")
                        Label(entry.high, systemImage: "thermometer.high")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("Low \(entry.low), high \(entry.high)")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                windGustsMetric
                HStack(alignment: .bottom, spacing: 4) {
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
            hourlyForecast(limit: 6, skippingCurrentHour: true)
        }
    }

    private var largeWidgetContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            weatherHeader
            Divider()
            hourlyForecast(limit: 6, skippingCurrentHour: true)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    weatherHeader
                    Divider()
                    hourlyForecast(limit: 10, skippingCurrentHour: true)
                    Divider()
                    expandedNonWindConditions(
                        compact: true,
                        rowSpacing: 4,
                        valueSpacing: 6,
                        metricColumnCount: 2
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Label("10-Day Forecast".localized, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accentColor(for: colorScheme))
                    dailyForecast(limit: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            insightCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var extraLargeStackedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            weatherHeader
            Divider()
            hourlyForecast(limit: 10, skippingCurrentHour: true)

            Divider()
            Label("10-Day Forecast".localized, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))
            dailyForecast(limit: 10)

            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Label("Conditions", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accentColor(for: colorScheme))

                expandedConditions(compact: true, rowSpacing: 4, valueSpacing: 4)
            }

            Divider()
            insightCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Forecast insight".localized, systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))
            Text(entry.insight)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private var weatherHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: entry.symbolName)
                        .font(.title3)
                        .widgetAccentable()
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
                }
                HStack(spacing: 4) {
                    ThermalLabel(entry.temperature, celsius: entry.temperatureCelsius, spacing: 2)
                        .font(.system(.title2, design: .rounded).weight(.light))

                    if entry.low != entry.high {
                        VStack(alignment: .leading, spacing: 1) {
                            Label(entry.low, systemImage: "thermometer.low")
                            Label(entry.high, systemImage: "thermometer.high")
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel("Low \(entry.low), high \(entry.high)")
                    }
#if !os(watchOS)
                    if displayedFamily == .systemMedium || displayedFamily == .systemLarge || displayedFamily == .systemExtraLarge {
                        Spacer()
                        windGustsMetric
                            .layoutPriority(1)
                    }
#else
                    if entry.low != entry.high {
                        ThermalLabel(entry.low, celsius: entry.lowCelsius)
                        ThermalLabel(entry.high, celsius: entry.highCelsius)
                    }
#endif
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var windGustsMetric: some View {
        HStack(alignment: .center, spacing: usesSmallSystemWidgetFamily ? 4 : 2) {
            windDirectionIndicator
            windGustsLine(usesSmallSystemWidgetFamily ? "" : "Wind", symbol: "wind", value: String(entry.wind.split(separator: " ").first!))
            if !usesSmallSystemWidgetFamily {
                Text("·")
            }
            windGustsLine("Gusts", symbol: "wind.circle", value: entry.gust)
        }
    }

    private var windDirectionIndicator: some View {
        Text(WindDirectionDisplayMode.arrow.text(forWindFrom: entry.windDirectionDegrees))
            .font(.body)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Wind direction \(entry.windDirection)")
    }

    private func windGustsLine(_ title: LocalizedStringKey, symbol: String, value: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(usesSmallSystemWidgetFamily ? .caption2 : .body)
                .foregroundStyle(.secondary)
                .frame(width: usesSmallSystemWidgetFamily ? 12 : 16, alignment: .center)
#if !os(watchOS)
            if displayedFamily != .systemSmall {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
            }
#endif
            Text(value)
                .font(usesSmallSystemWidgetFamily ? .caption2 : .subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(widgetValueMinimumScale)
        }
    }

    private var widgetValueMinimumScale: CGFloat {
#if os(watchOS)
        0.7
#else
        usesSmallSystemWidgetFamily ? 0.6 : 0.7
#endif
    }

    private func hourlyForecast(limit: Int, skippingCurrentHour: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 5) {
            let sourceHours = skippingCurrentHour ? entry.hourly.dropFirst() : entry.hourly[...]
            ForEach(Array(sourceHours.prefix(limit))) { hour in
                hourlyForecastHour(hour)
            }
        }
    }

    private func widgetMetric(_ value: String, symbol: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

#endif
