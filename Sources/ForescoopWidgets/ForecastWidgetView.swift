#if canImport(WidgetKit) && !os(tvOS)
import Forescoop
import SwiftUI
import WidgetKit

public struct ForecastWidgetView: View {
    public let entry: ForecastWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
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
            if let errorMessage = entry.errorMessage {
                errorContent(errorMessage)
            } else {
                normalContent
            }
        }
        .foregroundStyle(theme.primaryTextColor(for: colorScheme))
        .tint(theme.accentColor(for: colorScheme))
        .containerBackground(for: .widget) { widgetBackground }
        .modifier(ForecastWidgetFontDesign(design: theme.fontDesign))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.errorMessage ?? "\(entry.locationName). Temperature \(entry.temperature). Wind \(entry.wind), gusts \(entry.gust), from \(entry.windDirection). Rain \(entry.rain). Humidity \(entry.humidity). Cloud cover \(entry.cloudCover). Pressure \(entry.pressure).")
        .accessibilityHint("Open Ventus for the full forecast.")
        .accessibilityIdentifier("forecast.widget")
    }

    private var displayedFamily: WidgetFamily { previewFamily ?? family }

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
#elseif os(macOS)
        switch displayedFamily {
        case .systemSmall:
            smallWidgetContent
        case .systemMedium:
            mediumWidgetContent
        case .systemLarge:
            largeWidgetContent
        default:
            mediumWidgetContent
        }
#else
        mediumWidgetContent
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
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.locationName)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 8) {
                Image(systemName: entry.symbolName)
                    .font(.title)
                    .widgetAccentable()
                ThermalLabel(entry.temperature, celsius: entry.temperatureCelsius)
                    .font(.system(.title, design: .rounded).weight(.light))
                    .minimumScaleFactor(0.5)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    widgetMetric(entry.wind, symbol: "wind")
                    widgetMetric(entry.gust, symbol: "wind.circle")
                }
                HStack(alignment: .bottom, spacing: 8) {
                    widgetMetric(entry.rain, symbol: "drop.fill")
                    widgetMetric(entry.cloudCover, symbol: "cloud.fill")
                }
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

    /// iPad only.
    private var extraLargeWidgetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    dailyForecast(limit: 10, columns: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
            Divider()
            Text("Conditions")
                .font(.headline)
            expandedConditions

            Divider()
            insightCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Forecast insight", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentColor(for: colorScheme))
            Text(entry.insight)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var expandedConditions: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4),
            alignment: .leading,
            spacing: 12
        ) {
            expandedMetric("Wind", value: entry.wind, symbol: "wind")
            expandedMetric("Gusts", value: entry.gust, symbol: "wind.circle")
            expandedDirectionMetric("Direction", degrees: entry.windDirectionDegrees)
            expandedMetric("Rain", value: entry.rain, symbol: "drop.fill")
            expandedMetric("Humidity", value: entry.humidity, symbol: "humidity")
            expandedMetric("Clouds", value: entry.cloudCover, symbol: "cloud.fill")
            expandedMetric("Pressure", value: entry.pressure, symbol: "gauge.medium")
        }
    }

    private func expandedMetric(_ title: LocalizedStringKey, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func expandedDirectionMetric(_ title: LocalizedStringKey, degrees: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "arrow.down")
                    .rotationEffect(.degrees(degrees))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            Text("\(Int(degrees.rounded()))°")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var weatherHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.locationName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 10) {
                ThermalLabel(entry.temperature, celsius: entry.temperatureCelsius)
                    .font(.system(.title, design: .rounded).weight(.light))
                    .minimumScaleFactor(0.5)

                if previewFamily == .systemExtraLarge {
                    ThermalLabel(entry.rawTemperature, celsius: entry.temperatureCelsius)
                        .font(.system(.title, design: .rounded).weight(.light))
                        .minimumScaleFactor(0.5)
                }

                    ThermalLabel(entry.low, celsius: entry.lowCelsius)
                    ThermalLabel(entry.high, celsius: entry.highCelsius)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: entry.symbolName)
                    .font(.title)
                    .widgetAccentable()
                Text(entry.condition)
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private func hourlyForecast(limit: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(entry.hourly.prefix(limit))) { hour in
                VStack(spacing: 5) {
                    Text(hour.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

