//
//  ForecastWidgetProvider.swift
//  Ventus package
//
//  Created by Javier Fuchs on 8/15/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if canImport(WidgetKit) && !os(tvOS)
import Ventus
import SwiftUI
import WidgetKit

public struct ForecastWidgetProvider: TimelineProvider, Sendable {
    private let environment = AppEnvironment()

    public init() {}

    public func placeholder(in context: Context) -> ForecastWidgetEntry { .placeholder }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (ForecastWidgetEntry) -> Void) {
        Task { completion(await currentEntry()) }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ForecastWidgetEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            let nextHourDate = Self.nextHourBoundary(after: .now)
            completion(Timeline(entries: [entry], policy: .after(nextHourDate)))
        }
    }

    private static func nextHourBoundary(after date: Date) -> Date {
        let calendar = Calendar.current
        let startOfHour = calendar.date(bySetting: .minute, value: 0, of: date)
            .flatMap { calendar.date(bySetting: .second, value: 0, of: $0) }
            ?? date
        return calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? date.addingTimeInterval(3_600)
    }

    private static let snapshotFreshnessWindow: TimeInterval = 3 * 3_600

    private func currentEntry() async -> ForecastWidgetEntry {
        if let snapshot = environment.sharedForecastSnapshotStore.load(),
           Date().timeIntervalSince(snapshot.date) < Self.snapshotFreshnessWindow {
            return entry(from: snapshot)
        }
        if let liveEntry = await fetchLiveEntry() {
            return liveEntry
        }
        if let snapshot = environment.sharedForecastSnapshotStore.load() {
            return entry(from: snapshot)
        }
        return .needsUpdate
    }

    private func fetchLiveEntry() async -> ForecastWidgetEntry? {
        let spotID = environment.selectedSpotStore.load()
        let username = environment.windguruCredentialStore.activeUsername()
        let isProUser = environment.windguruCredentialStore.activeProUser()
        let password = username.flatMap(environment.windguruCredentialStore.password(for:))
        let savedLocationName = environment.savedMapLocationStore.load().first(where: { $0.spotID == spotID })?.name

        return await withTimeout(seconds: 12) {
            let service = ForecastWindguruService()
            do {
                guard let forecast = try await service.bestForecast(
                    bySpotId: spotID,
                    model: nil,
                    username: isProUser ? username : nil,
                    password: isProUser ? password : nil
                ), !forecast.availableForecastHours.isEmpty else { return nil }
                return self.entry(from: forecast, coordinateLocationName: savedLocationName)
            } catch {
                return nil
            }
        }
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result ?? nil
        }
    }

    private func entry(from forecast: SpotForecast, coordinateLocationName: String?) -> ForecastWidgetEntry {
        ForecastWidgetEntryBuilder.entry(from: forecast, coordinateLocationName: coordinateLocationName, environment: environment)
    }

    private func entry(from snapshot: SharedForecastSnapshot) -> ForecastWidgetEntry {
        ForecastWidgetEntryBuilder.entry(from: snapshot)
    }
}

#if DEBUG
#Preview("Provider result") {
    ForecastWidgetView(entry: .placeholder, theme: .system)
        .frame(width: 320, height: 150)
        .padding()
        .background(.blue.gradient)
}
#endif
#endif
