import SwiftData
import XCTest
@testable import Ventus

final class PersistenceControllerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "VentusPersistenceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testHealthyStoreOpensWithoutRecovery() {
        let controller = VentusPersistenceController(inMemory: false, directory: directory)
        XCTAssertTrue(controller.recoveryErrors.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appending(path: "SavedMapLocations.store").path))
    }

    func testCorruptedStoreIsResetInsteadOfCrashing() throws {
        let storeURL = directory.appending(path: "SavedMapLocations.store")
        try Data("not a sqlite database".utf8).write(to: storeURL)
        try Data("garbage".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))

        let controller = VentusPersistenceController(inMemory: false, directory: directory)

        XCTAssertFalse(controller.recoveryErrors.isEmpty)
        let context = ModelContext(controller.mapLocationsContainer)
        XCTAssertNoThrow(try context.fetch(FetchDescriptor<VentusPreferenceRecord>()))
        XCTAssertTrue(VentusPersistenceController(inMemory: false, directory: directory).recoveryErrors.isEmpty)
    }
}
