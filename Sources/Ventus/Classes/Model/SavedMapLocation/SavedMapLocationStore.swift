//
//  SavedMapLocationStore.swift
//  Ventus
//
//  Created by Javier on 19/08/2026.
//

import CoreLocation
import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

public protocol SavedMapLocationStoring: Sendable {
    func load() -> [SavedMapLocation]
    func save(_ locations: [SavedMapLocation])
    func removeAll()
    func clearSessionData() -> [SavedMapLocation]
}

public final class SavedMapLocationStore: SavedMapLocationStoring {
    public static let primarySpotID = "64141"
    private static let primaryLocation = SavedMapLocation(
        id: UUID(uuidString: "64141000-0000-4000-8000-000000000000")!,
        name: "Bariloche",
        coordinate: CLLocationCoordinate2D(latitude: -41.1281, longitude: -71.3480),
        spotID: primarySpotID,
        placeDescription: "Argentina"
    )

    private let container: ModelContainer
    private let selectedSpotStore: SelectedWindguruSpotStoring

    public init(container: ModelContainer, selectedSpotStore: SelectedWindguruSpotStoring) {
        self.container = container
        self.selectedSpotStore = selectedSpotStore
    }

    public func load() -> [SavedMapLocation] {
        let context = ModelContext(container)
        let locations = (try? context.fetch(FetchDescriptor<SavedMapLocationRecord>()))?.map(\.location) ?? []
        return normalized(locations)
    }

    public func save(_ locations: [SavedMapLocation]) {
        let context = ModelContext(container)
        (try? context.fetch(FetchDescriptor<SavedMapLocationRecord>()))?.forEach { context.delete($0) }
        normalized(locations).forEach { context.insert(SavedMapLocationRecord($0)) }
        try? context.save()
    }

    public func removeAll() {
        save([Self.primaryLocation])
    }

    public func clearSessionData() -> [SavedMapLocation] {
        removeAll()
        selectedSpotStore.clear()
        return load()
    }

    private func normalized(_ locations: [SavedMapLocation]) -> [SavedMapLocation] {
        let primary = locations.first(where: \.isPrimaryLocation) ?? Self.primaryLocation
        return locations
            .filter { !$0.isPrimaryLocation }
            .reduce(into: [primary]) { unique, location in
                guard !unique.contains(where: { Self.isSameLocation($0, location) }) else { return }
                unique.append(location)
            }
    }

    public static func isSameLocation(_ lhs: SavedMapLocation, _ rhs: SavedMapLocation) -> Bool {
        if let leftSpotID = lhs.spotID, let rightSpotID = rhs.spotID, leftSpotID == rightSpotID {
            return true
        }
        return abs(lhs.latitude - rhs.latitude) < 0.0001
            && abs(lhs.longitude - rhs.longitude) < 0.0001
    }
}
