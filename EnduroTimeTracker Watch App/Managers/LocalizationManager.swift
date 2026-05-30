//
//  LocalizationManager.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import Foundation
import SwiftUI
import Observation

/// Enum para representar los idiomas disponibles
enum AppLanguage: String, CaseIterable, Codable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }
}

/// Manager centralizado para manejar las traducciones de la app
@MainActor
@Observable
class LocalizationManager {
    static let shared = LocalizationManager()
    
    var currentLanguage: AppLanguage {
        didSet {
            // Guardar preferencia en UserDefaults
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    private init() {
        // Cargar idioma guardado o detectar idioma del dispositivo
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Detectar idioma del dispositivo
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            // Mapear códigos de idioma del dispositivo a nuestros idiomas
            switch deviceLanguage.prefix(2) {
            case "es":
                self.currentLanguage = .spanish
            case "fr":
                self.currentLanguage = .french
            case "de":
                self.currentLanguage = .german
            default:
                self.currentLanguage = .english
            }
        }
    }
    
    // MARK: - Diccionario de Traducciones
    
    private var translations: [String: [AppLanguage: String]] = [
        // WelcomeView
        "welcomeTo": [
            .english: "Welcome to",
            .spanish: "Hola!",
            .french: "",
            .german: ""
        ],
        "enduroTime": [
            .english: "Enduro Time",
            .spanish: "Enduro Time",
            .french: "",
            .german: ""
        ],
        "tracker": [
            .english: "Tracker",
            .spanish: "Tracker",
            .french: "",
            .german: ""
        ],
        "startButton": [
            .english: "Start",
            .spanish: "Iniciar",
            .french: "",
            .german: ""
        ],
        
        // MenuView
        "appName": [
            .english: "Enduro Time Tracker",
            .spanish: "Enduro Time Tracker",
            .french: "",
            .german: ""
        ],
        "mainMenu": [
            .english: "Main Menu",
            .spanish: "Menú Principal",
            .french: "",
            .german: ""
        ],
        "timetableButton": [
            .english: "Timetable",
            .spanish: "Tiempos Ideales",
            .french: "",
            .german: ""
        ],
        "raceTimerButton": [
            .english: "Race Timer",
            .spanish: "Cronómetro",
            .french: "",
            .german: ""
        ],
        "settingsButton": [
            .english: "Settings",
            .spanish: "Configuración",
            .french: "",
            .german: ""
        ],
        
        // SettingsView
        "settingsTitle": [
            .english: "Settings",
            .spanish: "Configuración",
            .french: "",
            .german: ""
        ],
        "changeLanguage": [
            .english: "Change Language",
            .spanish: "Cambiar Idioma",
            .french: "",
            .german: ""
        ],
        "version": [
            .english: "Version",
            .spanish: "Versión",
            .french: "",
            .german: ""
        ],
        "englishLanguage": [
            .english: "English",
            .spanish: "Inglés",
            .french: "",
            .german: ""
        ],
        "spanishLanguage": [
            .english: "Spanish",
            .spanish: "Español",
            .french: "",
            .german: ""
        ],
        "versionNumber": [
            .english: "Version 1.0",
            .spanish: "Versión 1.0",
            .french: "",
            .german: ""
        ],
        
        // TimeTableView
        "timetableTitle": [
            .english: "Timetable",
            .spanish: "Tiempos Ideales",
            .french: "",
            .german: ""
        ],
        "parcFerme": [
            .english: "Parc Ferme",
            .spanish: "Parque Cerrado",
            .french: "",
            .german: ""
        ],
        "parcFermeLabel": [
            .english: "Parc Ferme",
            .spanish: "Parque Cerrado",
            .french: "",
            .german: ""
        ],
        "selectTime": [
            .english: "Time",
            .spanish: "Hora",
            .french: "",
            .german: ""
        ],
        "chooseTime": [
            .english: "Choose Time",
            .spanish: "Selecciona Hora",
            .french: "",
            .german: ""
        ],
        "addTimeControl": [
            .english: "Add Time Control",
            .spanish: "Agregar Punto Control",
            .french: "",
            .german: ""
        ],
        "doneButton": [
            .english: "Done",
            .spanish: "Listo",
            .french: "",
            .german: ""
        ],
        "penaltyWarning": [
            .english: "Times in Red have been modified due to Penalty",
            .spanish: "Tiempos en Rojo fueron modificados por Penalización",
            .french: "",
            .german: ""
        ],
        "raceStart": [
            .english: "Race Start",
            .spanish: "Inicio Carrera",
            .french: "",
            .german: ""
        ],
        "raceFinish": [
            .english: "Race Finish",
            .spanish: "Fin de Carrera",
            .french: "",
            .german: ""
        ],
        "timeControlPrefix": [
            .english: "Time Control",
            .spanish: "Tiempo Ideal",
            .french: "",
            .german: ""
        ],
        "timeControlShort": [
            .english: "TC",
            .spanish: "TI",
            .french: "",
            .german: ""
        ],
        
        // RaceView
        "endOfRace": [
            .english: "End of Race",
            .spanish: "Carrera Finalizada",
            .french: "",
            .german: ""
        ],
        "timeLeftForParcFerme": [
            .english: "Time left for Parc Ferme",
            .spanish: "Tiempo para Ingresar Campo Cerrado",
            .french: "",
            .german: ""
        ],
        "timeLeftToBeginRace": [
            .english: "Time left to Begin Race",
            .spanish: "Tiempo para Comenzar Carrera",
            .french: "",
            .german: ""
        ],
        "timeLeftToFinishRace": [
            .english: "Time left to Finish Race",
            .spanish: "Tiempo para Terminar Carrera",
            .french: "",
            .german: ""
        ],
        "timeLeftForTC": [
            .english: "Time left for TC",
            .spanish: "Siguiente Tiempo Ideal",
            .french: "",
            .german: ""
        ],
        "timeToEnterParcFerme": [
            .english: "Time to enter Parc Ferme",
            .spanish: "Hora Ingreso Campo Cerrado",
            .french: "",
            .german: ""
        ],
        "timeOfRaceStart": [
            .english: "Time of Race Start",
            .spanish: "Hora Inicio Carrera",
            .french: "",
            .german: ""
        ],
        "timeOfRaceFinish": [
            .english: "Time of Race Finish",
            .spanish: "Hora Fin de Carrera",
            .french: "",
            .german: ""
        ],
        "timeOfTC": [
            .english: "Time of TC",
            .spanish: "Hora Tiempo Ideal",
            .french: "",
            .german: ""
        ],
        "lockScreenMessage": [
            .english: "Lock screen to prevent accidental touches",
            .spanish: "Bloquear pantalla para evitar modificaciones",
            .french: "",
            .german: ""
        ],
        "unlockMessage": [
            .english: "To unlock press screen 4 times",
            .spanish: "Para desbloquear toque 4 veces la pantalla",
            .french: "",
            .german: ""
        ],
        "penaltyConfirmationQuestion": [
            .english: "Need to Record a Penalty?",
            .spanish: "Requieres ingresar una penalización?",
            .french: "",
            .german: ""
        ],
        "yesButton": [
            .english: "YES",
            .spanish: "SÍ",
            .french: "",
            .german: ""
        ],
        "noButton": [
            .english: "NO",
            .spanish: "NO",
            .french: "",
            .german: ""
        ],
        "penaltyMinutes": [
            .english: "Penalty Minutes",
            .spanish: "Minutos de Penalización",
            .french: "",
            .german: ""
        ],
        "minutesLabel": [
            .english: "min",
            .spanish: "min",
            .french: "",
            .german: ""
        ],
        "goText": [
            .english: "GO!",
            .spanish: "GO!",
            .french: "",
            .german: ""
        ],
        
        // EndOfRaceView
        "dismissButton": [
            .english: "Dismiss",
            .spanish: "Cerrar",
            .french: "",
            .german: ""
        ],
        
        // WarningView
        "warningMessage": [
            .english: "Always keep a written backup copy of your times at hand",
            .spanish: "Siempre mantén tus tiempos por escrito a la mano como respaldo",
            .french: "",
            .german: ""
        ],
        "doNotShowAgain": [
            .english: "Do not show again",
            .spanish: "No volver a mostrar",
            .french: "",
            .german: ""
        ]
    ]
    
    // MARK: - Método para obtener traducción
    
    /// Obtiene la traducción para una clave específica en el idioma actual
    /// - Parameter key: La clave de la traducción
    /// - Returns: El texto traducido, o la clave si no se encuentra la traducción
    func localizedString(_ key: String) -> String {
        guard let languageTranslations = translations[key],
              let translation = languageTranslations[currentLanguage],
              !translation.isEmpty else {
            // Si no hay traducción en el idioma actual, intentar inglés como fallback
            if let englishTranslation = translations[key]?[.english], !englishTranslation.isEmpty {
                return englishTranslation
            }
            // Si tampoco hay en inglés, devolver la clave
            return key
        }
        return translation
    }
    
    /// Obtiene la traducción para una clave específica con formato dinámico
    /// - Parameters:
    ///   - key: La clave base de la traducción
    ///   - number: Número para insertar en la traducción (ej: "TC2")
    /// - Returns: El texto traducido con el número insertado
    func localizedString(_ key: String, with number: Int) -> String {
        let baseString = localizedString(key)
        // Reemplazar {n} con el número si existe en el formato
        return baseString.replacingOccurrences(of: "{n}", with: "\(number)")
    }
}

// MARK: - Extension para facilitar el uso en SwiftUI

extension String {
    /// Atajo para obtener una traducción localizada
    var localized: String {
        LocalizationManager.shared.localizedString(self)
    }
}

