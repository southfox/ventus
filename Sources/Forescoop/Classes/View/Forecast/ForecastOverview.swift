//
//  ForecastOverview.swift
//  ForescoopPackage
//
//  Created by Javier on 30/07/2026.
//  

#if !os(watchOS)
import SwiftUI

public struct ForecastOverview: View {
    @Environment(\.ventusTheme) private var theme
    public let forecast: SpotForecast
    public let selectedHour: String?
    public let coordinateLocationName: String?
    public let modelForecasts: [SpotForecast]
    public let modelNamesByID: [String: String]
    public let isModelComparisonEnabled: Bool
    public let showsLocationHeader: Bool
    public let showsModelSummary: Bool
    @Binding public var temperatureUnit: TemperatureUnit
    @State private var showsTemperatureSources = false
    private let onSelectLocation: () -> Void
    private let onSelectModel: () -> Void
    private let onShowMap: () -> Void
    private let modelInfoURL: URL

    public init(
        forecast: SpotForecast,
        selectedHour: String?,
        temperatureUnit: Binding<TemperatureUnit>,
        coordinateLocationName: String? = nil,
        modelForecasts: [SpotForecast] = [],
        modelNamesByID: [String: String] = [:],
        isModelComparisonEnabled: Bool = false,
        showsLocationHeader: Bool = true,
        showsModelSummary: Bool = true,
        modelInfoURL: URL = URL(string: "https://www.windguru.cz/help.php?sec=models")!,
        onSelectLocation: @escaping () -> Void,
        onSelectModel: @escaping () -> Void,
        onShowMap: @escaping () -> Void = {}
    ) {
        self.forecast = forecast
        self.selectedHour = selectedHour
        self.coordinateLocationName = coordinateLocationName
        self.modelForecasts = modelForecasts
        self.modelNamesByID = modelNamesByID
        self.isModelComparisonEnabled = isModelComparisonEnabled
        self.showsLocationHeader = showsLocationHeader
        self.showsModelSummary = showsModelSummary
        _temperatureUnit = temperatureUnit
        self.modelInfoURL = modelInfoURL
        self.onSelectLocation = onSelectLocation
        self.onSelectModel = onSelectModel
        self.onShowMap = onShowMap
    }

    public var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                if showsLocationHeader {
                    ForecastLocationHeader(
                        locationName: locationName,
                        onSelectLocation: onSelectLocation,
                        onShowMap: onShowMap
                    )

                    if forecast.isCoordinateLocation {
                        Text(forecast.coordinateSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if showsModelSummary {
                    ForecastModelSummary(
                        title: forecast.forecast?.modelName ?? "Forecast model",
                        modelInfoURL: modelInfoURL,
                        onSelect: onSelectModel
                    )
                }

                Text(forecast.forecast?.cadenceDescription ?? "Forecast cadence unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(forecast.weatherSymbolNames(hour: selectedHour), id: \.self) { symbol in
                    Image(systemName: symbol)
                }
            }
            .font(.system(size: 42))
            .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ForecastUnitSelector(
                        "Temperature unit",
                        selection: $temperatureUnit,
                        unitTitle: \.label
                    ) {
                        ThermalLabel(temperature, celsius: currentCelsius)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(theme.accentColor)
                    }
                    .accessibilityLabel("Temperature")

                    if supportsModelComparison {
                        Button("Compare temperature", systemImage: showsTemperatureSources ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                            showsTemperatureSources.toggle()
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(theme.accentColor)
                    }
                }

                if let realTemperature {
                    Label(realTemperature, systemImage: "thermometer.variable.and.figure")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(theme.accentColor)
                        .accessibilityLabel("Real temperature")
                }

                if let range = forecast.dailyTemperatureRange(hour: selectedHour), let highTemperatureText, let lowTemperatureText {
                    HStack(spacing: 12) {
                        ThermalLabel(lowTemperatureText, celsius: range.low)
                        ThermalLabel(highTemperatureText, celsius: range.high)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if showsTemperatureSources {
                    ForEach(Array(modelForecasts.enumerated()), id: \.offset) { _, source in
                        HStack {
                            Label(modelName(for: source), systemImage: "cpu")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(temperature(for: source)).monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    /// TMP only — deliberately not falling back to TMPE, so this headline
    /// stays visually distinct from the "Real temperature" line below it
    /// whenever the model actually reports both (matches the grid).
    private var currentCelsius: Double {
        let hour = selectedHour ?? forecast.currentForecastHour
        return forecast.forecast?.temperature(hh: hour) ?? forecast.forecast?.temperatureReal(hh: hour) ?? 0
    }

    private var temperature: String {
        temperature(for: forecast)
    }

    private func temperature(for source: SpotForecast) -> String {
        let hour = selectedHour ?? source.currentForecastHour
        guard let value = source.forecast?.temperature(hh: hour) ?? source.forecast?.temperatureReal(hh: hour) else { return "—" }
        return "\(Temperature(celsius: value).value(in: temperatureUnit).forecastFormatted(precision: 0))\(temperatureUnit.label)"
    }

    private var realTemperature: String? {
        let hour = selectedHour ?? forecast.currentForecastHour
        guard let value = forecast.forecast?.temperatureReal(hh: hour) else { return nil }
        return "\(Temperature(celsius: value).value(in: temperatureUnit).forecastFormatted(precision: 0))\(temperatureUnit.label)"
    }

    private var highTemperatureText: String? {
        guard let range = forecast.dailyTemperatureRange(hour: selectedHour) else { return nil }
        return "\(Temperature(celsius: range.high).value(in: temperatureUnit).forecastFormatted(precision: 0))\(temperatureUnit.label)"
    }

    private var lowTemperatureText: String? {
        guard let range = forecast.dailyTemperatureRange(hour: selectedHour) else { return nil }
        return "\(Temperature(celsius: range.low).value(in: temperatureUnit).forecastFormatted(precision: 0))\(temperatureUnit.label)"
    }

    private var supportsModelComparison: Bool { isModelComparisonEnabled && modelForecasts.count > 1 }

    private func modelName(for source: SpotForecast) -> String {
        guard let identifier = source.model else { return source.forecast?.modelName ?? "Forecast model" }
        return modelNamesByID[identifier] ?? source.forecast?.modelName ?? "Model \(identifier)"
    }

    private var locationName: String {
        forecast.locationDisplayName(coordinateLocationName: coordinateLocationName)
    }
}

#Preview("Forecast overview") {
    if let forecast = ForecastWindguruMockup().dashboardPreviewForecast {
        ForecastOverview(
            forecast: forecast,
            selectedHour: "29",
            temperatureUnit: .constant(.celsius),
            onSelectLocation: {},
            onSelectModel: {},
            onShowMap: {}
        )
        .padding()
    } else {
        ContentUnavailableView("Preview forecast unavailable", systemImage: "exclamationmark.triangle")
    }
}

#endif
