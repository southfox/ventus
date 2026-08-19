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

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: "Forecast Dashboard"
        case .grid: "Forecast Grid"
        case .workspace: "Grid and Dashboard"
        case .graph: "Forecast Graph"
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard: "rectangle.3.group"
        case .grid: "tablecells"
        case .workspace: "rectangle.split.2x1"
        case .graph: "chart.xyaxis.line"
        }
    }
}

public enum ForecastViewModeStore {
    private static let key = "forecastViewMode"

    public static func load() -> ForecastViewMode {
        let context = ModelContext(SavedMapLocationStore.container)
        let value = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key })?
            .value
        return value.flatMap(ForecastViewMode.init(rawValue:)) ?? defaultMode
    }

    private static var defaultMode: ForecastViewMode {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? .workspace : .dashboard
#else
        .dashboard
#endif
    }

    public static func save(_ mode: ForecastViewMode) {
        let context = ModelContext(SavedMapLocationStore.container)
        if let record = (try? context.fetch(FetchDescriptor<VentusPreferenceRecord>()))?
            .first(where: { $0.key == key }) {
            record.value = mode.rawValue
        } else {
            context.insert(VentusPreferenceRecord(key: key, value: mode.rawValue))
        }
        try? context.save()
    }
}
