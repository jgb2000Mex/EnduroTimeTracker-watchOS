//
//  RaceData.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import Foundation
import Observation

/// Modelo para representar un Time Control
struct TimeControl: Identifiable, Codable {
    let id: UUID
    var name: String
    var scheduledTime: Date?  // Opcional para permitir "Select time"
    
    init(id: UUID = UUID(), name: String, scheduledTime: Date? = nil) {
        self.id = id
        self.name = name
        self.scheduledTime = scheduledTime
    }
}

/// Modelo para almacenar la configuración de la carrera
@Observable
class RaceConfiguration {
    var hasParcFerme: Bool = false
    var parcFermeTime: Date?
    var timeControls: [TimeControl] = []
    
    // Penalizaciones: array donde cada elemento corresponde al índice del control en getAllControls()
    // penalties[i] = minutos de penalización aplicados en el control i
    // Para obtener la penalización acumulada para el control i, se suman penalties[0] + ... + penalties[i]
    var penalties: [Int] = [] // Minutos de penalización por índice de control
    
    /// Verifica si hay al menos 2 Time Controls válidos (o PF + TC1 + TC2 si PF está ON)
    var isValid: Bool {
        if hasParcFerme {
            guard let _ = parcFermeTime else { return false }
            // Verificar que al menos 2 Time Controls tengan hora seleccionada
            let validTCs = timeControls.filter { $0.scheduledTime != nil }
            return validTCs.count >= 2
        } else {
            // Verificar que al menos 2 Time Controls tengan hora seleccionada
            let validTCs = timeControls.filter { $0.scheduledTime != nil }
            return validTCs.count >= 2
        }
    }
    
    /// Obtiene la penalización acumulada para un índice de control
    /// - Parameter index: Índice del control en getAllControls()
    /// - Returns: Minutos totales de penalización acumulados hasta ese índice (inclusive)
    func getAccumulatedPenalty(for index: Int) -> Int {
        guard index >= 0 && index < penalties.count else { return 0 }
        return penalties[0...index].reduce(0, +)
    }
    
    /// Verifica si hay penalizaciones aplicadas (positivas o negativas)
    var hasPenalties: Bool {
        return !penalties.isEmpty && penalties.contains { $0 != 0 }
    }
    
    /// Aplica una penalización en un índice específico
    /// - Parameters:
    ///   - minutes: Minutos de penalización a aplicar
    ///   - fromIndex: Índice desde el cual aplicar la penalización (inclusive)
    ///   - totalControls: Número total de controles (para inicializar el array si es necesario)
    func applyPenalty(minutes: Int, fromIndex: Int, totalControls: Int) {
        // Asegurar que el array tenga el tamaño correcto
        while penalties.count < totalControls {
            penalties.append(0)
        }
        
        // Aplicar la penalización en el índice especificado
        if fromIndex < penalties.count {
            penalties[fromIndex] += minutes
        }
    }
    
    /// Resetea toda la configuración de la carrera, borrando todos los tiempos
    func reset() {
        hasParcFerme = false
        parcFermeTime = nil
        penalties = []
        // Borrar todos los tiempos de los Time Controls, pero mantener los nombres
        for index in timeControls.indices {
            timeControls[index].scheduledTime = nil
        }
    }
}

