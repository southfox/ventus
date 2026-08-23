//
//  PrecipitationPhase.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/22/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation

public enum PrecipitationPhase: Sendable, Equatable {
    case rain
    case sleet
    case snow

    public init(freezingLevelMeters: Double?, altitudeMeters: Double, temperatureCelsius: Double) {
        if let freezingLevelMeters, freezingLevelMeters <= altitudeMeters {
            self = .snow
            return
        }
        if temperatureCelsius > 3 {
            self = .rain
        } else if temperatureCelsius >= 1 {
            self = .sleet
        } else {
            self = .snow
        }
    }
}

public extension SpotForecast {
    func precipitationPhase(hh hour: String?) -> PrecipitationPhase {
        let temperature = forecast?.temperatureReal(hh: hour) ?? forecast?.temperature(hh: hour) ?? 0
        return PrecipitationPhase(
            freezingLevelMeters: forecast?.freezingLevelHeightInMeters(hh: hour),
            altitudeMeters: Double(altitude),
            temperatureCelsius: temperature
        )
    }
}
