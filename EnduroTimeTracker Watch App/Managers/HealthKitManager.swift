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
    private var weatherSamples = WorkoutWeatherSamples()
    private var startWeatherFetchTask: Task<Void, Never>?
    private var lastFinalizedWorkout: HKWorkout?
    private var lastFinalizedWorkoutUUID: UUID?
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
        
        if let effortType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore) {
            types.insert(effortType)
        }
        
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
        
        if let effortType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore) {
            types.insert(effortType)
        }
        
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
            isAuthorized = true
            return true
        } catch {
            print("Error solicitando autorización de HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Workout Data Source
    
    // MARK: - Workout Configuration
    
    private func makeWorkoutConfiguration() -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor
        return configuration
    }
    
    private func configureWorkoutDataSource(for configuration: HKWorkoutConfiguration) -> HKLiveWorkoutDataSource {
        let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        // Evitar distancia del sensor del reloj; usamos distancia GPS calculada.
        if let distanceCycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            dataSource.disableCollection(for: distanceCycling)
        }
        if let distanceWalkingRunning = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            dataSource.disableCollection(for: distanceWalkingRunning)
        }
        return dataSource
    }
    
    // MARK: - Workout Session
    
    /// Pre-calienta sensores y deja la sesión en `.prepared` para una transición rápida a TC1.
    func prepareWorkoutSession() async {
        guard isAuthorized, !isWorkoutActive, !isPreparingWorkout else { return }
        if preparedSession != nil || isWorkoutSessionPrepared { return }
        
        isPreparingWorkout = true
        defer { isPreparingWorkout = false }
        
        let configuration = makeWorkoutConfiguration()
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = configureWorkoutDataSource(for: configuration)
            session.delegate = self
            builder.delegate = self
            
            try await waitForPreparedState(session: session)
            
            preparedSession = session
            preparedBuilder = builder
            isWorkoutSessionPrepared = true
            #if DEBUG
            print("✅ [Workout] Sesión preparada (lista para TC1)")
            #endif
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
            #if DEBUG
            print("⚠️ [Workout] startTime era futuro, ajustado a tiempo actual")
            #endif
        }
        
        #if DEBUG
        print("🚀 [Workout] Iniciando workout con startTime: \(actualStartTime)")
        #endif
        allLocations = []
        totalDistance = 0.0
        elevationGain = 0.0
        previousLocation = nil
        weatherSamples = WorkoutWeatherSamples()
        startWeatherFetchTask?.cancel()
        startWeatherFetchTask = nil
        
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
            let configuration = makeWorkoutConfiguration()
            
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session.associatedWorkoutBuilder()
            builder.dataSource = configureWorkoutDataSource(for: configuration)
            session.delegate = self
            builder.delegate = self
            
            try await waitForPreparedState(session: session)
        }
        
        session.startActivity(with: actualStartTime)
        try await waitForRunningState(session: session)
        
        workoutSession = session
        workoutBuilder = builder
        workoutStartTime = actualStartTime
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: actualStartTime) { success, error in
                if let error = error {
                    print("❌ [Workout] Error iniciando colección: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        startLocationTracking()
        isWorkoutActive = true
        print("✅ [Workout] Workout activo (GPS iniciado)")
    }
    
    func endWorkout(endTime: Date, effortScore: Int? = nil) async throws {
        try await finalizeWorkout(endTime: endTime)
        if let effortScore {
            try await addEffortScore(effortScore)
        }
        completeRaceWorkoutCleanup()
    }
    
    /// Guarda ruta, métricas y clima en Fitness en cuanto termina la carrera (antes de Effort / End of Race).
    @discardableResult
    func finalizeWorkout(endTime: Date) async throws -> HKWorkout {
        guard workoutSession != nil,
              let builder = workoutBuilder else {
            print("⚠️ [Workout] No hay workout activo para finalizar")
            throw HealthKitError.noActiveWorkout
        }
        
        guard isWorkoutActive else {
            print("⚠️ [Workout] El workout ya fue finalizado anteriormente")
            if let lastFinalizedWorkout {
                return lastFinalizedWorkout
            }
            throw HealthKitError.noActiveWorkout
        }
        
        print("🛑 [Workout] Guardando carrera en Fitness...")
        
        if let startWeatherFetchTask {
            print("⏳ [Weather] Esperando clima de inicio TC1...")
            await startWeatherFetchTask.value
        }
        
        endLocationTracking()
        calculateMetricsFromLocations()
        
        guard let workoutStart = workoutStartTime else {
            throw HealthKitError.noActiveWorkout
        }
        
        let routeLocations = routeLocationsForSaving(start: workoutStart, end: endTime)
        
        if let endLocation = routeLocations.last ?? allLocations.last {
            if let snapshot = await WeatherCaptureManager.shared.fetchWeather(for: endLocation) {
                weatherSamples.atEnd = snapshot
                print("✅ [Weather] Fin de carrera: \(snapshot.logDescription)")
            } else {
                print("⚠️ [Weather] No se pudo obtener clima al finalizar")
            }
        }
        
        if let start = weatherSamples.atStart {
            print("ℹ️ [Weather] Inicio TC1: \(start.logDescription)")
        }
        
        let durationMinutes = endTime.timeIntervalSince(workoutStart) / 60.0
        if let first = routeLocations.first?.timestamp, let last = routeLocations.last?.timestamp {
            print("🛑 [Workout] GPS: \(routeLocations.count) puntos ruta / \(allLocations.count) crudos, carrera \(String(format: "%.0f", durationMinutes)) min, ruta \(first) → \(last)")
        } else {
            print("🛑 [Workout] GPS: \(routeLocations.count) puntos ruta / \(allLocations.count) crudos, carrera \(String(format: "%.0f", durationMinutes)) min")
        }
        
        var samplesToAdd: [HKSample] = []
        
        if totalDistance > 0, let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: totalDistance)
            samplesToAdd.append(HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: workoutStart,
                end: endTime
            ))
        }
        
        let duration = endTime.timeIntervalSince(workoutStart)
        if duration > 0, totalDistance > 0,
           let speedType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) {
            let avgSpeed = totalDistance / duration
            samplesToAdd.append(HKQuantitySample(
                type: speedType,
                quantity: HKQuantity(unit: HKUnit.meter().unitDivided(by: HKUnit.second()), doubleValue: avgSpeed),
                start: workoutStart,
                end: endTime
            ))
        }
        
        if !samplesToAdd.isEmpty {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add(samplesToAdd) { _, error in
                    if let error {
                        print("⚠️ [Workout] Error agregando métricas: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var metadata: [String: Any] = [HKMetadataKeyIndoorWorkout: false]
            if let fitnessWeather = weatherSamples.preferredForFitness {
                metadata.merge(WeatherCaptureManager.shared.healthKitMetadata(from: fitnessWeather)) { _, new in new }
                let source = weatherSamples.atEnd != nil ? "fin de carrera" : "inicio TC1"
                print("✅ [Weather] Metadata Fitness (\(source)): \(fitnessWeather.logDescription)")
            } else {
                print("⚠️ [Weather] Sin metadata de clima para este workout")
            }
            builder.addMetadata(metadata) { _, error in
                if let error {
                    print("⚠️ [Workout] Error agregando metadata: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: endTime) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitError.noActiveWorkout
        }
        #if DEBUG
        print("✅ [Workout] Guardado \(workout.uuid)")
        if let savedDistance = workout.totalDistance {
            print("✅ [Workout] Distancia: \(String(format: "%.0f", savedDistance.doubleValue(for: .meter())))m")
        }
        #endif
        
        if routeLocations.count >= 2 {
            try await saveWorkoutRoute(for: workout, locations: routeLocations)
            #if DEBUG
            await verifySavedWorkoutRoute(for: workout)
            #endif
        } else {
            print("⚠️ [GPS] Insuficientes puntos GPS (\(routeLocations.count))")
        }
        
        lastFinalizedWorkout = workout
        lastFinalizedWorkoutUUID = workout.uuid
        print("✅ [Workout] Carrera guardada en Fitness (listo para esfuerzo opcional)")
        
        // La sesión sigue abierta hasta registrar esfuerzo o cerrar la carrera (mejora relateWorkoutEffortSample).
        workoutBuilder = nil
        workoutStartTime = nil
        isWorkoutActive = false
        
        allLocations = []
        totalDistance = 0.0
        elevationGain = 0.0
        previousLocation = nil
        weatherSamples = WorkoutWeatherSamples()
        startWeatherFetchTask = nil
        
        return workout
    }
    
    /// Añade esfuerzo al workout ya guardado; re-lee el workout desde HealthKit por UUID.
    func addEffortScore(_ score: Int) async throws {
        guard let uuid = lastFinalizedWorkoutUUID else {
            print("⚠️ [Workout] No hay workout guardado para registrar esfuerzo")
            throw HealthKitError.noSavedWorkoutForEffort
        }
        
        let workout = try await fetchWorkout(uuid: uuid)
        try await saveWorkoutEffortScore(score, for: workout)
        endWorkoutSessionIfNeeded()
    }
    
    /// Cierra sesión HK y referencias al salir de la carrera (Dismiss en End of Race).
    func completeRaceWorkoutCleanup() {
        endWorkoutSessionIfNeeded()
        lastFinalizedWorkout = nil
        lastFinalizedWorkoutUUID = nil
    }
    
    func clearFinalizedWorkoutReference() {
        completeRaceWorkoutCleanup()
    }
    
    private func endWorkoutSessionIfNeeded() {
        guard let session = workoutSession else { return }
        session.end()
        workoutSession = nil
        isWorkoutSessionRunning = false
        print("✅ [Workout] Sesión de workout cerrada")
    }
    
    private func fetchWorkout(uuid: UUID) async throws -> HKWorkout {
        let predicate = HKQuery.predicateForObject(with: uuid)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(throwing: HealthKitError.noSavedWorkoutForEffort)
                    return
                }
                continuation.resume(returning: workout)
            }
            healthStore.execute(query)
        }
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
    
    private func isCollectibleGPSLocation(_ location: CLLocation) -> Bool {
        guard location.coordinate.latitude != 0,
              location.coordinate.longitude != 0,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy < 200 else {
            return false
        }
        
        // Rechazar fixes en caché anteriores al workout (p. ej. al arrancar GPS en TC1).
        if let workoutStart = workoutStartTime,
           location.timestamp < workoutStart.addingTimeInterval(-30) {
            return false
        }
        
        // Rechazar timestamps claramente futuros.
        if location.timestamp.timeIntervalSinceNow > 10 {
            return false
        }
        
        return true
    }
    
    private func isRouteQualityGPSLocation(_ location: CLLocation) -> Bool {
        isCollectibleGPSLocation(location) && location.horizontalAccuracy <= 100
    }
    
    private func routeLocationsForSaving(start: Date, end: Date) -> [CLLocation] {
        allLocations
            .filter { isRouteQualityGPSLocation($0) }
            .filter { $0.timestamp >= start.addingTimeInterval(-30) && $0.timestamp <= end.addingTimeInterval(30) }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    private func saveWorkoutEffortScore(_ score: Int, for workout: HKWorkout) async throws {
        guard score >= 1, score <= 10,
              let effortType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore) else {
            return
        }
        
        let sample = HKQuantitySample(
            type: effortType,
            quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double(score)),
            start: workout.startDate,
            end: workout.endDate
        )
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.relateWorkoutEffortSample(sample, with: workout, activity: nil) { success, error in
                if let error {
                    print("⚠️ [Workout] Error guardando esfuerzo: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if success {
                    print("✅ [Workout] Esfuerzo registrado: \(score)/10")
                    continuation.resume()
                } else {
                    print("⚠️ [Workout] No se pudo relacionar esfuerzo con el workout")
                    continuation.resume(throwing: HealthKitError.effortSaveFailed)
                }
            }
        }
    }
    
    private func saveWorkoutRoute(for workout: HKWorkout, locations: [CLLocation]) async throws {
        print("🗺️ [GPS] Guardando ruta (\(locations.count) puntos)")
        
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            routeBuilder.insertRouteData(locations) { success, error in
                if let error {
                    print("❌ [GPS] Error insertRouteData: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.noActiveWorkout)
                }
            }
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            routeBuilder.finishRoute(with: workout, metadata: nil) { route, error in
                if let error {
                    print("❌ [GPS] Error finishRoute: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let route {
                    print("✅ [GPS] Ruta guardada: \(route.uuid)")
                    continuation.resume()
                } else {
                    print("⚠️ [GPS] finishRoute completó sin ruta")
                    continuation.resume(throwing: HealthKitError.noActiveWorkout)
                }
            }
        }
    }
    
    private func verifySavedWorkoutRoute(for workout: HKWorkout) async {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routeType = HKSeriesType.workoutRoute()
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    print("❌ [GPS] Verificación: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                guard let route = samples?.first as? HKWorkoutRoute else {
                    print("⚠️ [GPS] Verificación: ninguna ruta asociada al workout en HealthKit")
                    continuation.resume()
                    return
                }
                
                var pointCount = 0
                let routeQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                    if let error {
                        print("❌ [GPS] Verificación puntos: \(error.localizedDescription)")
                        if done { continuation.resume() }
                        return
                    }
                    pointCount += locations?.count ?? 0
                    if done {
                        print("✅ [GPS] Verificación: ruta \(route.uuid) con \(pointCount) puntos en HealthKit")
                        continuation.resume()
                    }
                }
                self.healthStore.execute(routeQuery)
            }
            self.healthStore.execute(query)
        }
    }
    
    private func startLocationTracking() {
        guard !isLocationTrackingActive else { return }
        guard hasLocationAuthorization else {
            print("⚠️ [GPS] Sin permiso de ubicación")
            return
        }
        
        isLocationTrackingActive = true
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.activityType = .fitness
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = kCLDistanceFilterNone
        locationManager?.startUpdatingLocation()
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
        case noSavedWorkoutForEffort
        case effortSaveFailed
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "HealthKit no está autorizado"
            case .noActiveWorkout:
                return "No hay una sesión de workout activa"
            case .healthKitNotAvailable:
                return "HealthKit no está disponible en este dispositivo"
            case .noSavedWorkoutForEffort:
                return "No se encontró el workout guardado para registrar esfuerzo"
            case .effortSaveFailed:
                return "No se pudo guardar el esfuerzo en HealthKit"
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            switch toState {
            case .prepared:
                isWorkoutSessionPrepared = true
                completePrepareContinuation()
            case .running:
                isWorkoutSessionPrepared = false
                isWorkoutSessionRunning = true
                completeRunningContinuation()
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
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

// MARK: - CLLocationManagerDelegate

extension HealthKitManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isLocationTrackingActive else { return }
        
        let validLocations = locations.filter { isCollectibleGPSLocation($0) }
        guard !validLocations.isEmpty else { return }
        
        allLocations.append(contentsOf: validLocations)
        if let last = validLocations.last {
            previousLocation = last
            captureStartWeatherIfNeeded(from: last)
        }
    }
    
    private func captureStartWeatherIfNeeded(from location: CLLocation) {
        guard isWorkoutActive, weatherSamples.atStart == nil, startWeatherFetchTask == nil else { return }
        
        startWeatherFetchTask = Task {
            if let snapshot = await WeatherCaptureManager.shared.fetchWeather(for: location) {
                weatherSamples.atStart = snapshot
                print("✅ [Weather] Inicio TC1: \(snapshot.logDescription)")
            } else {
                print("⚠️ [Weather] No se obtuvo clima al inicio TC1")
            }
        }
    }
    
    private func calculateMetricsFromLocations() {
        guard allLocations.count >= 2 else { return }
        
        totalDistance = 0.0
        elevationGain = 0.0
        
        for i in 1..<allLocations.count {
            let current = allLocations[i]
            let previous = allLocations[i - 1]
            
            totalDistance += current.distance(from: previous)
            
            let altitudeDiff = current.altitude - previous.altitude
            if abs(current.altitude) > 0.1, abs(previous.altitude) > 0.1, altitudeDiff > 1.0 {
                elevationGain += altitudeDiff
            }
        }
        
        #if DEBUG
        print("📊 [Metrics] \(String(format: "%.0f", totalDistance))m, elev +\(String(format: "%.0f", elevationGain))m, \(allLocations.count) pts")
        #endif
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            return
        }
        print("❌ [GPS] Error en location manager: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse,
           isWorkoutActive, isLocationTrackingActive {
            locationManager?.startUpdatingLocation()
        }
    }
}

