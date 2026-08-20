//
//  ForecastGraphView.swift
//  Forescoop package
//

#if !os(watchOS)
import ForescoopGraph
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
        source.availableForecastHours.compactMap { hour in
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
#endif

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
