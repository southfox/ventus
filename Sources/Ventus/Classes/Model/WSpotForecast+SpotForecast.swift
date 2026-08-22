//
//  WSpotForecast+SpotForecast.swift
//  Ventus
//
//  Created by Javier Fuchs on 07/23/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation

public extension SpotForecast {
    static func from(coordinateForecast spot: WSpotForecast) throws -> SpotForecast? {
        guard let forecast = spot.forecast else { return nil }
        let hours = forecast.hours.isEmpty ? Array(forecast.WINDSPD.indices) : forecast.hours
        func values<T>(_ values: [T]) -> [String: Any] {
            Dictionary(uniqueKeysWithValues: zip(hours, values).map { (String($0.0), $0.1) })
        }
        func values<T>(_ values: [T?]) -> [String: Any] {
            Dictionary(uniqueKeysWithValues: zip(hours, values).compactMap { hour, value in
                value.map { (String(hour), $0) }
            })
        }
        func nullableValues<T>(_ values: [T?]) -> [String: Any] {
            Dictionary(uniqueKeysWithValues: zip(hours, values).compactMap { hour, value in
                guard let value else { return nil }
                return (String(hour), value)
            })
        }
        var model: [String: Any] = [
            "initstamp": forecast.initstamp,
            "initdate": forecast.initDate ?? "",
            "model_name": forecast.model_name ?? spot.model ?? "Windguru PRO",
            "WINDSPD": values(forecast.WINDSPD),
            "GUST": values(forecast.GUST),
            "WINDDIR": values(forecast.windDirection.map { Double($0.value) }),
            "WINDIRNAME": values(forecast.windDirection.map(\.description)),
            "TMP": values(forecast.TMP),
            "TMPE": values(forecast.TMPE),
            "RH": values(forecast.RH),
            "SLP": nullableValues(forecast.SLP),
            "FLHGT": values(forecast.FLHGT.map(Double.init)),
            "APCP": values(forecast.APCP),
            "APCP1": values(forecast.APCP1),
            "HTSGW": values(forecast.HTSGW),
            "WVHGT": values(forecast.WVHGT),
            "WVPER": values(forecast.WVPER),
            "WVDIR": values(forecast.WVDIR),
            "PERPW": values(forecast.PERPW),
            "DIRPW": values(forecast.DIRPW)
        ]
        model["TCDC"] = values(forecast.TCDC)
        model["HCDC"] = values(forecast.HCDC)
        model["MCDC"] = values(forecast.MCDC)
        model["LCDC"] = values(forecast.LCDC)
        return try SpotForecast(map: [
            "id_spot": spot.identifier,
            "spotname": spot.spotname ?? "Map location",
            "country": "Custom location",
            "lat": spot.lat,
            "lon": spot.lon,
            "alt": spot.alt,
            "tz": spot.tzid as Any,
            "gmt_hour_offset": spot.utc_offset,
            "sunrise": spot.sunrise as Any,
            "sunset": spot.sunset as Any,
            "models": [spot.id_model],
            "forecast": [String(spot.id_model): model]
        ])
    }
}
