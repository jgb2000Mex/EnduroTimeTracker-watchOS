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
    var onExit: (() -> Void)?
    
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
                // Header Section - App Name positioned below system clock
                HStack {
                    Spacer()
                    // App Name positioned to appear below system clock
                    Text("Enduro Time Keeper")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                    // (Color(red: 0.976, green: 0.451, blue: 0.086)) // orange-500
                        .tracking(0.3)
                        .offset(y: -12) // Offset negativo para subir y quedar justo debajo del reloj
                        .padding(.trailing, 12)
                }
                .padding(.bottom, 12) // Más espacio antes de los botones
                
                // Main Buttons Section
                VStack(spacing: 12) {
                    // Timetable Button
                    GlassButton(
                        icon: "calendar",
                        iconColor: Color(red: 0.976, green: 0.451, blue: 0.086),
                        text: "Timetable",
                        isEnabled: true,
                        action: onTimeTable
                    )
                    
                    // Go! Button
                    GlassButton(
                        icon: "play.fill",
                        iconColor: Color(red: 0.976, green: 0.451, blue: 0.086),
                        text: "Go!",
                        isEnabled: raceConfig.isValid,
                        action: onGo
                    )
                }
                .padding(.horizontal, 8)
                
                Spacer()
                    .frame(minHeight: 20)
                
                // Bottom Exit Button - mismo color que los botones principales
                Button(action: {
                    if let onExit = onExit {
                        onExit()
                    } else {
                        exit(0)
                    }
                }) {
                    ZStack {
                        // Mismo estilo glass morphism que los botones principales
                        Circle()
                            .fill(
                                Material.ultraThinMaterial
                            )
                            .overlay(
                                // Mismo color gris que los botones principales
                                Circle()
                                    .fill(Color.gray.opacity(0.25))
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.white.opacity(0.4), // Mismo borde que los botones principales
                                        lineWidth: 1
                                    )
                            )
                            .overlay(
                                // Inner highlight gradient
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.clear
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .padding(1)
                            )
                            .shadow(
                                color: Color.black.opacity(0.4),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 25, weight: .light))
                            .foregroundColor(.yellow)
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
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
                // Main button background with glass effect (gris con sombra)
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        Material.ultraThinMaterial
                    )
                    .overlay(
                        // Color gris más pronunciado (gray-500/35)
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.gray.opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                Color.white.opacity(0.4), // border-gray-400/40
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        // Inner highlight gradient
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.2), // inset highlight
                                        Color.clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                
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
            .frame(height: 80)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

#Preview {
    MenuView(
        raceConfig: RaceConfiguration(),
        onTimeTable: {},
        onGo: {},
        onExit: nil
    )
}

