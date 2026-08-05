#if canImport(WidgetKit) && !os(tvOS)
import Forescoop
import SwiftUI
import WidgetKit

public struct ForecastWidgetView: View {
    public let entry: ForecastWidgetEntry
    @Environment(\.widgetFamily) private var family
    private let theme: VentusTheme
    private let previewFamily: WidgetFamily?

    public init(
        entry: ForecastWidgetEntry,
        theme: VentusTheme = VentusThemeStore.load(),
        previewFamily: WidgetFamily? = nil
    ) {
        self.entry = entry
        self.theme = theme
        self.previewFamily = previewFamily
    }

    @ViewBuilder public var body: some View {
        Group {
#if os(watchOS) || os(iOS)
            switch displayedFamily {
            case .accessoryCircular:
                Image(systemName: entry.symbolName)
                    .font(.title2)
                    .widgetAccentable()
            case .accessoryInline:
                Text("\(entry.temperature) · \(entry.wind)")
            case .accessoryRectangular:
                HStack {
                    Image(systemName: entry.symbolName).widgetAccentable()
                    VStack(alignment: .leading) {
                        Text(entry.locationName).lineLimit(1)
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
            mediumWidgetContent
#endif
        }
        .foregroundStyle(theme.primaryTextColor)
        .tint(theme.accentColor)
        .containerBackground(for: .widget) { widgetBackground }
        .modifier(ForecastWidgetFontDesign(design: theme.fontDesign))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.locationName). Temperature \(entry.temperature). Wind \(entry.wind), gusts \(entry.gust), from \(entry.windDirection). Rain \(entry.rain). Humidity \(entry.humidity). Cloud cover \(entry.cloudCover). Pressure \(entry.pressure).")
        .accessibilityHint("Open Ventus for the full forecast.")
        .accessibilityIdentifier("forecast.widget")
    }

    private var displayedFamily: WidgetFamily { previewFamily ?? family }

    @ViewBuilder private var widgetBackground: some View {
        if theme.usesMaterial {
            Rectangle().fill(.ultraThinMaterial)
        } else {
            theme.backgroundColor
        }
    }

    private var smallWidgetContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.locationName)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 8) {
                Image(systemName: entry.symbolName)
                    .font(.title)
                    .widgetAccentable()
                Text(entry.temperature)
                    .font(.title.bold())
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 4) {
                    widgetMetric(entry.wind, symbol: "wind")
                    widgetMetric(entry.gust, symbol: "wind.circle")
                }
                widgetMetric(entry.rain, symbol: "drop.fill")
                widgetMetric(entry.cloudCover, symbol: "cloud.fill")
                widgetMetric(entry.humidity, symbol: "humidity")
                widgetMetric(entry.pressure, symbol: "gauge.medium")
            }
        }
    }

    private var mediumWidgetContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            weatherHeader
            hourlyForecast(limit: 6)
        }
    }

    private var largeWidgetContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            weatherHeader
            hourlyForecast(limit: 6)
            Divider()
            dailyForecast(limit: 4)
        }
    }

    /// The iPad-only extra-large canvas has room for both the near-term
    /// outlook and the multi-day forecast at a comfortably readable size.
    private var extraLargeWidgetContent: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                weatherHeader
                Divider()
                hourlyForecast(limit: 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("10-Day Forecast")
                    .font(.headline)
                // Five compact rows across two columns use the iPad canvas
                // for a full ten-day outlook rather than leaving it sparse.
                dailyForecast(limit: 10, columns: 2)
                Divider()
                HStack(spacing: 14) {
                    widgetMetric(entry.wind, symbol: "wind")
                    widgetMetric(entry.gust, symbol: "wind.circle")
                    widgetMetric(entry.rain, symbol: "drop.fill")
                    widgetMetric(entry.humidity, symbol: "humidity")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weatherHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.locationName)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.temperature)
                    .font(.system(size: 48, weight: .light, design: .rounded))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: entry.symbolName)
                    .font(.title)
                    .widgetAccentable()
                Text(entry.condition)
                    .font(.subheadline.weight(.medium))
                Text("H:\(entry.high)  L:\(entry.low)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func hourlyForecast(limit: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(entry.hourly.prefix(limit))) { hour in
                VStack(spacing: 5) {
                    Text(hour.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: hour.symbolName)
                        .font(.title3)
                        .widgetAccentable()
                    Text(hour.temperature)
                        .font(.caption.weight(.semibold))
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
                .frame(width: 25, alignment: .trailing)
            Capsule()
                .fill(theme.accentColor.opacity(0.18))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(theme.accentColor)
                        .frame(width: temperatureBarWidth(for: day, in: range, compact: compact))
                }
                .frame(height: 5)
            Text(day.high)
                .font((compact ? Font.caption2 : .caption).weight(.semibold))
                .frame(width: 25, alignment: .leading)
        }
    }

    private var temperatureRange: ClosedRange<Double> {
        let lows = entry.daily.map(\.lowValue)
        let highs = entry.daily.map(\.highValue)
        let lower = lows.min() ?? 0
        let upper = max(highs.max() ?? lower, lower + 1)
        return lower...upper
    }

    private func temperatureBarWidth(
        for day: ForecastWidgetDay,
        in range: ClosedRange<Double>,
        compact: Bool = false
    ) -> CGFloat {
        let span = max(range.upperBound - range.lowerBound, 1)
        let fraction = max((day.highValue - day.lowValue) / span, 0.18)
        return (compact ? 42 : 92) * fraction
    }

    private func widgetMetric(_ value: String, symbol: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
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

#if DEBUG
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
