//
//  ExtendedRuntimeManager.swift
//  EnduroTimeTracker Watch App
//
//  Mantiene la app activa durante la espera pre-carrera (Parc Fermé → TC1)
//  antes de que HKWorkoutSession asuma el control en Race Start.
//

import Foundation
import Combine
import WatchKit

@MainActor
final class ExtendedRuntimeManager: NSObject, ObservableObject {
    static let shared = ExtendedRuntimeManager()
    
    private var session: WKExtendedRuntimeSession?
    private var shouldMaintainSession = false
    private var configurationUnavailable = false
    private var hasLoggedConfigurationError = false
    
    @Published private(set) var isActive = false
    
    private override init() {
        super.init()
    }
    
    /// Inicia o mantiene la sesión extendida durante Parc Fermé → TC1.
    func beginRaceCountdownSession() {
        guard !configurationUnavailable else { return }
        shouldMaintainSession = true
        startIfNeeded()
    }
    
    /// Handoff a HKWorkoutSession: solo termina extended runtime cuando el workout está completamente activo.
    func handoffToWorkoutSession() {
        guard shouldMaintainSession || isActive else { return }
        shouldMaintainSession = false
        stop(reason: "handoff a HKWorkoutSession")
    }
    
    /// Finaliza la sesión extendida al salir de RaceView o si falla el inicio del workout.
    func endRaceCountdownSession() {
        shouldMaintainSession = false
        stop(reason: "fin de countdown / salida de carrera")
    }
    
    private func startIfNeeded() {
        guard shouldMaintainSession, !configurationUnavailable else { return }
        
        if let session, session.state == .running {
            return
        }
        
        if session == nil || session?.state == .invalid {
            let newSession = WKExtendedRuntimeSession()
            newSession.delegate = self
            session = newSession
        }
        
        session?.start()
        #if DEBUG
        print("🟢 [ExtendedRuntime] Sesión solicitada")
        #endif
    }
    
    private func stop(reason: String) {
        guard let session else {
            isActive = false
            return
        }
        
        switch session.state {
        case .running, .scheduled:
            session.invalidate()
            print("🔴 [ExtendedRuntime] Sesión terminada (\(reason))")
        default:
            self.session = nil
            isActive = false
        }
    }
    
    private func handleConfigurationError(_ error: Error) {
        configurationUnavailable = true
        shouldMaintainSession = false
        session = nil
        isActive = false
        
        guard !hasLoggedConfigurationError else { return }
        hasLoggedConfigurationError = true
        print("⚠️ [ExtendedRuntime] Falta WKBackgroundModes en Info.plist: \(error.localizedDescription)")
    }
    
    private func isConfigurationError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("info plist") || message.contains("entitlement")
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension ExtendedRuntimeManager: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            isActive = true
        }
    }
    
    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            guard shouldMaintainSession, !configurationUnavailable else { return }
            session?.invalidate()
            session = nil
            isActive = false
            startIfNeeded()
        }
    }
    
    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            if session === extendedRuntimeSession {
                session = nil
            }
            isActive = false
            
            if let error, isConfigurationError(error) {
                handleConfigurationError(error)
                return
            }
            
            #if DEBUG
            if shouldMaintainSession {
                if let error {
                    print("⚠️ [ExtendedRuntime] Sesión invalidada (\(reason.rawValue)): \(error.localizedDescription)")
                } else {
                    print("⚠️ [ExtendedRuntime] Sesión invalidada (\(reason.rawValue))")
                }
            }
            #endif
            
            if shouldMaintainSession, !configurationUnavailable {
                startIfNeeded()
            }
        }
    }
}
