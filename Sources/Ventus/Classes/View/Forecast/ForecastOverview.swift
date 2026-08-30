//
//  ForecastOverview.swift
//  VentusPackage
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
    public let isCompact: Bool
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
        isCompact: Bool = false,
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
        self.isCompact = isCompact
        _temperatureUnit = temperatureUnit
        self.modelInfoURL = modelInfoURL
        self.onSelectLocation = onSelectLocation
        self.onSelectModel = onSelectModel
        self.onShowMap = onShowMap
    }

    public var body: some View {
        VStack(spacing: isCompact ? 6 : 16) {
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

            Image(systemName: forecast.weatherSymbolName(hour: selectedHour))
            .font(.system(size: isCompact ? 20 : 42))
            .symbolRenderingMode(.hierarchical)

            if let precipitationAgreement {
                Label("\(precipitationAgreement.percentage)%", systemImage: "cloud.rain.fill")
                    .font(isCompact ? .caption2.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.cyan.opacity(precipitationAgreement.isLow ? 0.7 : 1))
                    .accessibilityLabel(precipitationAgreement.accessibilityLabel)
            }

            VStack(spacing: isCompact ? 2 : 8) {
                HStack(spacing: isCompact ? 6 : 12) {
                    ForecastUnitSelector(
                        "Temperature unit",
                        selection: $temperatureUnit,
                        unitTitle: \.label
                    ) {
                        HStack(spacing: isCompact ? 3 : 6) {
                            ThermalLabel(temperature, celsius: currentCelsius)
                            Text(temperatureUnit.label)
                        }
                        .font(.system(size: isCompact ? 22 : 44, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                    }
                    .accessibilityLabel("Temperature")

                    if let range = dailyTemperatureRange {
                        dailyTemperatureLabels(range)
                    }

                    if supportsModelComparison {
                        Button("Compare temperature", systemImage: showsTemperatureSources ? "rectangle.compress.vertical" : "rectangle.expand.vertical") {
                            showsTemperatureSources.toggle()
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(theme.accentColor)
                    }
                }

                if let realTemperature {
                    RealTemperatureLabel(realTemperature, celsius: realTemperatureCelsius)
                        .font(isCompact ? .caption.weight(.medium) : .title3.weight(.medium))
                        .foregroundStyle(theme.accentColor)
                        .accessibilityLabel("Real temperature")
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

    private var currentCelsius: Double {
        let hour = selectedHour ?? forecast.currentForecastHour
        return forecast.forecast?.temperature(hh: hour) ?? forecast.forecast?.temperatureReal(hh: hour) ?? 0
    }

    private var precipitationAgreement: ForecastPrecipitationAgreement? {
        modelForecasts.precipitationAgreement(hour: selectedHour ?? forecast.currentForecastHour)
    }

    private var temperature: String {
        temperatureValue(for: forecast)
    }

    private func temperature(for source: SpotForecast) -> String {
        "\(temperatureValue(for: source))\(temperatureUnit.label)"
    }

    private func temperatureValue(for source: SpotForecast) -> String {
        let hour = selectedHour ?? source.currentForecastHour
        guard let value = source.forecast?.temperature(hh: hour) ?? source.forecast?.temperatureReal(hh: hour) else { return "—" }
        return Temperature(celsius: value).value(in: temperatureUnit).forecastFormatted(precision: 0)
    }

    private var realTemperature: String? {
        let hour = selectedHour ?? forecast.currentForecastHour
        guard let value = forecast.forecast?.temperatureReal(hh: hour) else { return nil }
        return Temperature(celsius: value).value(in: temperatureUnit).forecastFormatted(precision: 0)
    }

    private var realTemperatureCelsius: Double {
        let hour = selectedHour ?? forecast.currentForecastHour
        return forecast.forecast?.temperatureReal(hh: hour) ?? 0
    }

    private var dailyTemperatureRange: (low: Double, high: Double)? {
        forecast.dailyTemperatureRange(hour: selectedHour)
    }

    @ViewBuilder
    private func dailyTemperatureLabels(_ dayRange: (low: Double, high: Double)) -> some View {
        HStack(spacing: 4) {
            Label(
                Temperature(celsius: dayRange.low).value(in: temperatureUnit).forecastFormatted(precision: 0),
                systemImage: "thermometer.low"
            )
            Label(
                Temperature(celsius: dayRange.high).value(in: temperatureUnit).forecastFormatted(precision: 0),
                systemImage: "thermometer.high"
            )
        }
        .font(isCompact ? .caption2 : .subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily low \(dayRange.low.forecastFormatted(precision: 0)), high \(dayRange.high.forecastFormatted(precision: 0)).")
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
