//
//  ForecastWindguruProtocol.swift
//  Ventus
//
//  Created by fox on 07/06/2023.
//

import Foundation

public protocol ForecastWindguruProtocol: Sendable {
    
    init()
    
    nonisolated(nonsending) func forecast(bySpotId spotId: String, model modelId: String?) async throws -> SpotForecast?
    nonisolated(nonsending) func wforecast(bySpotId spotId: String, model modelId: String?, username: String?, password: String?) async throws -> WSpotForecast?
    nonisolated(nonsending) func wforecast(byLatitude latitude: Double, longitude: Double, model modelId: String?, username: String, password: String) async throws -> WSpotForecast?
    nonisolated(nonsending) func spotInfo(bySpotId spotId: String) async throws -> SpotInfo?
    nonisolated(nonsending) func customSpots(withUsername username: String?, password: String?) async throws -> SpotResult?
    nonisolated(nonsending) func favoriteSpots(withUsername username: String?, password: String?) async throws -> SpotResult?
    nonisolated(nonsending) func setSpots(withUsername username: String?, password: String?) async throws -> SetResult?
    nonisolated(nonsending) func addSetSpots(withSetId setId: String?, username: String?, password: String?) async throws -> SpotResult?
    nonisolated(nonsending) func addFavoriteSpot(withSpotId spotId: String?, username: String?, password: String?) async throws -> WGSuccess?
    nonisolated(nonsending) func removeFavoriteSpot(withSpotId spotId: String?, username: String?, password: String?) async throws -> WGSuccess?
    nonisolated(nonsending) func searchSpots(byLocation location: String) async throws -> SpotResult?
    nonisolated(nonsending) func spots(withCountryId countryId: String?, regionId: String?) async throws -> SpotResult?
    nonisolated(nonsending) func modelInfo(onlyModelId modelId: String?) async throws -> Models?
    nonisolated(nonsending) func models(bylat lat: String?, lon: String?) async throws -> String?
    nonisolated(nonsending) func geoRegions() async throws -> GeoRegions?
    nonisolated(nonsending) func countries(byRegionId regionId: String?) async throws -> Countries?
    nonisolated(nonsending) func regions(byCountryId countryId: String?) async throws -> Regions?
    nonisolated(nonsending) func login(withUsername username: String?, password: String?) async throws -> User?
}

public extension ForecastWindguruProtocol {
    nonisolated(nonsending) func bestForecast(
        bySpotId spotId: String,
        model modelId: String? = nil,
        username: String? = nil,
        password: String? = nil
    ) async throws -> SpotForecast? {
        if let plainForecast = try? await forecast(bySpotId: spotId, model: modelId),
           !plainForecast.availableForecastHours.isEmpty,
           plainForecast.hasRealTemperatureData {
            return plainForecast
        }
        if let wForecast = try? await wforecast(bySpotId: spotId, model: modelId, username: username, password: password),
           let converted = try? SpotForecast.from(coordinateForecast: wForecast),
           !converted.availableForecastHours.isEmpty {
            return converted
        }
        return try await forecast(bySpotId: spotId, model: modelId)
    }
}
