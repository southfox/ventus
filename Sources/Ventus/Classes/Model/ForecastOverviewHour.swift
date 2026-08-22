//
//  ForecastOverviewHour.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/22/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation

public struct ForecastOverviewHour: Identifiable, Sendable {
    public let id = UUID()
    public let dayLabel: String
    public let timeLabel: String
    public let symbolName: String
    public let temperature: String
    public let wind: String
    public let gust: String
    public let windDirectionDegrees: Double
    public let windChill: String?
    public let freezingLevel: String
    public let rain: String?
    public let snow: String?
    public let daylightTime: String?
    public let daylightSymbolName: String?

    public init(
        dayLabel: String,
        timeLabel: String,
        symbolName: String,
        temperature: String,
        wind: String,
        gust: String,
        windDirectionDegrees: Double,
        windChill: String? = nil,
        freezingLevel: String,
        rain: String? = nil,
        snow: String? = nil,
        daylightTime: String? = nil,
        daylightSymbolName: String? = nil
    ) {
        self.dayLabel = dayLabel
        self.timeLabel = timeLabel
        self.symbolName = symbolName
        self.temperature = temperature
        self.wind = wind
        self.gust = gust
        self.windDirectionDegrees = windDirectionDegrees
        self.windChill = windChill
        self.freezingLevel = freezingLevel
        self.rain = rain
        self.snow = snow
        self.daylightTime = daylightTime
        self.daylightSymbolName = daylightSymbolName
    }
}
