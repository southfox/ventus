//
//  ForecastWidgetDailyForecastRow.swift
//  Ventus package
//

#if canImport(WidgetKit)
import SwiftUI
import WidgetKit

/// A self-contained daily forecast line used by the large widget. Keeping the
/// layout in a view makes its spacing parameters easy to preview and reuse.
@MainActor
struct ForecastWidgetDailyForecastRow: View {
    let day: ForecastWidgetDay
    let range: ClosedRange<Double>
    let compact: Bool
    let showsDayNumber: Bool
    let theme: VentusTheme
    let pointSizeReduction: CGFloat
    let dayLabelWidth: CGFloat?
    let dayIconGroupWidth: CGFloat?
    let windOffset: CGFloat
    let windMetricsWidth: CGFloat?
    let windMetricSpacing: CGFloat?
    let windValueColumnWidth: CGFloat?

    @Environment(\.colorScheme) private var colorScheme

    init(
        day: ForecastWidgetDay,
        range: ClosedRange<Double>,
        compact: Bool,
        showsDayNumber: Bool,
        theme: VentusTheme,
        pointSizeReduction: CGFloat = 0,
        dayLabelWidth: CGFloat? = nil,
        dayIconGroupWidth: CGFloat? = nil,
        windOffset: CGFloat = 0,
        windMetricsWidth: CGFloat? = nil,
        windMetricSpacing: CGFloat? = nil,
        windValueColumnWidth: CGFloat? = nil
    ) {
        self.day = day
        self.range = range
        self.compact = compact
        self.showsDayNumber = showsDayNumber
        self.theme = theme
        self.pointSizeReduction = pointSizeReduction
        self.dayLabelWidth = dayLabelWidth
        self.dayIconGroupWidth = dayIconGroupWidth
        self.windOffset = windOffset
        self.windMetricsWidth = windMetricsWidth
        self.windMetricSpacing = windMetricSpacing
        self.windValueColumnWidth = windValueColumnWidth
    }

    var body: some View {
        let labelWidth = dayLabelWidth ?? (compact ? 26 : 32)
        let iconGroupWidth = dayIconGroupWidth ?? (compact ? 48 : 56)
        HStack(spacing: compact ? 2 : 5) {
            HStack(spacing: compact ? 2 : 3) {
                Text(dailyLabel)
                    .font(dailyFont(compact ? .caption2 : .caption, baseSize: compact ? 10 : 12, weight: .medium))
                    .frame(width: labelWidth, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: day.symbolName)
                    .font(dailyFont(compact ? .caption : .body, baseSize: compact ? 12 : 17))
                    .widgetAccentable()
                    .frame(width: 20, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            // Keep the day and its symbol together instead of allowing the
            // flexible temperature track to visually push the symbol away.
            .frame(width: iconGroupWidth, alignment: .leading)
            Text(day.low)
                .font(dailyFont(compact ? .caption2 : .caption, baseSize: compact ? 10 : 12))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            temperatureTrack
                .frame(height: 5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(day.high)
                .font(dailyFont(compact ? .caption2 : .caption, baseSize: compact ? 10 : 12, weight: .semibold))
                .frame(width: 26, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            dailyWindMetrics
                .offset(x: windOffset)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dailyLabel: String {
        guard !showsDayNumber else { return day.label }
        let components = day.label.split(separator: " ")
        guard let last = components.last, last.allSatisfy(\.isNumber) else { return day.label }
        return components.dropLast().joined(separator: " ")
    }

    private var temperatureTrack: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let span = max(range.upperBound - range.lowerBound, 1)
            let lowFraction = min(max((day.lowValue - range.lowerBound) / span, 0), 1)
            let highFraction = min(max((day.highValue - range.lowerBound) / span, 0), 1)
            let segmentWidth = max(width * CGFloat(highFraction - lowFraction), 6)
            let leading = min(max(width * CGFloat(lowFraction), 0), width - segmentWidth)

            ZStack(alignment: .leading) {
                Capsule().fill(theme.accentColor(for: colorScheme).opacity(0.16))
                temperatureGradient.mask(alignment: .leading) {
                    Capsule().frame(width: segmentWidth).offset(x: leading)
                }
            }
        }
    }

    @ViewBuilder
    private var dailyWindMetrics: some View {
        if let degrees = day.windDirectionDegrees {
            HStack(spacing: windMetricSpacing ?? (compact ? 3 : 4)) {
                Text(WindDirectionDisplayMode.arrow.text(forWindFrom: degrees))
                    .font(dailyFont(compact ? .caption : .subheadline, baseSize: compact ? 10 : 13))
                    .foregroundStyle(.secondary)
                    .frame(width: compact ? 11 : 12, alignment: .leading)
                if let wind = day.wind {
                    HStack(spacing: windIconValueSpacing) {
                        Image(systemName: "wind").frame(width: compact ? 11 : 13, alignment: .leading)
                        Text(dailyWindValue(wind))
                            .font(dailyFont(compact ? .caption2 : .caption, baseSize: compact ? 11 : 11, weight: .medium))
                            .frame(width: windValueColumnWidth ?? (compact ? 18 : 20), alignment: .leading)
                    }
                }
                if let gust = day.gust {
                    HStack(spacing: windIconValueSpacing) {
                        Image(systemName: "wind.circle").frame(width: compact ? 11 : 13, alignment: .leading)
                        Text(dailyWindValue(gust))
                            .font(dailyFont(compact ? .caption2 : .caption, baseSize: compact ? 9 : 10, weight: .medium))
                            .frame(width: windValueColumnWidth ?? (compact ? 18 : 20), alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .font(dailyFont(compact ? .caption : .subheadline, baseSize: compact ? 12 : 16))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityLabel("Wind direction \(Int(degrees.rounded())) degrees, wind \(day.wind ?? "—"), gusts \(day.gust ?? "—")")
        }
    }

    /// Keep the visual gap beside the wider SF Symbols readable even when the
    /// surrounding metrics use a compact inter-column spacing.
    private var windIconValueSpacing: CGFloat {
        max(windMetricSpacing ?? 0, compact ? 3 : 6)
    }

    private var temperatureGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.36, green: 0.78, blue: 0.98),
                Color(red: 0.42, green: 0.85, blue: 0.62),
                .yellow, .orange, .red
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func dailyWindValue(_ value: String) -> String {
        String(value.split(separator: " ").first ?? "—")
    }

    private func dailyFont(
        _ standard: Font,
        baseSize: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        guard pointSizeReduction > 0 else { return standard }
        return .system(size: max(baseSize - pointSizeReduction, 1), weight: weight)
    }
}

#Preview("Daily forecast row", traits: .sizeThatFitsLayout) {
    VStack {
        ForecastWidgetDailyForecastRow(
            day: ForecastWidgetDay(
                label: "Sat 20",
                symbolName: "cloud.sun.fill",
                low: "-3°",
                high: "14°",
                lowValue: -3,
                highValue: 14,
                wind: "12 km/h",
                gust: "20 km/h",
                windDirectionDegrees: 285
            ),
            range: -5...18,
            compact: false,
            showsDayNumber: true,
            theme: .system
        )
        .padding()
        ForecastWidgetDailyForecastRow(
            day: ForecastWidgetDay(
                label: "Sat 20",
                symbolName: "cloud.sun.fill",
                low: "-3°",
                high: "14°",
                lowValue: -3,
                highValue: 14,
                wind: "12 km/h",
                gust: "20 km/h",
                windDirectionDegrees: 285
            ),
            range: -5...18,
            compact: true,
            showsDayNumber: true,
            theme: .system
        )
        .padding()
    }
}
#endif
