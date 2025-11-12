//
//  VersionView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct VersionView: View {
    @Environment(\.dismiss) var dismiss
    let localizationManager = LocalizationManager.shared
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            // Header Section - Title positioned below system clock (estático, fuera del ScrollView)
            VStack {
                HStack {
                    Spacer()
                    // Title positioned to appear below system clock
                    Text("version".localized)
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
            .zIndex(2) // Asegurar que el título esté por encima del contenido
            
            ScrollView {
                VStack(spacing: 0) {
                    // Espacio para el título estático
                    Spacer()
                        .frame(height: 20)
                    
                    // Version Text
                    Text("versionNumber".localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    
                    Spacer()
                        .frame(minHeight: 20)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            
            // Overlay con degradado del fondo para cubrir el área del toolbar y desvanecer contenido
            // Mismo degradado que MenuView y SettingsView para consistencia
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
            .ignoresSafeArea(.container, edges: .top) // Para que cubra el toolbar y desvanezca el contenido
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
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                dismiss()
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
        VersionView()
    }
}
