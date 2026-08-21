//
//  SavedMapLocation 2.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//  

import CoreLocation
import Foundation
#if os(iOS)
import UIKit
#endif

public struct SavedMapLocation: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public let latitude: Double
    public let longitude: Double
    public let spotID: String?
    public let placeDescription: String?

    public init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        spotID: String? = nil,
        placeDescription: String? = nil
    ) {
        self.id = id
        self.name = name
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.spotID = spotID
        self.placeDescription = placeDescription
    }

    public var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    public var coordinateText: String { "\(latitude.formatted(.number.precision(.fractionLength(4)))), \(longitude.formatted(.number.precision(.fractionLength(4))))" }
    public var displayName: String {
        guard let spotID, spotID != "0" else { return name }
        return "\(name) #\(spotID)"
    }
    public var detailText: String {
        guard let spotID, spotID != "0" else { return coordinateText }
        return placeDescription?.isEmpty == false ? placeDescription! : coordinateText
    }
    public var isPrimaryLocation: Bool { spotID == SavedMapLocationStore.primarySpotID }
}
