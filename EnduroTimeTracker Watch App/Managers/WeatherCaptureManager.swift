//
//  WeatherCaptureManager.swift
//  EnduroTimeTracker Watch App
//

import Foundation
import CoreLocation
import HealthKit

struct WorkoutWeatherSnapshot {
    let temperatureCelsius: Double
    let humidityPercent: Double
    let condition: HKWeatherCondition
    
    var logDescription: String {
        "\(String(format: "%.0f", temperatureCelsius))°C, \(String(format: "%.0f", humidityPercent))% hum"
    }
}

/// Muestras de clima al inicio (TC1) y al final de la carrera.
struct WorkoutWeatherSamples {
    var atStart: WorkoutWeatherSnapshot?
    var atEnd: WorkoutWeatherSnapshot?
    
    /// Para Fitness: prioriza fin de carrera; si no hay, usa inicio TC1.
    var preferredForFitness: WorkoutWeatherSnapshot? {
        atEnd ?? atStart
    }
}

@MainActor
final class WeatherCaptureManager {
    static let shared = WeatherCaptureManager()
    
    private init() {}
    
    func fetchWeather(for location: CLLocation) async -> WorkoutWeatherSnapshot? {
        guard let forecast = await fetchForecast(for: location) else { return nil }
        
        return WorkoutWeatherSnapshot(
            temperatureCelsius: forecast.temperatureCelsius,
            humidityPercent: forecast.humidityPercent,
            condition: mapWMOCode(forecast.weatherCode)
        )
    }
    
    func healthKitMetadata(from snapshot: WorkoutWeatherSnapshot) -> [String: Any] {
        [
            HKMetadataKeyWeatherTemperature: HKQuantity(
                unit: .degreeCelsius(),
                doubleValue: snapshot.temperatureCelsius
            ),
            HKMetadataKeyWeatherHumidity: HKQuantity(
                unit: .percent(),
                doubleValue: snapshot.humidityPercent
            ),
            HKMetadataKeyWeatherCondition: NSNumber(value: snapshot.condition.rawValue),
            HKMetadataKeyTimeZone: TimeZone.current.identifier
        ]
    }
    
    private struct ForecastData {
        let temperatureCelsius: Double
        let humidityPercent: Double
        let weatherCode: Int
    }
    
    private func fetchForecast(for location: CLLocation) async -> ForecastData? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("⚠️ [Weather] Forecast HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            let decoded = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)
            guard let current = decoded.current,
                  let temp = current.temperature2m,
                  let humidity = current.relativeHumidity2m else {
                return nil
            }
            return ForecastData(
                temperatureCelsius: temp,
                humidityPercent: max(0, min(100, humidity)),
                weatherCode: current.weatherCode ?? 0
            )
        } catch {
            print("⚠️ [Weather] No se pudo obtener clima: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func mapWMOCode(_ code: Int) -> HKWeatherCondition {
        switch code {
        case 0, 1:
            return .clear
        case 2:
            return .partlyCloudy
        case 3:
            return .cloudy
        case 45, 48:
            return .foggy
        case 51, 53, 55:
            return .drizzle
        case 56, 57:
            return .freezingDrizzle
        case 61, 63, 65, 80, 81, 82:
            return .showers
        case 66, 67:
            return .freezingRain
        case 71, 73, 75, 77, 85, 86:
            return .snow
        case 95, 96, 99:
            return .thunderstorms
        default:
            return .none
        }
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature2m: Double?
        let relativeHumidity2m: Double?
        let weatherCode: Int?
        
        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case weatherCode = "weather_code"
        }
    }
    
    let current: Current?
}
