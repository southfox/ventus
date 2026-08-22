//
//  ForecastLocationHeader.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/01/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

struct ForecastLocationHeader: View {
    @Environment(\.ventusTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let locationName: String
    var onSelectLocation: (() -> Void)? = nil
    var onShowMap: (() -> Void)? = nil
    let font: Font = .subheadline.bold()

    var body: some View {
        HStack(spacing: 8) {
            if let onSelectLocation {
                Button(action: onSelectLocation) {
                    Label(locationName, systemImage: "mappin.and.ellipse")
                        .font(.headline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose location")
            } else {
                Text(locationName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

#if !os(tvOS)
            if let onShowMap {
                LocationMapButton(
                    locationName: locationName,
                    buttonStyle: .plain,
                    action: onShowMap
                )
            }
#endif
        }
        .font(font)
        .foregroundStyle(theme.accentColor(for: colorScheme))
    }
}

#if DEBUG
#Preview("Forecast location header") {
    ForecastLocationHeader(locationName: SavedMapLocationStore.primaryLocationDisplayName)
    .padding()
}
#Preview("Forecast location header (w/Selection)") {
    ForecastLocationHeader(
        locationName: SavedMapLocationStore.primaryLocationDisplayName,
        onSelectLocation: {},
        onShowMap: {}
    )
    .padding()
}
#endif
#endif
