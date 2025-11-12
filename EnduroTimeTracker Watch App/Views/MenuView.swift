//
//  MenuView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct MenuView: View {
    let raceConfig: RaceConfiguration
    
    var onTimeTable: () -> Void
    var onGo: () -> Void
    var onSettings: () -> Void
    var onExit: (() -> Void)?
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                onExit?() // Regresar al Welcome Screen
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient: from-blue-950 via-blue-900 to-blue-950
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.09, green: 0.145, blue: 0.229),  // blue-950
                    Color(red: 0.118, green: 0.227, blue: 0.441), // blue-900
                    Color(red: 0.09, green: 0.145, blue: 0.229)   // blue-950
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                // Espacio para el título estático
                Spacer()
                    .frame(height: 20)
                
                // Main Buttons Section
                VStack(spacing: .standardButtonSpacing) {
                    // Timetable Button
                    GlassButton(
                        icon: "calendar",
                        iconColor: Color(red: 0.976, green: 0.451, blue: 0.086),
                        text: "timetableButton".localized,
                        isEnabled: true,
                        action: onTimeTable
                    )
                    
                    // Race View Timer Button
                    GlassButton(
                        icon: "timer",
                        iconColor: Color(red: 0.976, green: 0.451, blue: 0.086),
                        text: "raceTimerButton".localized,
                        isEnabled: raceConfig.isValid,
                        action: onGo
                    )
                    
                    // Settings Button
                    GlassButton(
                        icon: "gearshape",
                        iconColor: Color(red: 0.976, green: 0.451, blue: 0.086),
                        text: "settingsButton".localized,
                        isEnabled: true,
                        action: onSettings
                    )
                }
                .padding(.horizontal, 8)
                
                Spacer()
                    .frame(minHeight: 20)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            
            // Overlay con degradado del fondo para cubrir el área del toolbar y desvanecer burbujas
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.09, green: 0.145, blue: 0.229),  // blue-950 opaco
                        Color(red: 0.09, green: 0.145, blue: 0.229).opacity(0.8), // ligeramente transparente
                        Color(red: 0.09, green: 0.145, blue: 0.229).opacity(0.0) // completamente transparente
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90) // Altura suficiente para cubrir toolbar + título
                .allowsHitTesting(false) // No interceptar toques
                
                Spacer()
            }
            .zIndex(1) // Por encima del ScrollView pero debajo del título y toolbar
            .ignoresSafeArea(.container, edges: .top) // Restaurar para que cubra el toolbar y desvanezca las burbujas
            
            
            // Header Section - Screen Title positioned below system clock (estático, fuera del ScrollView)
            VStack {
                HStack {
                    Spacer()
                    // Screen Title positioned to appear below system clock
                    Text("mainMenu".localized)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.3)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .offset(y: -15) // Offset más agresivo para compensar el NavigationStack
                        .padding(.trailing, 12)
                }
                .padding(.top, -10) // Padding más negativo para compensar el NavigationStack
                
                Spacer()
            }
            .zIndex(3) // Por encima del degradado y las burbujas
        }
        .toolbar(content: toolbarContent)
    }
}

// Custom Glass Button Component
struct GlassButton: View {
    let icon: String
    let iconColor: Color
    let text: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Content
                HStack {
                    // Left side: Icon and Text
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(isEnabled ? iconColor : Color.gray)
                            .frame(width: 22, height: 22)
                        
                        Text(text)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(isEnabled ? .white : .gray)
                            .minimumScaleFactor(0.7)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Right side: More button
                    Button(action: {
                        // More action
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                            
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
            }
        }
        .buttonStyle(GlassButtonStyle(isEnabled: isEnabled, height: .standardButtonHeight))
        .disabled(!isEnabled)
    }
}

#Preview {
    MenuView(
        raceConfig: RaceConfiguration(),
        onTimeTable: {},
        onGo: {},
        onSettings: {},
        onExit: nil
    )
}

