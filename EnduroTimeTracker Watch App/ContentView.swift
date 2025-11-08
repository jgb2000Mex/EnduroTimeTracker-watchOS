//
//  ContentView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var raceConfig = RaceConfiguration()
    @State private var currentView: AppView = .welcome
    
    enum AppView {
        case welcome
        case menu
        case timeTable
        case race
        case endOfRace
    }
    
    var body: some View {
        Group {
            switch currentView {
            case .welcome:
                WelcomeView(onStart: {
                    currentView = .menu
                })
                
            case .menu:
                MenuView(
                    raceConfig: raceConfig,
                    onTimeTable: {
                        currentView = .timeTable
                    },
                    onGo: {
                        currentView = .race
                    },
                    onExit: {
                        currentView = .welcome
                    }
                )
                
            case .timeTable:
                NavigationStack {
                    TimeTableView(
                        raceConfig: raceConfig,
                        onDone: {
                            currentView = .menu
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                
            case .race:
                NavigationStack {
                    RaceView(
                        raceConfig: raceConfig,
                        onBack: {
                            currentView = .menu
                        },
                        onRaceEnd: {
                            // Resetear toda la configuración de la carrera
                            raceConfig.reset()
                            // Volver al Welcome Screen
                            currentView = .welcome
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                
            case .endOfRace:
                EndOfRaceView(onDismiss: {
                    // Resetear toda la configuración de la carrera
                    raceConfig.reset()
                    // Volver al Welcome Screen
                    currentView = .welcome
                })
            }
        }
    }
}

#Preview {
    ContentView()
}
