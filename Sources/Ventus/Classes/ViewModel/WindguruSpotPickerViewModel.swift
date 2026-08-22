//
//  WindguruSpotPickerViewModel.swift
//  Ventus package
//
//  Created by Javier Fuchs on 08/01/26.
//  Copyright © 2026 Mobile Patagonia. All rights reserved.
//

#if !os(watchOS)
import Combine
import Foundation

/// Owns Windguru spot-picker data and service dependencies.
@MainActor
final class WindguruSpotPickerViewModel: ObservableObject {
    @Published var query = ""
    @Published var spots = [SpotOwner]()
    @Published var favoriteSpots = [SpotOwner]()
    @Published var isLoading = false
    @Published var isLoadingFavorites = false
    @Published var errorMessage: String?
    @Published var favoritesErrorMessage: String?
    @Published var favoriteIDsBeingRemoved = Set<String>()
    @Published var favoriteIDsBeingAdded = Set<String>()
    @Published var savedLocations: [SavedMapLocation]

    private let searchRequest: @MainActor (String) async throws -> SpotResult?
    private let spotInfoRequest: @MainActor (String) async throws -> SpotInfo?
    private let favoritesRequest: @MainActor (String, String) async throws -> SpotResult?
    private let removeFavoriteRequest: @MainActor (String, String, String) async throws -> WGSuccess?
    private let addFavoriteRequest: @MainActor (String, String, String) async throws -> WGSuccess?
    private let analytics: AnalyticsLogging
    private let savedMapLocationStore: SavedMapLocationStoring

    init(forecastService: ForecastWindguruProtocol, environment: AppEnvironment) {
        searchRequest = { try await forecastService.searchSpots(byLocation: $0) }
        spotInfoRequest = { try await forecastService.spotInfo(bySpotId: $0) }
        favoritesRequest = { try await forecastService.favoriteSpots(withUsername: $0, password: $1) }
        removeFavoriteRequest = { try await forecastService.removeFavoriteSpot(withSpotId: $0, username: $1, password: $2) }
        addFavoriteRequest = { try await forecastService.addFavoriteSpot(withSpotId: $0, username: $1, password: $2) }
        self.analytics = environment.analytics
        self.savedMapLocationStore = environment.savedMapLocationStore
        savedLocations = environment.savedMapLocationStore.load()
    }

    func searchSpots(_ query: String) async throws -> SpotResult? { try await searchRequest(query) }
    func spotInfo(_ spotID: String) async throws -> SpotInfo? { try await spotInfoRequest(spotID) }
    func favorites(username: String, password: String) async throws -> SpotResult? { try await favoritesRequest(username, password) }
    func removeFavorite(spotID: String, username: String, password: String) async throws -> WGSuccess? {
        defer { analytics.log(.favoriteRemoved(spotID: spotID)) }
        return try await removeFavoriteRequest(spotID, username, password)
    }
    func addFavorite(spotID: String, username: String, password: String) async throws -> WGSuccess? {
        defer { analytics.log(.favoriteAdded(spotID: spotID)) }
        return try await addFavoriteRequest(spotID, username, password)
    }

    func saveLocations() {
        savedMapLocationStore.save(savedLocations)
        savedLocations = savedMapLocationStore.load()
    }
}
#endif
