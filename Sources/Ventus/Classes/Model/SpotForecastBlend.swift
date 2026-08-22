//
//  SpotForecastBlend.swift
//  Ventus
//
//  Created by Javier Fuchs on 07/22/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation

public extension SpotForecast {
    static func blended(_ forecasts: [SpotForecast]) throws -> SpotForecast? {
        guard let base = forecasts.first,
              forecasts.count > 1,
              forecasts.allSatisfy({ $0.forecast != nil }) else {
            return forecasts.first
        }

        let sources = forecasts.compactMap(\.forecast)
        let weights = sources.map(fineTuneWeight(for:))

        guard let baseInitStamp = base.forecast?.initStamp, baseInitStamp > 0 else {
            return forecasts.first
        }
        // sourceHourMaps[i]: canonical (base-relative) hour -> that source's own native hour key
        let sourceHourMaps: [[String: String]] = sources.map { source in
            guard source.initStamp > 0 else { return [:] }
            let initStampDelta = TimeInterval(source.initStamp - baseInitStamp)
            return source.availableHours.reduce(into: [String: String]()) { map, nativeHour in
                guard let offset = Int(nativeHour) else { return }
                let canonicalOffset = ((initStampDelta + TimeInterval(offset) * 3_600) / 3_600).rounded()
                map[String(Int(canonicalOffset))] = nativeHour
            }
        }

        let availableHours = Set(sourceHourMaps.flatMap(\.keys))
        guard !availableHours.isEmpty else { return base }

        let weatherKeys = Set(sources.flatMap { $0.weathers.map { Array($0.keys) } ?? [] })
        var blendedWeather = [String: [String: Any]]()
        for key in weatherKeys where key != TypeOfWeather.WINDIRNAME.rawValue {
            var valuesByHour = [String: Any]()
            var ceilingByHour = [String: Any]()
            for hour in availableHours {
                var values = [Double]()
                var weightedSum = 0.0
                var weightTotal = 0.0
                for (index, source) in sources.enumerated() {
                    guard let nativeHour = sourceHourMaps[index][hour],
                          let value = numericValue(source.weathers?[key]?.info[nativeHour]) else { continue }
                    values.append(value)
                    weightedSum += value * weights[index]
                    weightTotal += weights[index]
                }
                guard !values.isEmpty else { continue }
                let average: Double
                if circularDirectionWeatherKeys.contains(key) {
                    average = circularMean(values)
                } else if precipitationWeatherKeys.contains(key) {
                    average = median(values)
                    ceilingByHour[hour] = values.max() ?? average
                } else {
                    average = weightTotal > 0 ? weightedSum / weightTotal : values.reduce(0, +) / Double(values.count)
                }
                valuesByHour[hour] = integerWeatherKeys.contains(key)
                    ? Int(average.rounded())
                    : average
            }
            if !valuesByHour.isEmpty { blendedWeather[key] = valuesByHour }
            if !ceilingByHour.isEmpty { blendedWeather["\(key)_MAX"] = ceilingByHour }
        }

        if let directions = blendedWeather[TypeOfWeather.WINDDIR.rawValue] {
            blendedWeather[TypeOfWeather.WINDIRNAME.rawValue] = directions.reduce(into: [:]) { result, item in
                result[item.key] = WindDirection(value: Int(item.value as? Double ?? 0)).description
            }
        }

        let mixName = "Ventus Mix (%lld models)".localized(formatArguments: [forecasts.count])
        var model: [String: Any] = blendedWeather
        model["initdate"] = base.forecast?.initdate ?? ""
        model["initstamp"] = base.forecast?.initStamp ?? 0
        model["model_name"] = mixName
        let map: [String: Any] = [
            "id_spot": base.id_spot ?? "",
            "spotname": base.spotname ?? "",
            "country": base.country ?? "",
            "id_country": base.id_country,
            "lat": base.latitude,
            "lon": base.longitude,
            "alt": base.altitude,
            "tz": base.tz ?? "",
            "gmt_hour_offset": base.gmt_hour_offset,
            "sunrise": base.sunrise ?? "",
            "sunset": base.sunset ?? "",
            "models": base.models,
            "forecast": ["ventus-mix": model]
        ]
        return try SpotForecast(map: map)
    }
}

private func numericValue(_ value: Any?) -> Double? {
    switch value {
    case let value as Double: value
    case let value as Int: Double(value)
    case let value as NSNumber: value.doubleValue
    default: nil
    }
}

private let integerWeatherKeys: Set<String> = [
    TypeOfWeather.TCDC.rawValue,
    TypeOfWeather.HCDC.rawValue,
    TypeOfWeather.MCDC.rawValue,
    TypeOfWeather.LCDC.rawValue,
    TypeOfWeather.RH.rawValue
]

private let circularDirectionWeatherKeys: Set<String> = [
    TypeOfWeather.WINDDIR.rawValue,
    TypeOfWeather.WVDIR.rawValue,
    TypeOfWeather.DIRPW.rawValue
]

private let precipitationWeatherKeys: Set<String> = [
    TypeOfWeather.APCP.rawValue,
    TypeOfWeather.APCP1.rawValue
]

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let mid = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
}

private let fineTuneWeightsByModelName: [(matches: [String], weight: Double)] = [
    (["zephyr-hd", "zephyr_hd", "zephyrhd", "zephyr"], 0.397),
    (["ifs-hres", "ifs_hres", "ifshres", "ifs"], 0.126),
    (["gfs"], 0.213),
    (["wrf"], 0.094),
    (["icon"], 0.091),
    (["gdps"], 0.079)
]

private let fineTuneFallbackWeight = fineTuneWeightsByModelName.map(\.weight).reduce(0, +) / Double(fineTuneWeightsByModelName.count)

private func fineTuneWeight(for forecast: Forecast) -> Double {
    guard let name = forecast.modelName?.lowercased() else { return fineTuneFallbackWeight }
    for entry in fineTuneWeightsByModelName where entry.matches.contains(where: name.contains) {
        return entry.weight
    }
    return fineTuneFallbackWeight
}

private func circularMean(_ degrees: [Double]) -> Double {
    let radians = degrees.map { $0 * .pi / 180 }
    let angle = atan2(radians.map(sin).reduce(0, +), radians.map(cos).reduce(0, +)) * 180 / .pi
    return angle >= 0 ? angle : angle + 360
}
