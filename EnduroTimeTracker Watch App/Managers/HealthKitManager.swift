//
//  HealthKitManager.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import Foundation
import HealthKit
import CoreLocation
import Combine

@MainActor
class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var locationManager: CLLocationManager?
    private var routeBuilder: HKWorkoutRouteBuilder?
    
    // Variables para calcular métricas desde GPS
    private var allLocations: [CLLocation] = []
    private var totalDistance: Double = 0.0 // en metros
    private var elevationGain: Double = 0.0 // en metros
    private var previousLocation: CLLocation?
    
    // Tipos de datos que necesitamos leer y escribir
    private let typesToShare: Set<HKSampleType> = {
        var types: Set<HKSampleType> = []
        
        // Workout
        types.insert(HKObjectType.workoutType())
        
        // Heart Rate
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        
        // Active Energy (Calories)
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energyType)
        }
        
        // Distance - usar distanceCycling para workouts outdoor (más apropiado que walkingRunning)
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(distanceType)
        }
        // También incluir distanceWalkingRunning como fallback
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distanceType)
        }
        
        // Elevation Gain - usar flightsClimbed (HealthKit no tiene elevationAscended como tipo de cantidad)
        // La elevation gain en metros se puede agregar como metadata
        if let elevationType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(elevationType)
        }
        
        // Average Speed
        if let speedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
            types.insert(speedType)
        }
        
        // Workout Route (GPS) - requiere también HKWorkoutType (ya incluido arriba)
        types.insert(HKSeriesType.workoutRoute())
        
        return types
    }()
    
    private let typesToRead: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        
        // Workout Type (requerido cuando se lee WorkoutRoute)
        types.insert(HKObjectType.workoutType())
        
        // Heart Rate
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        
        // Active Energy
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energyType)
        }
        
        // Distance
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(distanceType)
        }
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distanceType)
        }
        
        // Elevation
        if let elevationType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(elevationType)
        }
        
        // Speed
        if let speedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
            types.insert(speedType)
        }
        
        // Workout Route (GPS) - requiere también HKWorkoutType
        types.insert(HKSeriesType.workoutRoute())
        
        return types
    }()
    
    @Published var isAuthorized = false
    @Published var isWorkoutActive = false
    @Published var workoutStartTime: Date?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit no está disponible en este dispositivo")
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            await MainActor.run {
                isAuthorized = true
            }
            return true
        } catch {
            print("Error solicitando autorización de HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Workout Session
    
    func startWorkout(startTime: Date) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        // Asegurar que startTime no sea futuro (HealthKit no lo acepta)
        let now = Date()
        let actualStartTime = startTime > now ? now : startTime
        
        if startTime > now {
            print("⚠️ [Workout] startTime era futuro, ajustado a tiempo actual")
        }
        
        print("🚀 [Workout] Iniciando workout con startTime: \(actualStartTime)")
        
        // Crear configuración del workout
        // Usar .cycling para que la distancia aparezca en Fitness
        // Los workouts .other no muestran distancia en Fitness, aunque los datos estén guardados
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling // Cambiar a .cycling para que aparezca distancia
        configuration.locationType = .outdoor
        
        // Inicializar variables de métricas GPS
        allLocations = []
        totalDistance = 0.0
        elevationGain = 0.0
        previousLocation = nil
        
        // Crear y preparar la sesión
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        
        // Configurar el builder
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        
        // Iniciar la sesión
        session.delegate = self
        builder.delegate = self
        
        // Iniciar la sesión con el tiempo ajustado
        session.startActivity(with: actualStartTime)
        print("✅ [Workout] Sesión iniciada con startActivity")
        
        // Iniciar colección de datos con el tiempo ajustado
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: actualStartTime) { success, error in
                if let error = error {
                    print("❌ [Workout] Error iniciando colección de datos: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if success {
                    print("✅ [Workout] Colección de datos iniciada exitosamente")
                    continuation.resume()
                } else {
                    print("⚠️ [Workout] beginCollection completó pero success = false")
                    continuation.resume() // Continuar aunque haya advertencia
                }
            }
        }
        
        // Iniciar GPS tracking
        startLocationTracking()
        
        // Guardar referencias
        await MainActor.run {
            workoutSession = session
            workoutBuilder = builder
            workoutStartTime = actualStartTime // Guardar el tiempo ajustado
            isWorkoutActive = true
        }
        print("✅ [Workout] Workout completamente inicializado y activo")
    }
    
    func endWorkout(endTime: Date) async throws {
        guard let session = workoutSession,
              let builder = workoutBuilder else {
            print("⚠️ [Workout] No hay workout activo para finalizar")
            throw HealthKitError.noActiveWorkout
        }
        
        // Verificar que el workout esté activo antes de finalizar
        guard isWorkoutActive else {
            print("⚠️ [Workout] El workout ya fue finalizado anteriormente")
            throw HealthKitError.noActiveWorkout
        }
        
        print("🛑 [Workout] Iniciando finalización del workout...")
        
        // Finalizar GPS tracking PRIMERO (antes de finalizar el workout)
        endLocationTracking()
        print("🛑 [Workout] GPS tracking finalizado")
        
        // Calcular métricas finales desde las ubicaciones GPS ANTES de finalizar la colección
        calculateMetricsFromLocations()
        
        // Agregar métricas calculadas al workout builder ANTES de finalizar la colección
        guard let workoutStart = workoutStartTime else {
            print("⚠️ [Workout] No hay workoutStartTime, usando endTime - 1 hora como fallback")
            throw HealthKitError.noActiveWorkout
        }
        
        var samplesToAdd: [HKSample] = []
        
        // Agregar distancia total al workout
        // Para workouts .cycling, usar distanceCycling es obligatorio
        if totalDistance > 0 {
            if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
                let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: totalDistance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: workoutStart,
                    end: endTime
                )
                samplesToAdd.append(distanceSample)
                print("📊 [Workout] Preparando distancia (Cycling): \(String(format: "%.2f", totalDistance))m (\(String(format: "%.2f", totalDistance / 1000.0))km)")
            } else {
                print("⚠️ [Workout] No se pudo crear distanceCycling type")
            }
        }
        
        // NOTA: HealthKit no tiene un tipo de cantidad para elevation gain en metros
        // La elevation gain se debe agregar como metadata del workout, no como muestra
        // Sin embargo, para que aparezca en Fitness, necesitamos usar el tipo correcto
        // Por ahora, no agregamos elevation gain como muestra separada
        // Se agregará como metadata después de finalizar el workout
        if elevationGain > 0 {
            print("📊 [Workout] Elevation gain calculado: \(String(format: "%.2f", elevationGain))m (se agregará como metadata)")
        }
        
        // Calcular y agregar velocidad promedio
        let duration = endTime.timeIntervalSince(workoutStart)
        if duration > 0 && totalDistance > 0 {
            let avgSpeedMetersPerSecond = totalDistance / duration
            if let speedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
                let speedQuantity = HKQuantity(unit: HKUnit.meter().unitDivided(by: HKUnit.second()), doubleValue: avgSpeedMetersPerSecond)
                let speedSample = HKQuantitySample(
                    type: speedType,
                    quantity: speedQuantity,
                    start: workoutStart,
                    end: endTime
                )
                samplesToAdd.append(speedSample)
                let avgSpeedKmh = avgSpeedMetersPerSecond * 3.6
                print("📊 [Workout] Preparando velocidad promedio: \(String(format: "%.2f", avgSpeedKmh)) km/h")
            }
        }
        
        // Agregar todas las muestras al builder antes de finalizar la colección
        if !samplesToAdd.isEmpty {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add(samplesToAdd) { success, error in
                    if let error = error {
                        print("⚠️ [Workout] Error agregando métricas: \(error.localizedDescription)")
                        continuation.resume() // Continuar aunque haya error
                    } else if success {
                        print("✅ [Workout] Todas las métricas agregadas exitosamente")
                        continuation.resume()
                    } else {
                        print("⚠️ [Workout] add completó pero success = false")
                        continuation.resume()
                    }
                }
            }
        }
        
        // Finalizar colección de datos ANTES de finalizar la sesión
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: endTime) { success, error in
                if let error = error {
                    print("❌ [Workout] Error finalizando colección: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if success {
                    print("✅ [Workout] Colección de datos finalizada")
                    continuation.resume()
                } else {
                    print("⚠️ [Workout] endCollection completó pero success = false")
                    continuation.resume() // Continuar aunque haya advertencia
                }
            }
        }
        
        // IMPORTANTE: Agregar la distancia directamente al workout usando totalDistance
        // Esto asegura que aparezca en la app Fitness
        // El builder calcula automáticamente la distancia desde las muestras agregadas,
        // pero también podemos asegurarnos agregándola explícitamente
        
        // Finalizar el workout builder - esto guarda el workout automáticamente
        // La distancia debería calcularse automáticamente desde las muestras agregadas
        print("🛑 [Workout] Finalizando workout builder...")
        print("🛑 [Workout] Distancia total calculada: \(String(format: "%.2f", totalDistance))m")
        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitError.noActiveWorkout
        }
        print("✅ [Workout] Workout builder finalizado y guardado automáticamente")
        print("✅ [Workout] Workout UUID: \(workout.uuid)")
        print("✅ [Workout] Workout start: \(workout.startDate), end: \(workout.endDate)")
        
        // Verificar si la distancia se guardó correctamente
        if let savedDistance = workout.totalDistance {
            let distanceInMeters = savedDistance.doubleValue(for: HKUnit.meter())
            print("✅ [Workout] Distancia guardada en workout: \(String(format: "%.2f", distanceInMeters))m")
        } else {
            print("⚠️ [Workout] La distancia NO se guardó en el workout - esto puede ser un problema")
        }
        
        // Finalizar la sesión DESPUÉS de finishWorkout
        session.end()
        print("✅ [Workout] Sesión finalizada")
        
        // Actualizar el workout con metadata personalizado (nombre "Enduro Time Tracker")
        // HealthKit permite actualizar metadata después de guardar usando HKAnchoredObjectQuery
        // Pero la forma más simple es crear un nuevo workout con el mismo UUID y metadata actualizado
        // Sin embargo, esto puede crear duplicados. Intentemos usar el workout original con metadata.
        
        // IMPORTANTE: Asociar la ruta GPS al workout original que ya está guardado
        // NO vamos a crear un workout nuevo porque eso rompería la asociación de la ruta GPS
        // El workout se guardará como "Other" pero con la ruta GPS correctamente asociada
        if let routeBuilder = routeBuilder {
            print("🗺️ [GPS] Finalizando ruta GPS con workout guardado...")
            print("🗺️ [GPS] Asociando ruta al workout UUID: \(workout.uuid)")
            print("🗺️ [GPS] Workout start: \(workout.startDate), end: \(workout.endDate)")
            
            // Asociar la ruta al workout original (el que ya está guardado por finishWorkout)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                routeBuilder.finishRoute(with: workout, metadata: nil) { route, error in
                    if let error = error {
                        print("❌ [GPS] Error finalizando ruta GPS: \(error.localizedDescription)")
                        print("❌ [GPS] Detalles del error: \(error)")
                        continuation.resume()
                    } else if route != nil {
                        print("✅ [GPS] Ruta GPS guardada exitosamente y asociada al workout")
                        print("✅ [GPS] Route UUID: \(route!.uuid)")
                        print("✅ [GPS] Route asociado al workout UUID: \(workout.uuid)")
                        print("✅ [GPS] La ruta GPS debería aparecer en la app Fitness")
                        continuation.resume()
                    } else {
                        print("⚠️ [GPS] finishRoute completó pero no se retornó ruta")
                        print("⚠️ [GPS] Esto puede indicar que no se guardaron ubicaciones en el routeBuilder")
                        print("⚠️ [GPS] Verifica que se hayan recibido ubicaciones durante el workout")
                        continuation.resume()
                    }
                }
            }
        } else {
            print("⚠️ [GPS] No hay routeBuilder para finalizar")
        }
        
        // Agregar elevation gain como metadata (HealthKit no tiene tipo de cantidad para esto)
        // NOTA: La app Fitness puede no mostrar este metadata, pero quedará guardado
        let existingMetadata = workout.metadata ?? [:]
        // Filtrar claves privadas
        let filteredMetadata = existingMetadata.filter { key, _ in
            !key.hasPrefix("_") && !key.hasPrefix("HKPrivate")
        }
        var updatedMetadata = filteredMetadata
        // Intentar agregar nombre personalizado (puede que no funcione para .cycling)
        updatedMetadata[HKMetadataKeyWorkoutBrandName] = "Enduro Time Tracker"
        updatedMetadata["HKWorkoutActivityName"] = "Enduro Time Tracker"
        
        // NOTA IMPORTANTE: Para workouts .cycling, HealthKit/Fitness calcula automáticamente
        // el elevation gain desde el GPS track (las altitudes de las ubicaciones en la ruta).
        // No hay un tipo de cantidad específico para elevation gain que podamos agregar manualmente.
        // 
        // El elevation gain aparecerá en Fitness si:
        // 1. Las ubicaciones GPS tienen altitudes válidas (no 0)
        // 2. Hay cambios significativos de altitud durante el workout
        // 3. El GPS está capturando altitudes correctamente
        //
        // Agregamos el elevation gain calculado como metadata para referencia,
        // pero Fitness lo calculará automáticamente desde el GPS track.
        if elevationGain > 0 {
            updatedMetadata["ElevationGain"] = elevationGain // en metros
            print("📊 [Workout] Elevation gain calculado: \(String(format: "%.2f", elevationGain))m")
            print("📊 [Workout] NOTA: Fitness calculará elevation gain automáticamente desde el GPS track")
            print("📊 [Workout] Si no aparece, verifica que las ubicaciones GPS tengan altitudes válidas")
        } else {
            print("⚠️ [Workout] Elevation gain = 0m")
            print("⚠️ [Workout] Esto puede ser porque:")
            print("  - No hubo cambios significativos de altitud durante el workout")
            print("  - Las altitudes GPS no están disponibles (ver logs de altitudes arriba)")
            print("  - El GPS no está capturando altitudes correctamente")
        }
        
        // NOTA: El workout se guardará como "Outdoor Cycle" (tipo .cycling)
        // Esto es necesario para que la distancia aparezca en Fitness
        // El nombre personalizado puede no aplicarse, pero los datos estarán completos
        print("ℹ️ [Workout] Workout guardado como 'Outdoor Cycle' (.cycling) para que aparezca distancia")
        print("ℹ️ [Workout] Todos los datos están guardados: distancia, elevation, velocidad, GPS track")
        
        // Si en el futuro queremos intentar actualizar el nombre, podríamos usar:
        // - HKAnchoredObjectQuery para leer el workout
        // - Eliminar el workout original
        // - Crear uno nuevo con metadata actualizado
        // Pero esto es complejo y puede causar problemas con la ruta GPS asociada
        
        // Limpiar variables de métricas GPS
        allLocations = []
        totalDistance = 0.0
        elevationGain = 0.0
        previousLocation = nil
        
        // Limpiar referencias SOLO después de que todo se haya guardado correctamente
        await MainActor.run {
            workoutSession = nil
            workoutBuilder = nil
            workoutStartTime = nil
            isWorkoutActive = false
            routeBuilder = nil
        }
        print("✅ [Workout] Workout completamente finalizado y limpiado")
    }
    
    // MARK: - Location Tracking (GPS)
    
    private func startLocationTracking() {
        print("🚀 [GPS] Iniciando GPS tracking...")
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        // Usar un filtro de distancia más pequeño (2 metros) para mejor conexión de puntos GPS
        // Esto ayuda a que el mapa muestre una línea más continua sin gaps
        locationManager?.distanceFilter = 2.0 // 2 metros - mejor conexión de puntos en el mapa
        
        // Solicitar autorización para usar ubicación siempre (necesario para workouts)
        let authorizationStatus = locationManager?.authorizationStatus ?? .notDetermined
        print("🚀 [GPS] Estado de autorización inicial: \(authorizationStatus.rawValue)")
        
        if authorizationStatus == .notDetermined {
            print("🚀 [GPS] Solicitando autorización 'Always'...")
            locationManager?.requestAlwaysAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse {
            // Si solo tenemos "when in use", intentar solicitar "always" para workout
            print("🚀 [GPS] Solicitando upgrade a 'Always'...")
            locationManager?.requestAlwaysAuthorization()
        }
        
        // Crear route builder ANTES de iniciar actualizaciones de ubicación
        routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        print("🚀 [GPS] RouteBuilder creado")
        
        // Solicitar una ubicación inicial inmediata
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            print("🚀 [GPS] Solicitando ubicación inicial...")
            locationManager?.requestLocation()
        }
        
        // Iniciar actualizaciones continuas de ubicación
        locationManager?.startUpdatingLocation()
        print("🚀 [GPS] LocationManager iniciado - Actualizaciones continuas activadas")
    }
    
    private func endLocationTracking() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
    }
    
    // MARK: - Error Types
    
    enum HealthKitError: LocalizedError {
        case notAuthorized
        case noActiveWorkout
        case healthKitNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "HealthKit no está autorizado"
            case .noActiveWorkout:
                return "No hay una sesión de workout activa"
            case .healthKitNotAvailable:
                return "HealthKit no está disponible en este dispositivo"
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Manejar cambios de estado de la sesión
        print("Workout session cambió de \(fromState) a \(toState) en \(date)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Error en workout session: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Los datos se están recolectando automáticamente
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Eventos del workout
    }
}

// MARK: - CLLocationManagerDelegate

extension HealthKitManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("📍 [GPS] didUpdateLocations llamado con \(locations.count) ubicaciones")
        
        guard let routeBuilder = routeBuilder else {
            print("❌ [GPS] RouteBuilder no está disponible")
            return
        }
        
        // Filtrar ubicaciones válidas (con coordenadas válidas y precisión razonable)
        // Usar un umbral de precisión balanceado (200m) para capturar suficientes ubicaciones
        // mientras mantenemos calidad razonable del track GPS
        // NOTA: 100m era demasiado estricto y rechazaba muchas ubicaciones válidas
        let validLocations = locations.filter { location in
            let timeDiff = location.timestamp.timeIntervalSinceNow
            let isValid = location.coordinate.latitude != 0 &&
                         location.coordinate.longitude != 0 &&
                         location.horizontalAccuracy > 0 &&
                         location.horizontalAccuracy < 200 && // 200m - balance entre calidad y cantidad
                         timeDiff > -300 // Solo ubicaciones de los últimos 5 minutos
            
            if !isValid {
                // Solo loguear ubicaciones inválidas si la precisión es muy mala (>500m) para no saturar logs
                if location.horizontalAccuracy >= 200 {
                    print("  ⚠️ Ubicación rechazada: Accuracy=\(String(format: "%.1f", location.horizontalAccuracy))m (umbral: 200m)")
                }
            }
            
            return isValid
        }
        
        guard !validLocations.isEmpty else {
            print("⚠️ [GPS] No hay ubicaciones válidas para agregar. Total recibidas: \(locations.count)")
            if locations.count > 0 {
                locations.forEach { loc in
                    let timeDiff = loc.timestamp.timeIntervalSinceNow
                    print("  - Lat: \(loc.coordinate.latitude), Lon: \(loc.coordinate.longitude), Accuracy: \(loc.horizontalAccuracy)m, Time: \(Int(timeDiff))s ago")
                }
            }
            return
        }
        
        // Calcular métricas desde las ubicaciones
        for location in validLocations {
            // Calcular distancia desde la ubicación anterior
            if let previous = previousLocation {
                let distance = location.distance(from: previous)
                totalDistance += distance
                
                // Calcular elevation gain
                // Mejorar el cálculo: aceptar altitudes válidas (pueden ser negativas en algunos lugares)
                // y filtrar cambios muy pequeños que pueden ser ruido del GPS
                let currentAltitude = location.altitude
                let previousAltitude = previous.altitude
                
                // Verificar que ambas altitudes sean válidas (no 0, que indica "no disponible")
                // y que la diferencia vertical sea significativa (mínimo 1 metro para filtrar ruido)
                if abs(currentAltitude) > 0.1 && abs(previousAltitude) > 0.1 {
                    let altitudeDiff = currentAltitude - previousAltitude
                    // Solo contar aumentos de altitud (elevation gain)
                    // Filtrar cambios menores a 1 metro para reducir ruido del GPS
                    if altitudeDiff > 1.0 {
                        elevationGain += altitudeDiff
                        print("  📈 Elevation gain: +\(String(format: "%.2f", altitudeDiff))m (de \(String(format: "%.1f", previousAltitude))m a \(String(format: "%.1f", currentAltitude))m)")
                    } else if altitudeDiff < -1.0 {
                        // Log de descensos para debugging
                        print("  📉 Elevation loss: \(String(format: "%.2f", altitudeDiff))m")
                    }
                } else {
                    // Log cuando las altitudes no están disponibles
                    if abs(currentAltitude) <= 0.1 {
                        print("  ⚠️ Altitud no disponible en ubicación actual")
                    }
                }
            }
            
            // Guardar ubicación para cálculos futuros
            previousLocation = location
            allLocations.append(location)
        }
        
        print("📍 [GPS] Agregando \(validLocations.count) ubicaciones válidas al route")
        print("📍 [GPS] Métricas acumuladas: Distancia=\(String(format: "%.2f", totalDistance))m, Elevation Gain=\(String(format: "%.2f", elevationGain))m")
        // Solo loguear detalles si hay pocas ubicaciones o en modo debug
        if validLocations.count <= 5 {
            validLocations.forEach { loc in
                print("  ✓ Lat: \(loc.coordinate.latitude), Lon: \(loc.coordinate.longitude), Accuracy: \(loc.horizontalAccuracy)m, Altitude: \(loc.altitude)m")
            }
        } else {
            // Para muchas ubicaciones, solo loguear resumen
            let avgAccuracy = validLocations.map { $0.horizontalAccuracy }.reduce(0, +) / Double(validLocations.count)
            print("  ✓ \(validLocations.count) ubicaciones, precisión promedio: \(String(format: "%.1f", avgAccuracy))m")
        }
        
        // Agregar ubicaciones al route builder
        routeBuilder.insertRouteData(validLocations) { success, error in
            if let error = error {
                print("❌ [GPS] Error agregando ubicación al route: \(error.localizedDescription)")
            } else if success {
                print("✅ [GPS] \(validLocations.count) ubicaciones agregadas exitosamente al route")
            } else {
                print("⚠️ [GPS] insertRouteData completó pero success = false")
            }
        }
    }
    
    // MARK: - Metrics Calculation
    
    private func calculateMetricsFromLocations() {
        guard allLocations.count >= 2 else {
            print("⚠️ [Metrics] No hay suficientes ubicaciones para calcular métricas")
            return
        }
        
        // Recalcular métricas desde todas las ubicaciones guardadas
        totalDistance = 0.0
        elevationGain = 0.0
        
        for i in 1..<allLocations.count {
            let current = allLocations[i]
            let previous = allLocations[i-1]
            
            // Calcular distancia
            let distance = current.distance(from: previous)
            totalDistance += distance
            
            // Calcular elevation gain
            // Mejorar el cálculo: aceptar altitudes válidas y filtrar ruido
            let currentAltitude = current.altitude
            let previousAltitude = previous.altitude
            
            if abs(currentAltitude) > 0.1 && abs(previousAltitude) > 0.1 {
                let altitudeDiff = currentAltitude - previousAltitude
                // Solo contar aumentos de altitud (elevation gain)
                // Filtrar cambios menores a 1 metro para reducir ruido del GPS
                if altitudeDiff > 1.0 {
                    elevationGain += altitudeDiff
                }
            }
        }
        
        print("📊 [Metrics] Métricas finales calculadas:")
        print("  - Distancia total: \(String(format: "%.2f", totalDistance))m (\(String(format: "%.2f", totalDistance / 1000.0))km)")
        print("  - Elevation gain: \(String(format: "%.2f", elevationGain))m")
        
        // Diagnosticar altitudes recibidas
        if !allLocations.isEmpty {
            let altitudes = allLocations.compactMap { $0.altitude != 0 ? $0.altitude : nil }
            if !altitudes.isEmpty {
                let minAltitude = altitudes.min() ?? 0
                let maxAltitude = altitudes.max() ?? 0
                let avgAltitude = altitudes.reduce(0, +) / Double(altitudes.count)
                print("  - Altitudes GPS: min=\(String(format: "%.1f", minAltitude))m, max=\(String(format: "%.1f", maxAltitude))m, avg=\(String(format: "%.1f", avgAltitude))m")
                print("  - Ubicaciones con altitud válida: \(altitudes.count)/\(allLocations.count)")
            } else {
                print("  ⚠️ No se recibieron altitudes válidas del GPS")
                print("  ⚠️ Esto puede ser porque el GPS no tiene señal de altitud o el dispositivo no la está capturando")
            }
        }
        
        if let startTime = workoutStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration > 0 {
                let avgSpeedMps = totalDistance / duration
                let avgSpeedKmh = avgSpeedMps * 3.6
                print("  - Velocidad promedio: \(String(format: "%.2f", avgSpeedKmh)) km/h")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [GPS] Error en location manager: \(error.localizedDescription)")
        if let clError = error as? CLError {
            print("  - Código de error: \(clError.code.rawValue)")
            print("  - Descripción: \(clError.localizedDescription)")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("📍 [GPS] Estado de autorización cambiado: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            print("✅ [GPS] Autorización 'Always' concedida")
            locationManager?.requestLocation()
            locationManager?.startUpdatingLocation()
        case .authorizedWhenInUse:
            print("✅ [GPS] Autorización 'WhenInUse' concedida")
            locationManager?.requestLocation()
            locationManager?.startUpdatingLocation()
        case .denied:
            print("❌ [GPS] Autorización denegada")
        case .restricted:
            print("❌ [GPS] Autorización restringida")
        case .notDetermined:
            print("⚠️ [GPS] Autorización aún no determinada")
        @unknown default:
            print("⚠️ [GPS] Estado de autorización desconocido")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // No necesario para GPS tracking, pero puede ser útil para debugging
    }
}

