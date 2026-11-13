//
//  VentusTutorialView.swift
//  Ventus package
//
//  Created by Javier Fuchs on 11/13/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

import SwiftUI

/// A short, repeatable introduction to Ventus. The full feature reference
/// remains available separately in Help.
public struct VentusTutorialView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding private var automaticallyShowsTutorial: Bool
    private let onLogin: () -> Void

    public init(
        automaticallyShowsTutorial: Binding<Bool>,
        onLogin: @escaping () -> Void = {}
    ) {
        _automaticallyShowsTutorial = automaticallyShowsTutorial
        self.onLogin = onLogin
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "wind")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.tint)
                        Text("Welcome to Ventus".localized)
                            .font(.largeTitle.bold())
                        Text("Windguru-powered forecasts, organized for a quick decision before you head out.".localized)
                            .foregroundStyle(.secondary)
                    }

                    TutorialSection(title: "Start here".localized, symbol: "1.circle.fill") {
                        TutorialRow(
                            symbol: "mappin.and.ellipse",
                            title: "Choose a location".localized,
                            detail: "Use the location control to search Windguru spots, open the map, or select a saved place.".localized
                        )
                        TutorialRow(
                            symbol: "rectangle.3.group",
                            title: "Read the dashboard".localized,
                            detail: "See current conditions and the forecast at a glance, then choose an hour for more detail.".localized
                        )
                        TutorialRow(
                            symbol: "line.3.horizontal",
                            title: "Explore forecast views".localized,
                            detail: "The menu opens the Grid, Graph, Overview, and Settings. Your location, selected hour, and units stay in sync.".localized
                        )
                    }

                    TutorialSection(title: "Windguru account".localized, symbol: "person.crop.circle") {
                        Text("Signing in is optional. Use your existing Windguru username and password to access account-based features, including your Windguru favorites.".localized)
                            .foregroundStyle(.secondary)

                        Button("Sign in to Windguru".localized, systemImage: "person.crop.circle") {
                            dismiss()
                            onLogin()
                        }
                        .buttonStyle(.bordered)
                    }

                    TutorialSection(title: "Free and PRO".localized, symbol: "sparkles") {
                        TutorialRow(
                            symbol: "checkmark.circle.fill",
                            title: "Without an account".localized,
                            detail: "Browse locations and use Ventus’s Dashboard, Grid, Graph, Overview, weather details, units, and saved on-device locations.".localized
                        )
                        TutorialRow(
                            symbol: "person.badge.key.fill",
                            title: "Windguru regular account".localized,
                            detail: "Sign in to bring your Windguru account and favorites into Ventus.".localized
                        )
                        TutorialRow(
                            symbol: "star.circle.fill",
                            title: "Windguru PRO account".localized,
                            detail: "Adds forecasts for an exact map coordinate or your current location, plus additional forecast model sources where Windguru makes them available.".localized
                        )
                    }

                    Toggle("Don’t show this tutorial automatically again".localized, isOn: Binding(
                        get: { !automaticallyShowsTutorial },
                        set: { automaticallyShowsTutorial = !$0 }
                    ))
                    .toggleStyle(.switch)
                    .padding(.top, 4)

                    Button("Start exploring".localized) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding()
            }
            .navigationTitle("Tutorial".localized)
#if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
#endif
        }
    }
}

private struct TutorialSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TutorialRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    VentusTutorialView(automaticallyShowsTutorial: .constant(true))
}
#endif
