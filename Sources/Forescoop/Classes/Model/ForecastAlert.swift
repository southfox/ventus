//
//  ForecastAlert.swift
//  Forescoop
//
//  User-defined conditions that trigger a push notification via
//  ForecastSevereWeatherNotifier, independent of its built-in severe-weather
//  rules.
//

import Foundation
import SwiftData

public enum ForecastAlertVariable: String, CaseIterable, Identifiable, Sendable, Codable {
    case temperature
    case windSpeed
    case windGusts
    case precipitation
    case waveHeight
    case seaLevelPressure
    case freezingLevel

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .temperature: "Temperature"
        case .windSpeed: "Wind speed"
        case .windGusts: "Wind gusts"
        case .precipitation: "Precipitation"
        case .waveHeight: "Wave height"
        case .seaLevelPressure: "Pressure"
        case .freezingLevel: "Freezing level"
        }
    }

    public var unit: String {
        switch self {
        case .temperature: "°C"
        case .windSpeed, .windGusts: "knots"
        case .precipitation: "mm/h"
        case .waveHeight: "m"
        case .seaLevelPressure: "hPa"
        case .freezingLevel: "m"
        }
    }

    func value(in forecast: Forecast, hour: String?) -> Double? {
        switch self {
        case .temperature: forecast.temperatureReal(hh: hour) ?? forecast.temperature(hh: hour)
        case .windSpeed: forecast.windSpeed(hh: hour)
        case .windGusts: forecast.windGustsKnots(hh: hour)
        case .precipitation: forecast.precipitation1(hh: hour) ?? forecast.precipitation(hh: hour)
        case .waveHeight: forecast.waveHeight(hh: hour)
        case .seaLevelPressure: forecast.seaLevelPressure(hh: hour)
        case .freezingLevel: forecast.freezingLevelHeightInMeters(hh: hour)
        }
    }
}

public enum ForecastAlertComparator: String, CaseIterable, Identifiable, Sendable, Codable {
    case greaterThanOrEqual
    case lessThanOrEqual

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .greaterThanOrEqual: "≥"
        case .lessThanOrEqual: "≤"
        }
    }

    func isSatisfied(_ value: Double, _ threshold: Double) -> Bool {
        switch self {
        case .greaterThanOrEqual: value >= threshold
        case .lessThanOrEqual: value <= threshold
        }
    }
}

public struct ForecastAlertCondition: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var variable: ForecastAlertVariable
    public var comparator: ForecastAlertComparator
    public var value: Double

    public init(id: UUID = UUID(), variable: ForecastAlertVariable = .temperature, comparator: ForecastAlertComparator = .greaterThanOrEqual, value: Double = 0) {
        self.id = id
        self.variable = variable
        self.comparator = comparator
        self.value = value
    }

    func isSatisfied(by forecast: Forecast, hour: String?) -> Bool {
        guard let value = variable.value(in: forecast, hour: hour) else { return false }
        return comparator.isSatisfied(value, self.value)
    }
}

public struct ForecastAlert: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var spotID: String
    public var spotDisplayName: String
    public var modelIDs: [String]
    public var conditions: [ForecastAlertCondition]
    public var considerForecastUpToDay: Int
    public var weekdays: Set<Int>
    public var pushNotificationEnabled: Bool
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String = "",
        spotID: String,
        spotDisplayName: String,
        modelIDs: [String] = [],
        conditions: [ForecastAlertCondition] = [ForecastAlertCondition()],
        considerForecastUpToDay: Int = 3,
        weekdays: Set<Int> = [],
        pushNotificationEnabled: Bool = true,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.spotID = spotID
        self.spotDisplayName = spotDisplayName
        self.modelIDs = modelIDs
        self.conditions = conditions
        self.considerForecastUpToDay = considerForecastUpToDay
        self.weekdays = weekdays
        self.pushNotificationEnabled = pushNotificationEnabled
        self.isActive = isActive
    }

    public var displayTitle: String {
        name.isEmpty ? spotDisplayName : "\(name), \(spotDisplayName)"
    }

    public var conditionsSummary: String {
        conditions.map { "\($0.variable.title.localized) \($0.comparator.symbol) \(formatted($0.value))\($0.variable.unit.localized)" }
            .joined(separator: ", ")
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(value)
    }
}

@Model
final class ForecastAlertRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var spotID: String
    var spotDisplayName: String
    var modelIDs: [String]
    var conditionsData: Data
    var considerForecastUpToDay: Int
    var weekdays: [Int]
    var pushNotificationEnabled: Bool
    var isActive: Bool

    init(_ alert: ForecastAlert) {
        id = alert.id
        name = alert.name
        spotID = alert.spotID
        spotDisplayName = alert.spotDisplayName
        modelIDs = alert.modelIDs
        conditionsData = (try? JSONEncoder().encode(alert.conditions)) ?? Data()
        considerForecastUpToDay = alert.considerForecastUpToDay
        weekdays = Array(alert.weekdays)
        pushNotificationEnabled = alert.pushNotificationEnabled
        isActive = alert.isActive
    }

    var alert: ForecastAlert {
        ForecastAlert(
            id: id,
            name: name,
            spotID: spotID,
            spotDisplayName: spotDisplayName,
            modelIDs: modelIDs,
            conditions: (try? JSONDecoder().decode([ForecastAlertCondition].self, from: conditionsData)) ?? [],
            considerForecastUpToDay: considerForecastUpToDay,
            weekdays: Set(weekdays),
            pushNotificationEnabled: pushNotificationEnabled,
            isActive: isActive
        )
    }

    func update(with alert: ForecastAlert) {
        name = alert.name
        spotID = alert.spotID
        spotDisplayName = alert.spotDisplayName
        modelIDs = alert.modelIDs
        conditionsData = (try? JSONEncoder().encode(alert.conditions)) ?? Data()
        considerForecastUpToDay = alert.considerForecastUpToDay
        weekdays = Array(alert.weekdays)
        pushNotificationEnabled = alert.pushNotificationEnabled
        isActive = alert.isActive
    }
}

public protocol ForecastAlertStoring: Sendable {
    func load() -> [ForecastAlert]
    func save(_ alert: ForecastAlert)
    func remove(_ alert: ForecastAlert)
    func setActive(_ isActive: Bool, for alertID: UUID)
}

public final class ForecastAlertStore: ForecastAlertStoring {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> [ForecastAlert] {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<ForecastAlertRecord>()))?.map(\.alert) ?? []
    }

    public func save(_ alert: ForecastAlert) {
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<ForecastAlertRecord>()))?.first(where: { $0.id == alert.id }) {
            record.update(with: alert)
        } else {
            context.insert(ForecastAlertRecord(alert))
        }
        try? context.save()
    }

    public func remove(_ alert: ForecastAlert) {
        let context = ModelContext(container)
        guard let record = (try? context.fetch(FetchDescriptor<ForecastAlertRecord>()))?.first(where: { $0.id == alert.id }) else { return }
        context.delete(record)
        try? context.save()
    }

    public func setActive(_ isActive: Bool, for alertID: UUID) {
        let context = ModelContext(container)
        guard let record = (try? context.fetch(FetchDescriptor<ForecastAlertRecord>()))?.first(where: { $0.id == alertID }) else { return }
        record.isActive = isActive
        try? context.save()
    }
}
