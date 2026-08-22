#if os(tvOS)
import SwiftUI

struct TVForecastWidgetCard: View {
    let forecast: SpotForecast
    let hour: String?
    var coordinateLocationName: String? = nil

    private var weather: Forecast? { forecast.forecast }

    var body: some View {
        HStack(spacing: 28) {
            Image(systemName: forecast.weatherSymbolName(hour: hour))
                .font(.system(size: 56, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 8) {
                Text(forecast.locationDisplayName(coordinateLocationName: coordinateLocationName))
                    .font(.title2.weight(.semibold))
                HStack(spacing: 24) {
                    metric("Temperature", value: temperature, symbol: "thermometer.medium", celsius: temperatureCelsius)
                    metric("Wind", value: wind, symbol: "wind")
                    metric("Rain", value: rain, symbol: "drop.fill")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .focusable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(forecast.locationDisplayName(coordinateLocationName: coordinateLocationName)). Temperature \(temperature). Wind \(wind). Rain \(rain).")
        .accessibilityHint("Current selected forecast hour")
        .accessibilityIdentifier("tv.forecast.card")
    }

    private var temperatureCelsius: Double {
        weather?.temperatureReal(hh: hour) ?? weather?.temperature(hh: hour) ?? 0
    }

    private var temperature: String {
        "\(Int(temperatureCelsius.rounded()))°C"
    }

    private var wind: String {
        "\(Int((weather?.windSpeed(hh: hour) ?? 0).rounded())) kt"
    }

    private var rain: String {
        let value = weather?.precipitation1(hh: hour) ?? weather?.precipitation(hh: hour) ?? 0
        return "\(value.formatted(.number.precision(.fractionLength(0)))) mm"
    }

    private func metric(_ title: LocalizedStringKey, value: String, symbol: String, celsius: Double? = nil) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            if let celsius {
                let palette = TemperatureColorScale.palette(forCelsius: celsius)
                Image(systemName: symbol)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(palette.primary, palette.secondary)
            } else {
                Image(systemName: symbol).foregroundStyle(.tint)
            }
        }
    }
}
#endif
