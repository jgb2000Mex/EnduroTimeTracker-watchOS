//
//  SettingsView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    let localizationManager = LocalizationManager.shared
    var onBack: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            // Header Section - Title positioned below system clock (estático, fuera del ScrollView)
            VStack {
                HStack {
                    Spacer()
                    // Title positioned to appear below system clock
                    Text("settingsTitle".localized)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.3)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .offset(y: -15) // Offset más agresivo para compensar el espacio del NavigationStack
                        .padding(.trailing, 12)
                }
                .padding(.top, -10) // Padding más negativo para compensar el espacio del NavigationStack
                
                Spacer()
            }
            .zIndex(2) // Asegurar que el título esté por encima de las burbujas
            
            ScrollView {
                VStack(spacing: 0) {
                    // Espacio para el título estático
                    Spacer()
                        .frame(height: 20)
                    
                    VStack(spacing: .standardButtonSpacing) {
                        // Change Language Button
                        NavigationLink(destination: LanguageSelectionView()) {
                            ZStack {
                                // Content
                                HStack {
                                    HStack(spacing: 10) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundColor(Color(red: 0.976, green: 0.451, blue: 0.086))
                                            .frame(width: 22, height: 22)
                                        
                                        Text("changeLanguage".localized)
                                            .font(.system(size: 16, weight: .regular, design: .rounded))
                                            .foregroundColor(.white)
                                            .minimumScaleFactor(0.7)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 12)
                            }
                            .frame(height: .standardButtonHeight)
                            .background(glassButtonBackground)
                        }
                        .buttonStyle(PlainButtonStyle())
                
                // Version Button
                NavigationLink(destination: VersionView()) {
                    ZStack {
                        // Content
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(Color(red: 0.976, green: 0.451, blue: 0.086))
                                    .frame(width: 22, height: 22)
                                
                                Text("version".localized)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: .standardButtonHeight)
                    .background(glassButtonBackground)
                }
                .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer()
                        .frame(minHeight: 20)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            
            // Overlay con degradado del fondo para cubrir el área del toolbar y desvanecer burbujas
            // Mismo degradado que MenuView para consistencia
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
            .ignoresSafeArea(.container, edges: .top) // Para que cubra el toolbar y desvanezca las burbujas
        }
        .toolbar(content: toolbarContent)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.09, green: 0.145, blue: 0.229),
                Color(red: 0.118, green: 0.227, blue: 0.441),
                Color(red: 0.09, green: 0.145, blue: 0.229)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // Reutilizar el estilo de GlassButtonStyle para los botones de SettingsView
    // Usa los mismos valores que GlassButtonStyle para mantener consistencia
    private var glassButtonBackground: some View {
        let style = GlassButtonStyle(isEnabled: true)
        let cornerRadius = style.cornerRadius
        let isEnabled = style.isEnabled
        
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Material.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(isEnabled ? 0.15 : 0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color.white.opacity(isEnabled ? 0.45 : 0.3),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 2)
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
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                if let onBack = onBack {
                    onBack()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

