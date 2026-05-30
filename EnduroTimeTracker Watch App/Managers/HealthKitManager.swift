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

#if DEBUG
private enum HealthKitDiagnostics {
    static let verboseLogging = false
    static func log(_ message: @autoclosure () -> String) {
        guard verboseLogging else { return }
        print(message())
    }
}
#else
private enum HealthKitDiagnostics {
    static func log(_ message: @autoclosure () -> String) {}
}
#endif

@MainActor
class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var locationManager: CLLocationManager?
    private var authorizationLocationManager: CLLocationManager?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private var preparedSession: HKWorkoutSession?
    private var preparedBuilder: HKLiveWorkoutBuilder?
    private var isPreparingWorkout = false
    private var prepareContinuation: CheckedContinuation<Void, Error>?
    private var runningContinuation: CheckedContinuation<Void, Error>?
    
    @Published private(set) var isWorkoutSessionPrepared = false
    @Published private(set) var isWorkoutSessionRunning = false
    
    // Variables para calcular métricas desde GPS
    private var allLocations: [CLLocation] = []
    private var totalDistance: Double = 0.0 // en metros
    private var elevationGain: Double = 0.0 // en metros
    private var previousLocation: CLLocation?
    private var isLocationTrackingActive = false
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
    
    /// Pre-calienta sensores y deja la sesión en `.prepared` para una transición rápida a TC1.
    func prepareWorkoutSession() async {
        guard isAuthorized, !isWorkoutActive, !isPreparingWorkout else { return }
        if preparedSession != nil || isWorkoutSessionPrepared { return }
        
        isPreparingWorkout = true
        defer { isPreparingWorkout = false }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            
            try await waitForPreparedState(session: session)
            
            preparedSession = session
            preparedBuilder = builder
            isWorkoutSessionPrepared = true
            print("✅ [Workout] Sesión preparada (lista para TC1)")
        } catch {
            failPrepareContinuation(with: error)
            print("⚠️ [Workout] Error preparando sesión: \(error.localizedDescription)")
        }
    }
    
    private func waitForPreparedState(session: HKWorkoutSession) async throws {
        if session.state == .prepared {
            return
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            prepareContinuation = continuation
            session.prepare()
            
            if session.state == .prepared {
                prepareContinuation = nil
                continuation.resume()
            }
        }
    }
    
    private func failPrepareContinuation(with error: Error) {
        prepareContinuation?.resume(throwing: error)
        prepareContinuation = nil
    }
    
    private func completePrepareContinuation() {
        prepareContinuation?.resume()
        prepareContinuation = nil
    }
    
    private func completeRunningContinuation() {
        runningContinuation?.resume()
        runningContinuation = nil
    }
    
    private func failRunningContinuation(with error: Error) {
        runningContinuation?.resume(throwing: error)
        runningContinuation = nil
    }
    
    private func waitForRunningState(session: HKWorkoutSession) async throws {
        if session.state == .running {
            isWorkoutSessionRunning = true
            return
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            runningContinuation = continuation
            if session.state == .running {
                runningContinuation = nil
                isWorkoutSessionRunning = true
                continuation.resume()
            }
        }
    }
    
    func discardPreparedWorkoutSession() {
        guard workoutSession == nil, let session = preparedSession else { return }
        session.end()
        preparedSession = nil
        preparedBuilder = nil
        isWorkoutSessionPrepared = false
        isWorkoutSessionRunning = false
    }
    
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
        
        // Inicializar variables de métricas GPS
        allLocations = []
        totalDistance = 0.0
        elevationGain = 0.0
        previousLocation = nil
        
        let session: HKWorkoutSession
        let builder: HKLiveWorkoutBuilder
        
        if let prepared = preparedSession, let prepBuilder = preparedBuilder {
            session = prepared
            builder = prepBuilder
            preparedSession = nil
            preparedBuilder = nil
            isWorkoutSessionPrepared = false
            HealthKitDiagnostics.log("✅ [Workout] Usando sesión preparada")
        } else {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .cycling
            configuration.locationType = .outdoor
            
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            
            try await waitForPreparedState(session: session)
        }
        
        session.startActivity(with: actualStartTime)
        print("✅ [Workout] startActivity enviado; esperando .running...")
        
        try await waitForRunningState(session: session)
        print("✅ [Workout] Sesión en .running")
        
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
        
        // Iniciar GPS cuando la sesión de workout esté en ejecución (delegate)
        
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
            isWorkoutSessionRunning = false
            routeBuilder = nil
        }
        print("✅ [Workout] Workout completamente finalizado y limpiado")
    }
    
    // MARK: - Location Authorization
    
    /// Solicita permiso de ubicación una sola vez, antes de la carrera. Usa "While Using" — suficiente con HKWorkoutSession activo.
    func ensureLocationAuthorizationIfNeeded() {
        let status = CLLocationManager().authorizationStatus
        guard status == .notDetermined else { return }
        
        if authorizationLocationManager == nil {
            authorizationLocationManager = CLLocationManager()
        }
        authorizationLocationManager?.requestWhenInUseAuthorization()
    }
    
    private var hasLocationAuthorization: Bool {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Location Tracking (GPS)
    
    private func startLocationTracking() {
        guard !isLocationTrackingActive else { return }
        
        let authorizationStatus = CLLocationManager().authorizationStatus
        HealthKitDiagnostics.log("🚀 [GPS] Estado de autorización inicial: \(authorizationStatus.rawValue)")
        
        guard hasLocationAuthorization else {
            print("⚠️ [GPS] Sin permiso de ubicación; no se muestra diálogo en TC1 para evitar salir a carátula")
            return
        }
        
        isLocationTrackingActive = true
        HealthKitDiagnostics.log("🚀 [GPS] Iniciando GPS tracking...")
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager?.distanceFilter = 10.0
        
        routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        HealthKitDiagnostics.log("🚀 [GPS] RouteBuilder creado")
        
        locationManager?.startUpdatingLocation()
        HealthKitDiagnostics.log("🚀 [GPS] LocationManager iniciado")
    }
    
    private func endLocationTracking() {
        isLocationTrackingActive = false
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
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("🏃 [Workout] Estado \(fromState.rawValue) → \(toState.rawValue)")
        
        Task { @MainActor in
            switch toState {
            case .prepared:
                isWorkoutSessionPrepared = true
                completePrepareContinuation()
            case .running:
                isWorkoutSessionPrepared = false
                isWorkoutSessionRunning = true
                completeRunningContinuation()
                startLocationTracking()
            case .ended, .stopped:
                isWorkoutSessionPrepared = false
                isWorkoutSessionRunning = false
            default:
                break
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            print("Error en workout session: \(error.localizedDescription)")
            failPrepareContinuation(with: error)
            failRunningContinuation(with: error)
        }
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
        guard let routeBuilder = routeBuilder else {
            print("❌ [GPS] RouteBuilder no está disponible")
            return
        }
        
        let validLocations = locations.filter { location in
            let timeDiff = location.timestamp.timeIntervalSinceNow
            return location.coordinate.latitude != 0 &&
                   location.coordinate.longitude != 0 &&
                   location.horizontalAccuracy > 0 &&
                   location.horizontalAccuracy < 200 &&
                   timeDiff > -300
        }
        
        guard !validLocations.isEmpty else { return }
        
        for location in validLocations {
            if let previous = previousLocation {
                let distance = location.distance(from: previous)
                totalDistance += distance
                
                let currentAltitude = location.altitude
                let previousAltitude = previous.altitude
                
                if abs(currentAltitude) > 0.1 && abs(previousAltitude) > 0.1 {
                    let altitudeDiff = currentAltitude - previousAltitude
                    if altitudeDiff > 1.0 {
                        elevationGain += altitudeDiff
                    }
                }
            }
            
            previousLocation = location
            allLocations.append(location)
        }
        
        routeBuilder.insertRouteData(validLocations) { success, error in
            if let error = error {
                print("❌ [GPS] Error agregando ubicación al route: \(error.localizedDescription)")
            } else if !success {
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
        if let clError = error as? CLError, clError.code == .locationUnknown {
            return
        }
        print("❌ [GPS] Error en location manager: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        HealthKitDiagnostics.log("📍 [GPS] Estado de autorización cambiado: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if isWorkoutActive, isLocationTrackingActive {
                locationManager?.startUpdatingLocation()
            }
        case .denied:
            print("❌ [GPS] Autorización denegada")
        case .restricted:
            print("❌ [GPS] Autorización restringida")
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // No necesario para GPS tracking, pero puede ser útil para debugging
    }
}

