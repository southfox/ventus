//
//  ForecastGraphCanvas.swift
//  VentusGraph package
//
//  Created by Javier on 08/02/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public struct ForecastGraphCanvas: View {
    public let points: [ForecastGraphPoint]
    public let comparisonSeries: [ForecastGraphSeries]
    @Binding public var selectedID: String?
    public let windUnitLabel: String

    public init(points: [ForecastGraphPoint], comparisonSeries: [ForecastGraphSeries] = [], selectedID: Binding<String?>, windUnitLabel: String) {
        self.points = points; self.comparisonSeries = comparisonSeries; _selectedID = selectedID; self.windUnitLabel = windUnitLabel
    }

    private var width: CGFloat { max(720, CGFloat(points.count) * 62) }
    private var pressureRange: ClosedRange<Double> {
        let values = points.map(\.pressure).filter { $0 > 0 }
        guard let low = values.min(), let high = values.max(), low != high else { return 0...1 }
        return low...high
    }
    private var hasWaveData: Bool {
        points.contains { $0.wave != nil } || comparisonSeries.contains { $0.points.contains { $0.wave != nil } }
    }
    private var canvasHeight: CGFloat { hasWaveData ? 630 : 520 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legend
            if !comparisonSeries.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(comparisonSeries.enumerated()), id: \.element.id) { index, series in
                        ForecastGraphLegendItem(label: Text(series.name), color: comparisonColor(for: index), style: .line)
                    }
                }
                .font(.caption2)
            }
            ScrollView(.horizontal) {
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    draw(in: &context, size: size)
                }
                .frame(width: width, height: canvasHeight)
                .contentShape(Rectangle())
#if !os(tvOS)
                .simultaneousGesture(SpatialTapGesture().onEnded { value in
                    let progress = min(max((value.location.x - 42) / (width - 58), 0), 1)
                    let tappedID = points[Int((progress * CGFloat(points.count - 1)).rounded())].id
                    selectedID = realID(for: tappedID)
                })
#endif
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityLabel(hasWaveData
            ? "Wind, gust, cloud cover, humidity, pressure, temperature, precipitation and wave forecast graph"
            : "Wind, gust, cloud cover, humidity, pressure, temperature and precipitation forecast graph")
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 122), alignment: .leading)],
            alignment: .leading,
            spacing: 7
        ) {
            ForecastGraphLegendItem(label: Text("Wind"), color: .primary, style: .line)
            ForecastGraphLegendItem(label: Text("Gusts · low → strong"), style: .gustGradient)
            ForecastGraphLegendItem(label: Text("Cloud cover"), color: .gray.opacity(0.55), style: .area)
            ForecastGraphLegendItem(label: Text("Humidity"), color: .green, style: .line)
            ForecastGraphLegendItem(label: Text("Pressure"), color: .blue, style: .line)
            ForecastGraphLegendItem(label: Text("Temperature"), color: .yellow, style: .dot)
            ForecastGraphLegendItem(label: Text("Rain"), color: .cyan, style: .bar)
            ForecastGraphLegendItem(label: Text("Wind direction"), color: .primary, style: .arrow)
            if hasWaveData {
                ForecastGraphLegendItem(label: Text("Wave"), color: .indigo, style: .area)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func axisLabel(for date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.abbreviated))
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("j")
        let timeString = formatter.string(from: date)
        let hourText = formatter.dateFormat.contains("a") ? timeString : "\(timeString)h"
        return "\(weekday), \(hourText)"
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let wind = CGRect(x: 42, y: 28, width: size.width - 58, height: 240)
        let weather = CGRect(x: 42, y: 334, width: wind.width, height: 165)
        let wave = hasWaveData ? CGRect(x: 42, y: weather.maxY + 24, width: wind.width, height: 90) : nil
        let bottomY = wave?.maxY ?? weather.maxY
        let x: (Int) -> CGFloat = { wind.minX + CGFloat($0) / CGFloat(max(points.count - 1, 1)) * wind.width }
        let maxGust = max((points.map(\.gust) + comparisonSeries.flatMap { $0.points.map(\.gust) }).max() ?? 1, 1)
        let windY: (Double) -> CGFloat = { wind.maxY - CGFloat($0 / maxGust) * wind.height }
        let weatherY: (Double) -> CGFloat = { weather.maxY - CGFloat(min(max($0, 0), 100) / 100) * weather.height }

        for index in points.indices {
            guard index.isMultiple(of: 2) else { continue }
            var line = Path(); line.move(to: CGPoint(x: x(index), y: wind.minY)); line.addLine(to: CGPoint(x: x(index), y: bottomY))
            context.stroke(line, with: .color(.secondary.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            context.draw(Text(axisLabel(for: points[index].date)).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: x(index), y: 12))
        }

        for index in points.indices {
            guard let symbolName = sunSymbolName(for: points[index].id) else { continue }
            var marker = Path(); marker.move(to: CGPoint(x: x(index), y: wind.minY)); marker.addLine(to: CGPoint(x: x(index), y: bottomY))
            context.stroke(marker, with: .color(.orange.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            context.draw(
                Text(Image(systemName: symbolName)).font(.caption).foregroundStyle(.orange),
                at: CGPoint(x: x(index), y: wind.minY - 8)
            )
        }

        var gustArea = smoothPath(points.map(\.gust), x: x, y: windY)
        gustArea.addLine(to: CGPoint(x: x(points.count - 1), y: wind.maxY)); gustArea.closeSubpath()
        context.fill(gustArea, with: .linearGradient(Gradient(colors: [.cyan.opacity(0.2), .mint.opacity(0.55), .yellow.opacity(0.7), .orange.opacity(0.8), .pink.opacity(0.9)]), startPoint: CGPoint(x: 0, y: wind.maxY), endPoint: CGPoint(x: 0, y: wind.minY)))
        for (seriesIndex, series) in comparisonSeries.enumerated() {
            let valuesByID = Dictionary(uniqueKeysWithValues: series.points.map { ($0.id, $0.wind) })
            let values = points.map { valuesByID[$0.id] ?? $0.wind }
            drawLine(values, color: comparisonColor(for: seriesIndex), in: &context, x: x, y: windY)
        }
        drawLine(points.map(\.wind), color: .primary, in: &context, x: x, y: windY)

        for index in points.indices {
            let point = CGPoint(x: x(index), y: windY(points[index].wind))
            context.draw(Text(points[index].wind, format: .number.precision(.fractionLength(0))).font(.caption2.monospacedDigit()), at: CGPoint(x: point.x, y: point.y - 10))
            if let direction = points[index].direction {
                var arrow = context; arrow.translateBy(x: point.x, y: wind.maxY + 22); arrow.rotate(by: .degrees(direction))
                arrow.draw(Text("↓").font(.caption.weight(.bold)), at: .zero)
            }
        }

        var clouds = smoothPath(points.map(\.cloudCover), x: x, y: weatherY)
        clouds.addLine(to: CGPoint(x: x(points.count - 1), y: weather.maxY)); clouds.closeSubpath()
        context.fill(clouds, with: .color(.gray.opacity(0.4)))
        drawLine(points.map(\.humidity), color: .green, in: &context, x: x, y: weatherY)
        drawLine(points.map { pressureLevel($0.pressure) }, color: .blue, in: &context, x: x, y: weatherY)
        for index in points.indices {
            let point = points[index]
            let rainHeight = min(CGFloat(point.precipitation * 20), 28)
            context.fill(Path(CGRect(x: x(index) - 2, y: weather.maxY - rainHeight, width: 4, height: rainHeight)), with: .color(.cyan))
            let temperatureCenter = CGPoint(x: x(index), y: weather.maxY - 18)
            context.fill(Path(ellipseIn: CGRect(x: temperatureCenter.x - 10, y: temperatureCenter.y - 10, width: 20, height: 20)), with: .color(.yellow.opacity(0.9)))
            context.draw(Text(point.temperature, format: .number.precision(.fractionLength(0))).font(.caption2.weight(.bold)), at: temperatureCenter)
        }
        if let wave {
            let maxWave = max((points.compactMap(\.wave) + comparisonSeries.flatMap { $0.points.compactMap(\.wave) }).max() ?? 1, 1)
            let waveY: (Double) -> CGFloat = { wave.maxY - CGFloat($0 / maxWave) * wave.height }
            let waveValues = points.map { $0.wave ?? 0 }
            var waveArea = smoothPath(waveValues, x: x, y: waveY)
            waveArea.addLine(to: CGPoint(x: x(points.count - 1), y: wave.maxY)); waveArea.closeSubpath()
            context.fill(waveArea, with: .color(.indigo.opacity(0.25)))
            drawLine(waveValues, color: .indigo, in: &context, x: x, y: waveY)
            for index in points.indices where points[index].wave != nil {
                let point = CGPoint(x: x(index), y: waveY(points[index].wave ?? 0))
                context.draw(Text(points[index].wave ?? 0, format: .number.precision(.fractionLength(1))).font(.caption2.monospacedDigit()), at: CGPoint(x: point.x, y: point.y - 10))
            }
        }

        if let index = points.firstIndex(where: { $0.id == selectedID }) {
            var selection = Path(); selection.move(to: CGPoint(x: x(index), y: wind.minY)); selection.addLine(to: CGPoint(x: x(index), y: bottomY))
            context.stroke(selection, with: .color(.accentColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    private func drawLine(_ values: [Double], color: Color, in context: inout GraphicsContext, x: (Int) -> CGFloat, y: (Double) -> CGFloat) {
        context.stroke(smoothPath(values, x: x, y: y), with: .color(color), lineWidth: 2)
    }

    private func smoothPath(_ values: [Double], x: (Int) -> CGFloat, y: (Double) -> CGFloat) -> Path {
        guard !values.isEmpty else { return Path() }
        func point(_ index: Int) -> CGPoint { CGPoint(x: x(index), y: y(values[index])) }
        var path = Path()
        path.move(to: point(0))
        guard values.count > 1 else { return path }
        for index in 0..<(values.count - 1) {
            let previous = point(max(index - 1, 0))
            let start = point(index)
            let end = point(index + 1)
            let next = point(min(index + 2, values.count - 1))
            let control1 = CGPoint(x: start.x + (end.x - previous.x) / 6, y: start.y + (end.y - previous.y) / 6)
            let control2 = CGPoint(x: end.x - (next.x - start.x) / 6, y: end.y - (next.y - start.y) / 6)
            path.addCurve(to: end, control1: control1, control2: control2)
        }
        return path
    }

    private func pressureLevel(_ pressure: Double) -> Double {
        guard pressureRange.lowerBound != pressureRange.upperBound, pressure > 0 else { return 50 }
        return 22 + (pressure - pressureRange.lowerBound) / (pressureRange.upperBound - pressureRange.lowerBound) * 58
    }

    private func comparisonColor(for index: Int) -> Color {
        [.purple, .orange, .pink, .teal, .indigo][index % 5]
    }

    private func sunSymbolName(for id: String) -> String? {
        guard id.hasPrefix("sun:") else { return nil }
        let parts = id.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        return parts.count == 4 ? parts[1] : nil
    }

    private func realID(for id: String) -> String {
        guard id.hasPrefix("sun:") else { return id }
        let parts = id.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        return parts.count == 4 ? parts[2] : id
    }
}
