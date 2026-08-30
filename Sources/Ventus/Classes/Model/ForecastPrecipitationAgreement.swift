//
//  ForecastPrecipitationAgreement.swift
//  Ventus
//

import Foundation

/// The fraction of currently selected forecast models that predict measurable
/// precipitation. This is model agreement, not a provider-issued PoP value.
public struct ForecastPrecipitationAgreement: Sendable {
    public let rainyModelCount: Int
    public let modelCount: Int

    public var percentage: Int {
        Int((Double(rainyModelCount) / Double(modelCount) * 100).rounded())
    }

    public var isLow: Bool { percentage <= 25 }
    public var accessibilityLabel: String {
        "Rain model agreement: \(percentage) percent. \(rainyModelCount) of \(modelCount) models predict measurable precipitation."
    }
}

public extension Collection where Element == SpotForecast {
    /// Returns an agreement only when two or more selected models have usable
    /// precipitation values. Values below 0.1 mm are treated as a trace.
    func precipitationAgreement(hour: String?, threshold: Double = 0.1) -> ForecastPrecipitationAgreement? {
        let precipitation = compactMap { source in
            source.forecast?.precipitation1(hh: hour)
                ?? source.forecast?.precipitation(hh: hour)
        }
        guard precipitation.count >= 2 else { return nil }
        return ForecastPrecipitationAgreement(
            rainyModelCount: precipitation.count(where: { $0 >= threshold }),
            modelCount: precipitation.count
        )
    }
}
