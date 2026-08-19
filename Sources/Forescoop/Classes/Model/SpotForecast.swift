//
//  SpotForecast.swift
//  Xoshem-watch
//
//  Created by Javier Fuchs on 10/7/15.
//  Copyright © 2023 Fuchs. All rights reserved.
//

import Foundation

/*
 *  SpotForecast
 *
 *  Discussion:
 *    Represents a model information of the stot or location when the forecast is obtained.
 *    By inheritance the common attributes are parsed and filled in SpotInfo and Spot.
 *    Contains the complete forecast (inside a single instance of ForecastModel)
 *
 *   {
 *       "id_spot": "64141",
 *       "spotname": "Bariloche",
 *       "country": "Argentina",
 *       "id_country": 32,
 *       "lat": -41.1281,
 *       "lon": -71.348,
 *       "alt": 770,
 *       "tz": "America/Argentina/Mendoza",
 *       "gmt_hour_offset": -3,
 *       "sunrise": "07:11",
 *       "sunset": "19:54",
 *       "models": [
 *           "3"
 *       ],
 *       "tides": "0",
 *       "forecast": { ... }
 *   }
 *        
 *
 */

public class SpotForecast: SpotInfo {
    
    var currentModel: String? = nil

    var forecasts = [ForecastModel]()

    required convenience init?(map: [String: Any]?) throws {
        self.init()
        try mapping(map: map)
    }

    public override func mapping(map: [String: Any]?) throws {
        try super.mapping(map: map)
        guard let forecastDict = map?["forecast"] as? [String: Any] else { return }
        forecasts = try forecastDict.compactMap { model, value in
            guard let info = value as? [String: Any],
                  info[TypeOfWeather.WINDSPD.rawValue] is [String: Any] else {
                return nil
            }
            return try ForecastModel(map: ["model": model, "info": info, "gmt_hour_offset": gmtHourOffset])
        }
        currentModel = forecasts.first(where: { $0.model == Model.defaultModel })?.model ?? forecasts.first?.model
    }
    
    override public var description : String {
        [
            super.description,
            "\(type(of:self)): ",
            currentModel?.description,
            forecasts
                .compactMap({$0.description})
                .joined(separator: "\n")
        ]
            .compactMap{$0}
            .joined(separator: "\n")
    }
}

public extension SpotForecast {

    func locationDisplayName(coordinateLocationName: String? = nil) -> String {
        guard isCoordinateLocation,
              let coordinateLocationName,
              !coordinateLocationName.isEmpty else {
            return displayName
        }
        return coordinateLocationName
    }

    var availableForecastHours: [String] {
        forecast?.availableHours ?? []
    }

    var hasRealTemperatureData: Bool {
        availableForecastHours.contains { forecast?.temperatureReal(hh: $0) != nil }
    }

    var currentForecastHour: String? {
        let hours = availableForecastHours.compactMap { hour -> (String, Int)? in
            guard let value = Int(hour) else { return nil }
            return (hour, value)
        }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
           let initStamp = forecast?.initStamp, initStamp > 0 {
            let elapsedHours = Date().timeIntervalSince(Date(timeIntervalSince1970: TimeInterval(initStamp))) / 3_600
            return hours.last(where: { Double($0.1) <= elapsedHours })?.0 ?? hours.first?.0
        }
        return hours.last(where: { $0.1 <= currentHourInt })?.0 ?? hours.first?.0
    }

    func steppedForecastHours(anchorHour: String?, step: Int, includingPast: Bool = true) -> [String] {
        var allHours = availableForecastHours
        if !includingPast, let anchorHour, let anchorOffset = Int(anchorHour) {
            allHours = allHours.filter { (Int($0) ?? 0) >= anchorOffset }
        }
        guard step > 1, let anchorHour, let anchorIndex = allHours.firstIndex(of: anchorHour) else {
            return allHours
        }
        return allHours.enumerated()
            .filter { ($0.offset - anchorIndex).isMultiple(of: step) }
            .map(\.element)
    }

    func forecastDate(hour: String?, relativeTo referenceDate: Date = Date()) -> Date? {
        guard let offset = Int(hour ?? "") else { return nil }
        if let initStamp = forecast?.initStamp, initStamp > 0 {
            return Date(timeIntervalSince1970: TimeInterval(initStamp)).addingTimeInterval(TimeInterval(offset) * 3_600)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
            ?? TimeZone(secondsFromGMT: gmtHourOffset * 3_600)
            ?? .current
        return calendar.date(byAdding: .hour, value: offset, to: calendar.startOfDay(for: referenceDate))
    }

    func dailyTemperatureRange(hour: String?) -> (low: Double, high: Double)? {
        guard let date = forecastDate(hour: hour) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
            ?? TimeZone(secondsFromGMT: gmtHourOffset * 3_600)
            ?? .current
        let day = calendar.startOfDay(for: date)
        let temperatures = availableForecastHours
            .filter { calendar.startOfDay(for: forecastDate(hour: $0) ?? date) == day }
            .compactMap { forecast?.temperatureReal(hh: $0) ?? forecast?.temperature(hh: $0) }
        guard let low = temperatures.min(), let high = temperatures.max() else { return nil }
        return (low, high)
    }

    var numberOfForecasts: Int {
        forecasts.count
    }
    
    var model: String? {
        currentModel
    }
    
    var forecastModel: ForecastModel? {
        forecasts.first(where: {$0.model == currentModel})
    }
    
    var forecast: Forecast? {
        forecastModel?.forecast
    }
    
    var weatherInfo: String {
        weatherSymbolName(hour: currentForecastHour)
    }

    func weatherSymbolName(hour: String?) -> String {
        weatherSymbolNames(hour: hour).first ?? "sun.max.fill"
    }

    static let strongWindBeaufortThreshold = 6

    private func skyObscuringCloudCover(hh hour: String?) -> Int {
        let low = forecast?.cloudCoverLow(hh: hour) ?? 0
        let mid = forecast?.cloudCoverMid(hh: hour) ?? 0
        let high = forecast?.cloudCoverHigh(hh: hour) ?? 0
        guard low > 0 || mid > 0 || high > 0 else {
            return forecast?.cloudCoverTotal(hh: hour) ?? 0
        }
        return Int(max(Double(low), Double(mid) * 0.7, Double(high) * 0.35))
    }

    func weatherSymbolNames(hour: String?) -> [String] {
        let precipitation = forecast?.precipitation(hh: hour)
            ?? forecast?.precipitation1(hh: hour)
            ?? 0
        let modelTemperature = forecast?.temperature(hh: hour) ?? forecast?.temperatureReal(hh: hour) ?? 0
        let phaseTemperature = forecast?.temperatureReal(hh: hour) ?? forecast?.temperature(hh: hour) ?? 0
        let cloudCover = skyObscuringCloudCover(hh: hour)
        let humidity = forecast?.relativeHumidity(hh: hour) ?? 0
        let windSpeed = forecast?.windSpeed(hh: hour) ?? 0
        let windGusts = forecast?.windGustsKnots(hh: hour) ?? 0
        let isNight = !isDaylight(at: forecastDate(hour: hour) ?? Date())
        var symbols: [String] = []

        let oktas = Int((Double(cloudCover) / 100 * 8).rounded())
        let isSnow = precipitation > 0 && phaseTemperature <= 0
        let isHeavyRain = precipitation > 0 && !isSnow && precipitation >= 8
        let isLightRain = precipitation > 0 && !isSnow && !isHeavyRain

        if isSnow {
            symbols.append("snowflake")
        } else if isHeavyRain {
            symbols.append("cloud.heavyrain")
        } else if isLightRain, oktas <= 2 {
            symbols.append(isNight ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill")
        } else if isLightRain {
            symbols.append(precipitation < 2 ? "cloud.drizzle" : "cloud.rain.fill")
        } else if humidity >= 95 && cloudCover >= 80 {
            symbols.append("cloud.fog")
        } else if oktas <= 2 {
            symbols.append(isNight ? "moon.stars.fill" : modelTemperature >= 30 ? "sun.haze" : "sun.max.fill")
        } else if oktas <= 4 {
            symbols.append(isNight ? "cloud.moon.fill" : "cloud.sun.fill")
        } else if oktas <= 7 {
            symbols.append("cloud")
        } else {
            symbols.append("cloud.fill")
        }

        let beaufort = max(Knots(windSpeed).bft ?? 0, Knots(windGusts).bft ?? 0)
        if beaufort >= SpotForecast.strongWindBeaufortThreshold,
           let windSymbol = SpotForecast.windSymbolName(forBeaufort: beaufort) {
            symbols.insert(windSymbol, at: 0)
        }

        return symbols
    }

    static func windSymbolName(forBeaufort beaufort: Int) -> String? {
        let ladder = [
            "wind", "wind.circle", "wind.circle.fill",
            "tornado", "tornado.circle", "tornado.circle.fill",
            "tropicalstorm", "tropicalstorm.circle", "tropicalstorm.circle.fill",
            "hurricane", "hurricane.circle", "hurricane.circle.fill",
        ]
        guard beaufort > 0 else { return nil }
        return ladder[min(beaufort, ladder.count) - 1]
    }
    
    var asHourString: String {
        var hourString: String
        let hh: Int = currentHour

        hourString = String(format: "%02d hs", hh)
        
        return hourString
    }
    
    var asCurrentWindDirectionName: String? {
        forecast?.windDirectionName(hh: currentHourString)
    }
    
    var asCurrentWindDirection: Float {
        Float(forecast?.windDirection(hh: currentHourString) ?? 0.0)
    }
    
    var asCurrentWindSpeed: String? {
        guard let forecast = forecast,
            let windSpeed = forecast.windSpeed(hh: currentHourString) else {
                return nil
        }
        return "\(windSpeed) knots"
    }
    
    // "11"
    var asCurrentTemperature: String? {
        guard let forecast = forecast,
            let temperatureReal = forecast.temperatureReal(hh: currentHourString) else {
                return nil
        }
        return "\(temperatureReal)\(asCurrentUnit)"
    }
    
    // "C" or "F"
    var asCurrentUnit: String {
        "°C"
    }
    
    var asCurrentLocation: String? {
        name
    }
}

private extension SpotForecast {
    
    var isNight: Bool {
        !isDaylight(at: Date())
    }
    
    var isSunny: Bool {
        // if TCDC is == 0
        cloudCoverTotal == 0
    }
    
    var isCloudy: Bool {
        !isSunny
    }
    
    var cloudCoverTotal: Int {
        forecast?.cloudCoverTotal(hh: currentHourString) ?? 0
    }
    
    var isRaining: Bool {
        precipitation > 0.0
    }
    
    var precipitation: Double {
        forecast?.precipitation(hh: currentHourString) ?? 0
    }

    var windSpeed: Double {
        forecast?.windSpeed(hh: currentHourString) ?? 0
    }

    var windGusts: Double {
        forecast?.windGusts(hh: currentHourString) ?? 0
    }

    var relativeHumidity: Int {
        forecast?.relativeHumidity(hh: currentHourString) ?? 0
    }

    var currentTemperature: Double {
        forecast?.temperatureReal(hh: currentHourString) ?? forecast?.temperature(hh: currentHourString) ?? 0
    }
    
    var mockupCurrentHourInt: Int {
        12
    }

    var realCurrentHourInt: Int {
        let date = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour
    }

    var currentHourInt: Int {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return mockupCurrentHourInt
        } else {
            return realCurrentHourInt
        }
    }
    
    var currentHour: Int {
        Int(currentForecastHour ?? "") ?? currentHourInt
    }
    
    var currentHourString: String? {
        currentForecastHour
    }
}
