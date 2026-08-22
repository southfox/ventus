//
//  WindguruMapSpotPicker.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/01/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS) && !os(tvOS)
import CoreLocation
import SwiftUI

/// Windguru's map-entry point for choosing a coordinate to resolve as a spot.
struct WindguruMapSpotPicker: View {
    let initialCoordinate: CLLocationCoordinate2D?
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void

    @Environment(\.appEnvironment) private var environment

    var body: some View {
        MapLocationPicker(
            initialCoordinate: initialCoordinate,
            environment: environment,
            onSelection: onCoordinateSelected
        )
    }
}

#if DEBUG
#Preview("Windguru map spot picker") {
    WindguruMapSpotPicker(
        initialCoordinate: CLLocationCoordinate2D(latitude: -41.13, longitude: -71.31),
        onCoordinateSelected: { _ in }
    )
}
#endif
#endif
