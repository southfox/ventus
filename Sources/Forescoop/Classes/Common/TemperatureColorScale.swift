//
//  TemperatureColorScale.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/17/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public enum TemperatureColorScale {
    public static func color(forCelsius celsius: Double) -> Color {
        switch celsius {
        case ..<(-10): Color(red: 0.62, green: 0.80, blue: 1.00) // deep freeze: icy blue
        case ..<0: Color(red: 0.35, green: 0.62, blue: 1.00) // freezing: blue
        case ..<10: Color(red: 0.30, green: 0.82, blue: 0.95) // cold: cyan
        case ..<18: Color(red: 0.40, green: 0.80, blue: 0.55) // cool/mild: green
        case ..<25: .yellow // warm: yellow
        case ..<32: .orange // hot: orange
        default: .red // very hot: red
        }
    }

    public static func palette(forCelsius celsius: Double) -> (primary: Color, secondary: Color) {
        let color = color(forCelsius: celsius)
        return (color, color.opacity(0.35))
    }
}

public struct ThermalLabel: View {
    private let title: String
    private let celsius: Double
    private let spacing: CGFloat

    public init(_ title: String, celsius: Double, spacing: CGFloat = 4) {
        self.title = title
        self.celsius = celsius
        self.spacing = spacing
    }

    public var body: some View {
        let palette = TemperatureColorScale.palette(forCelsius: celsius)
        HStack(spacing: spacing) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(palette.primary, palette.secondary)
            Text(title)
        }
    }

    private var symbolName: String {
        switch celsius {
        case ..<0: "thermometer.snowflake"
        case ..<18: "thermometer.medium"
        case ..<28: "thermometer.sun"
        default: "thermometer.sun.fill"
        }
    }
}

#if DEBUG
#Preview("ThermalLabel Preview") {
    VStack(spacing: 12) {
        ThermalLabel("Freezing", celsius: -5)
        ThermalLabel("Mild", celsius: 12)
        ThermalLabel("Warm", celsius: 22)
        ThermalLabel("Hot", celsius: 32, spacing: 6)
    }
    .padding()
}
#endif
