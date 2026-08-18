//
//  Double+ForecastFormatting.swift
//  Forescoop package
//
//  Created by Javier on 07/30/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation

public extension Double {
    func forecastFormatted(precision: Int = 1) -> String {
        let scale = pow(10.0, Double(precision))
        var rounded = (self * scale).rounded() / scale
        if rounded == 0, self != 0 {
            rounded = (self < 0 ? -1.0 : 1.0) / scale
        }
        return rounded.formatted(.number.precision(.fractionLength(precision)))
    }
}
