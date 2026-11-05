//
//  ForecastCacheStore.swift
//  VentusPackage
//

import Foundation
import SwiftData

/// The full last-successful forecast, kept separately from the lightweight
/// widget snapshot. This is what lets the app restore the selected layout
/// immediately while a fresh request is in flight.
@Model final class ForecastCacheRecord {
    @Attribute(.unique) var key: String
    @Attribute(.externalStorage) var payload: Data
    var coordinateLocationName: String?
    var savedAt: Date

    init(key: String = "current", payload: Data, coordinateLocationName: String?) {
        self.key = key
        self.payload = payload
        self.coordinateLocationName = coordinateLocationName
        savedAt = .now
    }
}

struct CachedForecast: Sendable {
    let forecast: SpotForecast
    let coordinateLocationName: String?
    let savedAt: Date
}

protocol ForecastCacheStoring: Sendable {
    func save(_ forecast: SpotForecast, coordinateLocationName: String?)
    func load() -> CachedForecast?
}

final class ForecastCacheStore: ForecastCacheStoring, @unchecked Sendable {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func save(_ forecast: SpotForecast, coordinateLocationName: String?) {
        guard let payload = ForecastCacheCodec.encode(forecast) else { return }
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<ForecastCacheRecord>()))?
            .first(where: { $0.key == "current" }) {
            record.payload = payload
            record.coordinateLocationName = coordinateLocationName
            record.savedAt = .now
        } else {
            context.insert(ForecastCacheRecord(payload: payload, coordinateLocationName: coordinateLocationName))
        }
        try? context.save()
    }

    func load() -> CachedForecast? {
        let context = ModelContext(container)
        guard let record = (try? context.fetch(FetchDescriptor<ForecastCacheRecord>()))?
            .first(where: { $0.key == "current" }),
              let forecast = ForecastCacheCodec.decode(record.payload) else {
            return nil
        }
        return CachedForecast(
            forecast: forecast,
            coordinateLocationName: record.coordinateLocationName,
            savedAt: record.savedAt
        )
    }
}

private enum ForecastCacheCodec {
    static func encode(_ forecast: SpotForecast) -> Data? {
        let encodedModels = forecast.forecasts.reduce(into: [String: Any]()) { models, model in
            guard let identifier = model.model, let info = model.info else { return }
            models[identifier] = forecastPayload(info)
        }
        guard !encodedModels.isEmpty,
              let spotID = forecast.id_spot,
              let spotName = forecast.spotname,
              let country = forecast.country else {
            return nil
        }

        var payload: [String: Any] = [
            "id_spot": spotID,
            "spotname": spotName,
            "country": country,
            "id_country": forecast.id_country,
            "lat": forecast.latitude,
            "lon": forecast.longitude,
            "alt": forecast.altitude,
            "gmt_hour_offset": forecast.gmt_hour_offset,
            "models": forecast.models,
            "forecast": encodedModels
        ]
        if let nickname = forecast.nickname { payload["nickname"] = nickname }
        if let timezone = forecast.tz { payload["tz"] = timezone }
        if let sunrise = forecast.sunrise { payload["sunrise"] = sunrise }
        if let sunset = forecast.sunset { payload["sunset"] = sunset }
        if let tides = forecast.tides { payload["tides"] = tides }

        guard JSONSerialization.isValidJSONObject(payload) else { return nil }
        return try? JSONSerialization.data(withJSONObject: payload, options: [])
    }

    static func decode(_ data: Data) -> SpotForecast? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return try? SpotForecast(map: payload)
    }

    private static func forecastPayload(_ forecast: Forecast) -> [String: Any] {
        var payload: [String: Any] = ["initstamp": forecast.initStamp]
        if let initdate = forecast.initdate { payload["initdate"] = initdate }
        if let modelName = forecast.model_name { payload["model_name"] = modelName }
        for (weather, values) in forecast.weathers ?? [:] {
            payload[weather] = values.info
        }
        return payload
    }
}
