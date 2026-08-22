//
//  VentusPersistenceController.swift
//  VentusPackage
//
//  Created by Javier Fuchs on 08/20/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import Foundation
import SwiftData

/// Owns the app's two SwiftData containers. These are the only pieces of
/// genuinely cached, lazily-built shared state the package defines itself
/// (everything else — UserDefaults, Keychain, file-based stores — persists
/// through an OS-level store we don't own). A composition root creates
/// exactly one `VentusPersistenceController` and hands its containers down
/// explicitly to every store that needs them, instead of each store
/// reaching for a static default.
public final class VentusPersistenceController: Sendable {
    public let mapLocationsContainer: ModelContainer
    public let alertsContainer: ModelContainer

    /// - Parameter inMemory: `true` for previews/tests, so nothing touches
    ///   the real App Group store on disk.
    public init(inMemory: Bool = false) {
        mapLocationsContainer = Self.makeContainer(
            schema: Schema([SavedMapLocationRecord.self, VentusPreferenceRecord.self]),
            fileName: "SavedMapLocations.store",
            inMemory: inMemory
        )
        // Needs its own uniquely named file so it doesn't collide with
        // mapLocationsContainer's store in the shared App Group.
        alertsContainer = Self.makeContainer(
            schema: Schema([ForecastAlertRecord.self]),
            fileName: "ForecastAlerts.store",
            inMemory: inMemory
        )
    }

    private static func makeContainer(schema: Schema, fileName: String, inMemory: Bool) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.forescoop.shared") {
            configuration = ModelConfiguration(schema: schema, url: groupURL.appending(path: fileName))
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try! ModelContainer(for: schema, configurations: configuration)
    }
}
