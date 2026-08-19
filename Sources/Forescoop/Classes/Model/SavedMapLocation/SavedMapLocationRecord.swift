//
//  SavedMapLocationRecord.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//  

import CoreLocation
import Foundation
import SwiftData

@Model final class SavedMapLocationRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var spotID: String?
    var placeDescription: String?

    init(_ location: SavedMapLocation) {
        id = location.id; name = location.name; latitude = location.latitude; longitude = location.longitude
        spotID = location.spotID; placeDescription = location.placeDescription
    }

    var location: SavedMapLocation { SavedMapLocation(id: id, name: name, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), spotID: spotID, placeDescription: placeDescription) }
}
