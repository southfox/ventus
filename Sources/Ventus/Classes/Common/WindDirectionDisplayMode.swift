//
//  WindDirectionDisplayMode.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/23/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation

public enum WindDirectionDisplayMode: CaseIterable, Equatable, Sendable {
    case arrow
    case degrees

    public var next: WindDirectionDisplayMode {
        let cases = Self.allCases
        let index = cases.firstIndex(of: self) ?? cases.startIndex
        return cases[cases.index(after: index) == cases.endIndex ? cases.startIndex : cases.index(after: index)]
    }

    public var indicator: String {
        switch self {
        case .arrow: "→"
        case .degrees: "°"
        }
    }

    public func text(forWindFrom direction: Double) -> String {
        switch self {
        case .arrow:
            return Self.arrow(forTravelToward: direction + 180)
        case .degrees:
            return "\(Int(direction.rounded()))°"
        }
    }

    public static func arrow(forTravelToward direction: Double) -> String {
        let arrows = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
        let normalized = direction.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return arrows[Int((positive + 22.5) / 45) % arrows.count]
    }
}
