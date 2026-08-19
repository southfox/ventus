//
//  SavedMapLocationStore.swift
//  Forescoop
//
//  Created by Javier on 19/08/2026.
//

import CoreLocation
import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

public enum SavedMapLocationStore {
    static let container: ModelContainer = {
        let schema = Schema([SavedMapLocationRecord.self, VentusPreferenceRecord.self])
        let configuration: ModelConfiguration
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.forescoop.shared") {
            configuration = ModelConfiguration(schema: schema, url: groupURL.appending(path: "SavedMapLocations.store"))
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try! ModelContainer(for: schema, configurations: configuration)
    }()
    public static let primarySpotID = "64141"
    private static let primaryLocation = SavedMapLocation(
        id: UUID(uuidString: "64141000-0000-4000-8000-000000000000")!,
        name: "Bariloche",
        coordinate: CLLocationCoordinate2D(latitude: -41.1281, longitude: -71.3480),
        spotID: primarySpotID,
        placeDescription: "Argentina"
    )

    public static func load() -> [SavedMapLocation] {
        let context = ModelContext(container)
        let locations = (try? context.fetch(FetchDescriptor<SavedMapLocationRecord>()))?.map(\.location) ?? []
        return normalized(locations)
    }

    public static func save(_ locations: [SavedMapLocation]) {
        let context = ModelContext(container)
        (try? context.fetch(FetchDescriptor<SavedMapLocationRecord>()))?.forEach { context.delete($0) }
        normalized(locations).forEach { context.insert(SavedMapLocationRecord($0)) }
        try? context.save()
    }

    public static func removeAll() {
        save([primaryLocation])
    }

    public static func clearSessionData() -> [SavedMapLocation] {
        removeAll()
        SelectedWindguruSpotStore.clear()
        return load()
    }

    private static func normalized(_ locations: [SavedMapLocation]) -> [SavedMapLocation] {
        let primary = locations.first(where: \.isPrimaryLocation) ?? primaryLocation
        return locations
            .filter { !$0.isPrimaryLocation }
            .reduce(into: [primary]) { unique, location in
                guard !unique.contains(where: { isSameLocation($0, location) }) else { return }
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
