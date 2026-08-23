//
//  ForecastWindDetails.swift
//  VentusPackage
//
//  Created by Javier on 30/07/2026.
//

#if !os(watchOS)
import SwiftUI

public struct ForecastWindDetails: View {
    @Environment(\.ventusTheme) private var theme
    public let forecast: SpotForecast
    public let selectedHour: String?
    @Binding public var windSpeedUnit: WindSpeedUnit
    @Binding public var windDirectionDisplayMode: WindDirectionDisplayMode
    @Binding public var temperatureUnit: TemperatureUnit
    public let modelForecasts: [SpotForecast]
    public let modelNamesByID: [String: String]
    public let isModelComparisonEnabled: Bool

    public init(
        forecast: SpotForecast,
        selectedHour: String?,
        windSpeedUnit: Binding<WindSpeedUnit>,
        windDirectionDisplayMode: Binding<WindDirectionDisplayMode>,
        temperatureUnit: Binding<TemperatureUnit>,
        modelForecasts: [SpotForecast] = [],
        modelNamesByID: [String: String] = [:],
        isModelComparisonEnabled: Bool = false
    ) {
        self.forecast = forecast
        self.selectedHour = selectedHour
        _windSpeedUnit = windSpeedUnit
        _windDirectionDisplayMode = windDirectionDisplayMode
        _temperatureUnit = temperatureUnit
        self.modelForecasts = modelForecasts
        self.modelNamesByID = modelNamesByID
        self.isModelComparisonEnabled = isModelComparisonEnabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForecastUnitSelector(
                "Wind speed unit",
                selection: $windSpeedUnit,
                unitTitle: \.label
            ) {
                LabeledContent { Text(windSpeed(weather?.windSpeed(hh: hour))) } label: {
                    Label("Wind speed", systemImage: "wind")
                        .foregroundStyle(theme.accentColor)
                }
            }
            .accessibilityLabel("Wind speed")
            ForecastModelSourceRows(forecasts: modelForecasts, modelNamesByID: modelNamesByID, isEnabled: isModelComparisonEnabled) {
                windSpeed($0.forecast?.windSpeed(hh: hour))
            }

            ForecastUnitSelector(
                "Wind speed unit",
                selection: $windSpeedUnit,
                unitTitle: \.label
            ) {
                LabeledContent { Text(windSpeed(weather?.windGustsKnots(hh: hour))) } label: {
                    Label("Wind gusts", systemImage: "wind.circle.fill")
                        .foregroundStyle(theme.accentColor)
                }
            }
            .accessibilityLabel("Wind gusts")
            ForecastModelSourceRows(forecasts: modelForecasts, modelNamesByID: modelNamesByID, isEnabled: isModelComparisonEnabled) {
                windSpeed($0.forecast?.windGustsKnots(hh: hour))
            }

            LabeledContent {
                if let direction = weather?.windDirection(hh: hour) {
                    Button {
                        windDirectionDisplayMode = windDirectionDisplayMode.next
                    } label: {
                        windDirectionView(direction)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("—")
                }
            } label: {
                Label("Wind direction", systemImage: "location.north.line")
            }
            ForecastModelSourceRows(forecasts: modelForecasts, modelNamesByID: modelNamesByID, isEnabled: isModelComparisonEnabled) {
                $0.forecast?.windDirection(hh: hour).map(windDirectionText) ?? "—"
            }

            if let windChill = weather?.windChill(hh: hour) {
                ForecastUnitSelector(
                    "Temperature unit",
                    selection: $temperatureUnit,
                    unitTitle: \.label
                ) {
                    LabeledContent { Text(windChillText(windChill)) } label: {
                        Label("Wind chill", systemImage: "thermometer.snowflake")
                            .foregroundStyle(theme.accentColor)
                    }
                }
                .accessibilityLabel("Wind chill")
                ForecastModelSourceRows(forecasts: modelForecasts, modelNamesByID: modelNamesByID, isEnabled: isModelComparisonEnabled) {
                    $0.forecast?.windChill(hh: hour).map(windChillText) ?? "—"
                }
            }
        }
        .font(.body)
        .labelStyle(ForecastDetailLabelStyle())
    }

    private var hour: String? { selectedHour ?? forecast.currentForecastHour }
    private var weather: Forecast? { forecast.forecast }

    private func windSpeed(_ knots: Double?) -> String {
        guard let knots, let value = Knots(knots).value(in: windSpeedUnit) else { return "—" }
        return "\(value.forecastFormatted(precision: windSpeedUnit.displayPrecision)) \(windSpeedUnit.label)"
    }

    @ViewBuilder private func windDirectionView(_ direction: Double) -> some View {
        switch windDirectionDisplayMode {
        case .arrow:
            Image(systemName: "arrow.down")
                .rotationEffect(.degrees(direction))
        case .degrees:
            Text(windDirectionText(direction))
        }
    }

    private func windDirectionText(_ direction: Double) -> String {
        "\(Int(direction.rounded()))°"
    }

    private func windChillText(_ celsius: Double) -> String {
        "\(Temperature(celsius: celsius).value(in: temperatureUnit).forecastFormatted(precision: 0))\(temperatureUnit.label)"
    }
}

#Preview("Wind details") {
    if let forecast = ForecastWindguruMockup().dashboardPreviewForecast {
        ForecastWindDetails(
            forecast: forecast,
            selectedHour: "29",
            windSpeedUnit: .constant(.knots),
            windDirectionDisplayMode: .constant(.arrow),
            temperatureUnit: .constant(.celsius)
        )
        .padding()
    } else {
        ContentUnavailableView("Preview forecast unavailable", systemImage: "exclamationmark.triangle")
    }
}

#endif
