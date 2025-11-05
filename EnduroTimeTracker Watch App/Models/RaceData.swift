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
}

