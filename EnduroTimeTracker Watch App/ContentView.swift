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
    @State private var isBackNavigation = false
    
    enum AppView {
        case welcome
        case warning
        case menu
        case timeTable
        case race
        case endOfRace
        case settings
    }
    
    private func navigate(to view: AppView, isBack: Bool = false) {
        isBackNavigation = isBack
        withAnimation(.easeInOut(duration: 0.3)) {
            currentView = view
        }
    }
    
    var body: some View {
        ZStack {
            // Welcome View
            if currentView == .welcome {
                WelcomeView(onStart: {
                    // Verificar si el usuario ya marcó "no volver a mostrar"
                    let warningDismissed = UserDefaults.standard.bool(forKey: "warningDismissed")
                    if warningDismissed {
                        navigate(to: .menu, isBack: false)
                    } else {
                        navigate(to: .warning, isBack: false)
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
                .zIndex(0)
            }
            
            // Warning View
            if currentView == .warning {
                WarningView(onDone: {
                    navigate(to: .menu, isBack: false)
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .zIndex(1)
            }
            
            // Menu View
            if currentView == .menu {
                NavigationStack {
                    MenuView(
                        raceConfig: raceConfig,
                        onTimeTable: {
                            navigate(to: .timeTable, isBack: false)
                        },
                        onGo: {
                            navigate(to: .race, isBack: false)
                        },
                        onSettings: {
                            navigate(to: .settings, isBack: false)
                        },
                        onExit: {
                            navigate(to: .welcome, isBack: true)
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .transition(isBackNavigation ? 
                    .asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ) :
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    )
                )
                .zIndex(2)
            }
            
            // Settings View
            if currentView == .settings {
                NavigationStack {
                    SettingsView(onBack: {
                        navigate(to: .menu, isBack: true)
                    })
                    .navigationBarTitleDisplayMode(.inline)
                }
                .transition(isBackNavigation ? 
                    .asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ) :
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    )
                )
                .zIndex(3)
            }
            
            // Time Table View
            if currentView == .timeTable {
                NavigationStack {
                    TimeTableView(
                        raceConfig: raceConfig,
                        onDone: {
                            navigate(to: .menu, isBack: true)
                        },
                        onGo: {
                            navigate(to: .race, isBack: false)
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .transition(isBackNavigation ? 
                    .asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ) :
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    )
                )
                .zIndex(4)
            }
            
            // Race View
            if currentView == .race {
                NavigationStack {
                    RaceView(
                        raceConfig: raceConfig,
                        onBack: {
                            navigate(to: .menu, isBack: true)
                        },
                        onRaceEnd: {
                            // Resetear toda la configuración de la carrera
                            raceConfig.reset()
                            // Volver al Welcome Screen
                            navigate(to: .welcome, isBack: false)
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .transition(isBackNavigation ? 
                    .asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ) :
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    )
                )
                .zIndex(5)
            }
            
            // End of Race View
            if currentView == .endOfRace {
                EndOfRaceView(onDismiss: {
                    // Resetear toda la configuración de la carrera
                    raceConfig.reset()
                    // Volver al Welcome Screen
                    navigate(to: .welcome, isBack: false)
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .zIndex(6)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentView)
    }
}

#Preview {
    ContentView()
}
