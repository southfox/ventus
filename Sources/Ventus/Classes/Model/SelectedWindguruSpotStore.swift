//
//  SelectedWindguruSpotStore.swift
//  VentusPackage
//
//  Created by Javier on 19/08/2026.
//

import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

public protocol SelectedWindguruSpotStoring: Sendable {
    func load() -> String
    var hasSavedSelection: Bool { get }
    func save(_ spotID: String)
    func clear()
    var usesCurrentLocation: Bool { get }
    func saveUsesCurrentLocation(_ value: Bool)
    var selectedCoordinate: SelectedForecastCoordinate? { get }
    func saveSelectedCoordinate(_ coordinate: SelectedForecastCoordinate)
    func clearSelectedCoordinate()
}

public struct SelectedForecastCoordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let locationName: String?

    public init(latitude: Double, longitude: Double, locationName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}

public final class SelectedWindguruSpotStore: SelectedWindguruSpotStoring {
    private static let key = "selectedWindguruSpotID"
    private static let usesCurrentLocationKey = "selectedWindguruUsesCurrentLocation"
    private static let coordinateLatitudeKey = "selectedWindguruCoordinateLatitude"
    private static let coordinateLongitudeKey = "selectedWindguruCoordinateLongitude"
    private static let coordinateLocationNameKey = "selectedWindguruCoordinateLocationName"
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> String {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == Self.key })?.value ?? SavedMapLocationStore.primarySpotID
    }

    public var hasSavedSelection: Bool {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.contains(where: { $0.key == Self.key }) ?? false
    }

    public func save(_ spotID: String) {
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == Self.key }) { record.value = spotID } else { context.insert(VentusPreferenceRecord(key: Self.key, value: spotID)) }
        removeCoordinateRecords(from: context)
        try? context.save()
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    public func clear() {
        let context = ModelContext(container)
        let selectionKeys = [
            Self.key,
            Self.usesCurrentLocationKey,
            Self.coordinateLatitudeKey,
            Self.coordinateLongitudeKey,
            Self.coordinateLocationNameKey
        ]
        (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .filter { selectionKeys.contains($0.key) }
            .forEach(context.delete)
        try? context.save()
    }

    public var usesCurrentLocation: Bool {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.usesCurrentLocationKey })?.value == "true"
    }

    public func saveUsesCurrentLocation(_ value: Bool) {
        let context = ModelContext(container)
        let stringValue = value ? "true" : "false"
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.usesCurrentLocationKey }) {
            record.value = stringValue
        } else {
            context.insert(VentusPreferenceRecord(key: Self.usesCurrentLocationKey, value: stringValue))
        }
        try? context.save()
    }

    public var selectedCoordinate: SelectedForecastCoordinate? {
        let context = ModelContext(container)
        let values = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .reduce(into: [String: String]()) { values, record in values[record.key] = record.value } ?? [:]
        guard let latitudeString = values[Self.coordinateLatitudeKey],
              let longitudeString = values[Self.coordinateLongitudeKey],
              let latitude = Double(latitudeString),
              let longitude = Double(longitudeString),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }
        return SelectedForecastCoordinate(
            latitude: latitude,
            longitude: longitude,
            locationName: values[Self.coordinateLocationNameKey]
        )
    }

    public func saveSelectedCoordinate(_ coordinate: SelectedForecastCoordinate) {
        let context = ModelContext(container)
        saveValue(String(coordinate.latitude), for: Self.coordinateLatitudeKey, in: context)
        saveValue(String(coordinate.longitude), for: Self.coordinateLongitudeKey, in: context)
        if let locationName = coordinate.locationName, !locationName.isEmpty {
            saveValue(locationName, for: Self.coordinateLocationNameKey, in: context)
        } else {
            removeValue(for: Self.coordinateLocationNameKey, from: context)
        }
        try? context.save()
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    public func clearSelectedCoordinate() {
        let context = ModelContext(container)
        removeCoordinateRecords(from: context)
        try? context.save()
    }

    private func saveValue(_ value: String, for key: String, in context: ModelContext) {
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?.first(where: { $0.key == key }) {
            record.value = value
        } else {
            context.insert(VentusPreferenceRecord(key: key, value: value))
        }
    }

    private func removeCoordinateRecords(from context: ModelContext) {
        [Self.coordinateLatitudeKey, Self.coordinateLongitudeKey, Self.coordinateLocationNameKey]
            .forEach { removeValue(for: $0, from: context) }
    }

    private func removeValue(for key: String, from context: ModelContext) {
        (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .filter { $0.key == key }
            .forEach(context.delete)
    }
}
