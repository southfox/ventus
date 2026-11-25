import Foundation
import OSLog
import SwiftData

/// Owns the app's two SwiftData containers. These are the only pieces of
/// genuinely cached, lazily-built shared state the package defines itself
/// (everything else — UserDefaults, Keychain, file-based stores — persists
/// through an OS-level store we don't own). A composition root creates
/// exactly one `VentusPersistenceController` and hands its containers down
/// explicitly to every store that needs them, instead of each store
/// reaching for a static default.
public final class VentusPersistenceController: Sendable {
    public static let appGroupIdentifier = "group.org.forescoop.shared"

    public let mapLocationsContainer: ModelContainer
    public let alertsContainer: ModelContainer
    public let recoveryErrors: [Error]

    private static let logger = Logger(subsystem: "org.forescoop.ventus", category: "Persistence")

    /// - Parameter inMemory: `true` for previews/tests, so nothing touches
    ///   the real App Group store on disk.
    public convenience init(inMemory: Bool = false) {
        let directory = inMemory
            ? nil
            : FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
        self.init(inMemory: inMemory, directory: directory)
    }

    init(inMemory: Bool, directory: URL?) {
        var errors = [Error]()
        mapLocationsContainer = Self.makeContainer(
            schema: Schema([SavedMapLocationRecord.self, VentusPreferenceRecord.self, ForecastCacheRecord.self]),
            fileName: "SavedMapLocations.store",
            directory: directory,
            inMemory: inMemory,
            errors: &errors
        )
        // Needs its own uniquely named file so it doesn't collide with
        // mapLocationsContainer's store in the shared App Group.
        alertsContainer = Self.makeContainer(
            schema: Schema([ForecastAlertRecord.self]),
            fileName: "ForecastAlerts.store",
            directory: directory,
            inMemory: inMemory,
            errors: &errors
        )
        recoveryErrors = errors
    }

    private static func makeContainer(
        schema: Schema,
        fileName: String,
        directory: URL?,
        inMemory: Bool,
        errors: inout [Error]
    ) -> ModelContainer {
        if inMemory {
            return makeInMemoryContainer(schema: schema)
        }

        let storeURL = directory?.appending(path: fileName)
        let configuration = storeURL.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            logger.error("Failed to open \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public). Resetting store.")
            errors.append(error)
        }

        removeStoreFiles(at: configuration.url)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            logger.fault("Failed to recreate \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public). Using in-memory store.")
            errors.append(error)
        }

        return makeInMemoryContainer(schema: schema)
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Unable to create in-memory SwiftData container: \(error)")
        }
    }

    static func removeStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
