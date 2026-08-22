#if canImport(CoreSpotlight) && !os(tvOS) && !os(watchOS)
import CoreSpotlight

public enum VentusSpotlightIndexer {
    private static let domain = "org.forescoop.forecast"

    public static func index(forecast: SpotForecast, savedLocations: [SavedMapLocation]) {
        var items = [forecastItem(forecast)]
        items.append(contentsOf: savedLocations.map(locationItem))

        CSSearchableIndex.default().indexSearchableItems(items) { _ in
        }
    }

    private static func forecastItem(_ forecast: SpotForecast) -> CSSearchableItem {
        let hour = forecast.currentForecastHour
        let weather = forecast.forecast
        let temperature = weather?.temperatureReal(hh: hour) ?? weather?.temperature(hh: hour)
        let wind = weather?.windSpeed(hh: hour)
        let attributes = CSSearchableItemAttributeSet(itemContentType: "public.text")
        let location = forecast.locationDisplayName()
        attributes.title = "Forecast · \(location)"
        attributes.contentDescription = [
            temperature.map { "\(Int($0.rounded()))°C" },
            wind.map { "\(Int($0.rounded())) kt wind" }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
        attributes.keywords = ["forecast", "weather", "wind", location]
        attributes.contentCreationDate = .now
        return CSSearchableItem(
            uniqueIdentifier: "\(domain).current.\(forecast.identifier ?? "default")",
            domainIdentifier: domain,
            attributeSet: attributes
        )
    }

    private static func locationItem(_ location: SavedMapLocation) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(itemContentType: "public.place")
        attributes.title = "Forecast · \(location.displayName)"
        attributes.contentDescription = location.detailText
        attributes.keywords = ["forecast", "weather", "wind", location.name, location.displayName]
        attributes.latitude = location.latitude as NSNumber
        attributes.longitude = location.longitude as NSNumber
        return CSSearchableItem(
            uniqueIdentifier: "\(domain).location.\(location.id.uuidString)",
            domainIdentifier: domain,
            attributeSet: attributes
        )
    }
}
#else
public enum VentusSpotlightIndexer {
    public static func index(forecast: SpotForecast, savedLocations: [SavedMapLocation]) {}
}
#endif
