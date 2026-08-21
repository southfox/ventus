//
//  ForecastViewMode.swift
//  ForescoopPackage
//
//  Created by Javier on 19/08/2026.
//  

import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

public enum ForecastViewMode: String, CaseIterable, Identifiable, Sendable {
    case dashboard
    case grid
    case workspace
    case graph
    case overview

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: "Forecast Dashboard"
        case .grid: "Forecast Grid"
        case .workspace: "Grid and Dashboard"
        case .graph: "Forecast Graph"
        case .overview: "Overview"
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard: "rectangle.3.group"
        case .grid: "tablecells"
        case .workspace: "rectangle.split.2x1"
        case .graph: "chart.xyaxis.line"
        case .overview: "square.grid.2x2"
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .workspace:
#if os(watchOS)
            return false
#elseif os(iOS)
            return UIDevice.current.userInterfaceIdiom != .phone
#else
            return true
#endif
        case .overview:
#if os(watchOS) || !canImport(WidgetKit)
            return false
#else
            return true
#endif
        default:
            return true
        }
    }

    public static var availableCases: [ForecastViewMode] {
        allCases.filter(\.isAvailable)
    }
}

public protocol ForecastViewModeStoring: Sendable {
    func load() -> ForecastViewMode
    func save(_ mode: ForecastViewMode)
}

public final class ForecastViewModeStore: ForecastViewModeStoring {
    private static let key = "forecastViewMode"

    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func load() -> ForecastViewMode {
        let context = ModelContext(container)
        let value = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key })?
            .value
        let saved = value.flatMap(ForecastViewMode.init(rawValue:))
        return saved?.isAvailable == true ? saved! : Self.defaultMode
    }

    private static var defaultMode: ForecastViewMode {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? .workspace : .dashboard
#else
        .dashboard
#endif
    }

    public func save(_ mode: ForecastViewMode) {
        let context = ModelContext(container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == Self.key }) {
            record.value = mode.rawValue
        } else {
            context.insert(VentusPreferenceRecord(key: Self.key, value: mode.rawValue))
        }
        try? context.save()
    }
}
