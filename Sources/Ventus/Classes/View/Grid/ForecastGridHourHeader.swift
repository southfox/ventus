//
//  ForecastGridHourHeader.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/01/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

struct ForecastGridHourHeader: View {
    let hours: [String]
    let columnWidth: CGFloat
    let columnSpacing: CGFloat
    let height: CGFloat
    let day: (String) -> String
    let time: (String) -> String
    let weatherSymbols: (String) -> [String]
    let daylightSymbol: (String) -> String?
    let precipitationAgreement: (String) -> ForecastPrecipitationAgreement?
    let precipitationSymbol: (String) -> String
    let daylightOverlay: (String) -> Color
    let selectedHour: String?
    let onSelectHour: (String) -> Void
#if os(tvOS)
    @FocusState private var focusedHour: String?
#endif

    var body: some View {
        LazyHStack(spacing: columnSpacing) {
            ForEach(hours, id: \.self) { hour in
#if os(tvOS)
                ForecastGridHourCell(
                    hour: hour,
                    columnWidth: columnWidth,
                    height: height,
                    day: day,
                    time: time,
                    weatherSymbols: weatherSymbols,
                    daylightSymbol: daylightSymbol,
                    precipitationAgreement: precipitationAgreement,
                    precipitationSymbol: precipitationSymbol,
                    daylightOverlay: daylightOverlay,
                    isSelected: selectedHour == hour,
                    onSelect: onSelectHour,
                    focusedHour: $focusedHour
                )
#else
                ForecastGridHourCell(
                    hour: hour,
                    columnWidth: columnWidth,
                    height: height,
                    day: day,
                    time: time,
                    weatherSymbols: weatherSymbols,
                    daylightSymbol: daylightSymbol,
                    precipitationAgreement: precipitationAgreement,
                    precipitationSymbol: precipitationSymbol,
                    daylightOverlay: daylightOverlay,
                    isSelected: selectedHour == hour,
                    onSelect: onSelectHour
                )
#endif
            }
        }
#if os(tvOS)
        .onChange(of: focusedHour) { _, hour in
            guard let hour else { return }
            onSelectHour(hour)
        }
#endif
    }
}

struct ForecastGridHourCell: View {
    @Environment(\.ventusTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let hour: String
    let columnWidth: CGFloat
    let height: CGFloat
    let day: (String) -> String
    let time: (String) -> String
    let weatherSymbols: (String) -> [String]
    let daylightSymbol: (String) -> String?
    let precipitationAgreement: (String) -> ForecastPrecipitationAgreement?
    let precipitationSymbol: (String) -> String
    let daylightOverlay: (String) -> Color
    let isSelected: Bool
    let onSelect: (String) -> Void
#if os(tvOS)
    let focusedHour: FocusState<String?>.Binding
#endif

    var body: some View {
        Button {
            onSelect(hour)
        } label: {
            VStack(spacing: 2) {
                let agreement = precipitationAgreement(hour)
                let isMoonPhase = daylightSymbol(hour)?.hasPrefix("moonphase.") == true
                let showsPrecipitationInWeatherRow = !isMoonPhase && weatherSymbols(hour).isEmpty && (agreement?.percentage ?? 0) > 0
                let spreadsWeatherSymbols = !isMoonPhase &&
                    (agreement?.percentage ?? 0) == 0 &&
                    weatherSymbols(hour).count > 1
                Text(day(hour))
                    .font(dayFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: 13)
                Text(time(hour))
                    .font(timeFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: 15)
                HStack(spacing: 2) {
                    if let daylightSymbol = daylightSymbol(hour) {
                        Image(systemName: daylightSymbol)
                            .font(.title3)
                            .foregroundStyle(daylightSymbol.hasPrefix("moon") ? .indigo : .orange)
                    }
                    if !isMoonPhase {
                        let displayedWeatherSymbols = spreadsWeatherSymbols
                            ? weatherSymbols(hour).prefix(1)
                            : weatherSymbols(hour).prefix(3)
                        let n = displayedWeatherSymbols.count + (showsPrecipitationInWeatherRow ? 1 : 0)
                        ForEach(displayedWeatherSymbols, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(n == 1 ? .title3 : .caption)
                        }
                        if showsPrecipitationInWeatherRow {
                            Image(systemName: precipitationSymbol(hour))
                                .font(n == 1 ? .title3 : .caption)
                        }
                    }
                }
                .font(.caption2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(height: 22)
                if isMoonPhase, agreement?.percentage == 0 {
                    HStack(spacing: 2) {
                        ForEach(weatherSymbols(hour).prefix(1), id: \.self) { symbol in
                            Image(systemName: symbol)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: 11)
                } else if spreadsWeatherSymbols {
                    HStack(spacing: 2) {
                        ForEach(weatherSymbols(hour).dropFirst().prefix(2), id: \.self) { symbol in
                            Image(systemName: symbol)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: 11)
                } else if let agreement, agreement.percentage > 0 {
                    HStack(spacing: 0) {
                        Text("\(agreement.percentage)%")
                        if !showsPrecipitationInWeatherRow {
                            Image(systemName: precipitationSymbol(hour))
                        }
                    }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.cyan.opacity(agreement.isLow ? 0.7 : 1))
                        .accessibilityLabel(agreement.accessibilityLabel)
                        .frame(height: 11)
                } else {
                    Color.clear.frame(height: 11)
                }
            }
            .frame(width: columnWidth, height: height)
            .background {
                if theme.usesMaterial && !isSelected {
                    Rectangle().fill(.thinMaterial)
                } else {
                    isSelected ? accentColor.opacity(0.22) : Color.secondary.opacity(colorScheme == .dark ? 0.20 : 0.12)
                }
            }
            .ventusGlassEffect(theme: theme, in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                if daylightSymbol(hour) == nil {
                    Rectangle().fill(daylightOverlay(hour))
                }
            }
            .overlay {
                if isSelected {
                    ForecastGridHeaderSelectionBorder(cornerRadius: 3)
                        .stroke(accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
#if os(tvOS)
        .focused(focusedHour, equals: hour)
#endif
        .foregroundStyle(accentColor)
        .accessibilityLabel("\(day(hour)), \(time(hour))\(daylightSymbol(hour).map { ", \(eventAccessibilityName($0))" } ?? "")\(precipitationAgreement(hour).map { ", \($0.accessibilityLabel)" } ?? ""), \(weatherSymbols(hour).count) weather symbol\(weatherSymbols(hour).count == 1 ? "" : "s")")
        .accessibilityHint(isSelected ? "Selected forecast hour" : "Select forecast hour")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accentColor: Color { theme.accentColor(for: colorScheme) }

    private var dayFont: Font {
#if os(tvOS)
        .caption2
#else
        .caption2
#endif
    }

    private var timeFont: Font {
#if os(tvOS)
        .caption.bold()
#else
        .caption.bold()
#endif
    }

    private func hasPrecipitation(_ hour: String) -> Bool {
        weatherSymbols(hour).contains { $0.contains("snow") || $0.contains("rain") || $0.contains("drizzle") }
    }

    private func eventAccessibilityName(_ symbolName: String) -> String {
        switch symbolName {
        case "sunrise.fill": "sunrise"
        case "sunset.fill": "sunset"
        case "moonrise.fill": "moonrise"
        case "moonset.fill": "moonset"
        default: symbolName.hasPrefix("moonphase.") ? "moon phase" : symbolName
        }
    }
}

struct ForecastGridHeaderSelectionBorder: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

struct ForecastGridDataSelectionBorder: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#if DEBUG
#Preview("Forecast grid hour header") {
    ScrollView(.horizontal) {
        ForecastGridHourHeader(
            hours: ["0", "1", "2", "3"],
            columnWidth: 56,
            columnSpacing: 0,
            height: 64,
            day: { _ in "Sat 1" },
            time: { hour in "\(hour)h" },
            weatherSymbols: { _ in ["cloud.sun.fill", "wind"] },
            daylightSymbol: { hour in hour == "1" ? "sunrise.fill" : nil },
            precipitationAgreement: { hour in
                hour == "2" ? ForecastPrecipitationAgreement(rainyModelCount: 1, modelCount: 4) : nil
            },
            precipitationSymbol: { _ in "cloud.rain.fill" },
            daylightOverlay: { _ in .clear },
            selectedHour: "1",
            onSelectHour: { _ in }
        )
    }
    .padding()
}
#endif
#endif
