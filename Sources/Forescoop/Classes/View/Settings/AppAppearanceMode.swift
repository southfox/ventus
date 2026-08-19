//
//  AppAppearanceMode.swift
//  Forescoop package
//
//  Created by Javier Fuchs on 08/19/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    public var systemImage: String {
        switch self {
        case .system: "circle.righthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

public extension View {
    func appAppearance(_ mode: AppAppearanceMode) -> some View {
        preferredColorScheme(mode.colorScheme)
    }
}

public enum AppAppearanceModeStore {
    private static let key = "appAppearanceMode"

    public static func load() -> AppAppearanceMode {
        UserDefaults.standard.string(forKey: key).flatMap(AppAppearanceMode.init(rawValue:)) ?? .system
    }

    public static func save(_ mode: AppAppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: key)
    }
}
