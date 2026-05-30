//
//  WelcomeView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct WelcomeView: View {
    var onStart: () -> Void
    
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var hasRequestedPermissions = false
    
    var body: some View {
        VStack(spacing: 6) {
            // Logo de la app
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
            
            Spacer()
                .frame(height: 2)
            
            // Texto de bienvenida con tamaños reducidos
            VStack(spacing: 2) {
                Text("welcomeTo".localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                
                
                Text("\("enduroTime".localized) \("tracker".localized)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Botón Start con estilo Glass
            // PATRÓN CORRECTO: frame dentro, padding fuera (como Button 10 en TestButtonView)
            Button(action: onStart) {
                Text("startButton".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(GlassButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .task {
            // Solicitar permisos de HealthKit y ubicación al aparecer por primera vez
            if !hasRequestedPermissions {
                hasRequestedPermissions = true
                
                // Solicitar permisos de HealthKit
                _ = await healthKitManager.requestAuthorization()
                
                healthKitManager.ensureLocationAuthorizationIfNeeded()
            }
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}

