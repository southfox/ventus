//
//  ForecastGraphView.swift
//  Ventus package
//

#if !os(watchOS)
import VentusGraph
import SwiftUI

public struct ForecastGraphView: View {
    public let forecast: SpotForecast
    @Binding public var selectedHour: String?
    private let coordinateLocationName: String?
    @Binding private var windSpeedUnit: WindSpeedUnit
    @Binding private var waveHeightUnit: WaveHeightUnit
    private let modelForecasts: [SpotForecast]
    private let modelNamesByID: [String: String]
    @Binding private var isModelComparisonEnabled: Bool
    private let onSelectLocation: () -> Void
    private let onShowMap: () -> Void

    public init(
        forecast: SpotForecast,
        selectedHour: Binding<String?>,
        coordinateLocationName: String? = nil,
        windSpeedUnit: Binding<WindSpeedUnit>,
        waveHeightUnit: Binding<WaveHeightUnit> = .constant(.meters),
        modelForecasts: [SpotForecast] = [],
        modelNamesByID: [String: String] = [:],
        isModelComparisonEnabled: Binding<Bool> = .constant(false),
        onSelectLocation: @escaping () -> Void = {},
        onShowMap: @escaping () -> Void = {}
    ) {
        self.forecast = forecast
        _selectedHour = selectedHour
        self.coordinateLocationName = coordinateLocationName
        _windSpeedUnit = windSpeedUnit
        _waveHeightUnit = waveHeightUnit
        self.modelForecasts = modelForecasts
        self.modelNamesByID = modelNamesByID
        _isModelComparisonEnabled = isModelComparisonEnabled
        self.onSelectLocation = onSelectLocation
        self.onShowMap = onShowMap
    }

    private var locationName: String {
        forecast.locationDisplayName(coordinateLocationName: coordinateLocationName)
    }

    private var points: [ForecastGraphPoint] {
        points(for: forecast)
    }

    private func points(for source: SpotForecast) -> [ForecastGraphPoint] {
        let realPoints = source.availableForecastHours.compactMap { hour -> ForecastGraphPoint? in
            guard let offset = Int(hour) else { return nil }
                let date = source.forecastDate(hour: hour)
                    ?? Calendar.current.date(byAdding: .hour, value: offset, to: Calendar.current.startOfDay(for: .now))
                    ?? .now
                let windKnots = source.forecast?.windSpeed(hh: hour) ?? 0
                let gustKnots = source.forecast?.windGustsKnots(hh: hour) ?? windKnots
                let waveMeters = source.forecast?.waveHeight(hh: hour)
                let wave: Double? = waveMeters.map { WaveHeight(meters: $0).value(in: waveHeightUnit) }
                return ForecastGraphPoint(
                    id: hour,
                    date: date,
                    wind: Knots(windKnots).value(in: windSpeedUnit) ?? windKnots,
                    gust: Knots(gustKnots).value(in: windSpeedUnit) ?? gustKnots,
                    direction: source.forecast?.windDirection(hh: hour),
                    cloudCover: Double(source.forecast?.cloudCoverTotal(hh: hour) ?? 0),
                    humidity: Double(source.forecast?.relativeHumidity(hh: hour) ?? 0),
                    pressure: source.forecast?.seaLevelPressure(hh: hour) ?? 0,
                    temperature: source.forecast?.temperatureReal(hh: hour) ?? source.forecast?.temperature(hh: hour) ?? 0,
                    precipitation: source.forecast?.precipitation1(hh: hour) ?? source.forecast?.precipitation(hh: hour) ?? 0,
                    wave: wave
                )
            }
        let daylightPoints = source.insertingDaylightEvents(
            into: realPoints,
            date: { $0.date },
            make: { previous, next, eventDate, symbolName in
                ForecastGraphPoint(
                    id: "sun:\(symbolName):\(previous.id):\(next.id)",
                    date: eventDate,
                    wind: average(previous.wind, next.wind),
                    gust: average(previous.gust, next.gust),
                    direction: averageOptional(previous.direction, next.direction),
                    cloudCover: average(previous.cloudCover, next.cloudCover),
                    humidity: average(previous.humidity, next.humidity),
                    pressure: average(previous.pressure, next.pressure),
                    temperature: average(previous.temperature, next.temperature),
                    precipitation: average(previous.precipitation, next.precipitation),
                    wave: averageOptional(previous.wave, next.wave)
                )
            }
        )
        guard let firstDate = daylightPoints.first?.date, let lastDate = daylightPoints.last?.date else {
            return daylightPoints
        }

        let moonEvents = ForecastMoonCalendar.events(for: source, from: firstDate, until: lastDate.addingTimeInterval(1))
        let moonPoints = moonEvents.compactMap { event -> ForecastGraphPoint? in
            guard let nearest = daylightPoints.min(by: { abs($0.date.timeIntervalSince(event.date)) < abs($1.date.timeIntervalSince(event.date)) }) else { return nil }
            return ForecastGraphPoint(
                id: "moon:\(event.symbolName):\(nearest.id)",
                date: event.date,
                wind: nearest.wind,
                gust: nearest.gust,
                direction: nearest.direction,
                cloudCover: nearest.cloudCover,
                humidity: nearest.humidity,
                pressure: nearest.pressure,
                temperature: nearest.temperature,
                precipitation: nearest.precipitation,
                wave: nearest.wave
            )
        }
        return (daylightPoints + moonPoints).sorted { $0.date < $1.date }
    }

    private func average(_ a: Double, _ b: Double) -> Double { (a + b) / 2 }

    private func averageOptional(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (a?, b?): (a + b) / 2
        case let (a?, nil): a
        case let (nil, b?): b
        case (nil, nil): nil
        }
    }

    private var comparisonSeries: [ForecastGraphSeries] {
        guard isModelComparisonEnabled else { return [] }
        return modelForecasts.enumerated().compactMap { index, modelForecast in
            let modelID = modelForecast.model ?? "model-\(index)"
            return ForecastGraphSeries(
                id: modelID,
                name: modelNamesByID[modelID] ?? modelForecast.forecast?.model_name ?? modelID,
                points: points(for: modelForecast)
            )
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForecastLocationHeader(
                    locationName: locationName,
                    onSelectLocation: onSelectLocation,
                    onShowMap: onShowMap
                )
                if points.isEmpty {
                    ContentUnavailableView("Graph unavailable", systemImage: "chart.xyaxis.line")
                } else {
                    ForecastGraphCanvas(
                        points: points,
                        comparisonSeries: comparisonSeries,
                        selectedID: $selectedHour,
                        windUnitLabel: windSpeedUnit.label
                    )
                }
            }
            .frame(maxWidth: 1_300, alignment: .leading)
            .padding()
        }
        .forecastAccessibilityContainer(
            "Forecast graph for \(locationName)",
            hint: "Explore forecast metrics and select a point to change the active forecast hour.",
            identifier: "forecast.graph"
        )
    }
}

#if DEBUG
#Preview("Unavailable") {
    ForecastGraphView(
        forecast: .init(),
        selectedHour: .constant(nil),
        windSpeedUnit: .constant(.knots),
        modelForecasts: [],
        modelNamesByID: [:],
        isModelComparisonEnabled: .constant(false)
    )
}
#endif
#endif
