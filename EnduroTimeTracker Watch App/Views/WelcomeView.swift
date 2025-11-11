//
//  WelcomeView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI
import CoreLocation

struct WelcomeView: View {
    var onStart: () -> Void
    
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var hasRequestedPermissions = false
    @State private var locationManager: CLLocationManager?
    
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
                Text("Welcome to")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 0) {
                    Text("Enduro Time")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .minimumScaleFactor(0.9)
                        .lineLimit(1)
                    
                    Text(" Tracker")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.9)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
            
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Botón Start con estilo Glass
            Button(action: onStart) {
                Text("Start")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 60)
            }
            .buttonStyle(GlassButtonStyle())
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
                
                // Solicitar permisos de ubicación
                // En watchOS, los permisos de ubicación se solicitan cuando se usa CLLocationManager
                // Creamos un locationManager temporal solo para solicitar permisos
                let tempLocationManager = CLLocationManager()
                let status = tempLocationManager.authorizationStatus
                
                if status == .notDetermined {
                    tempLocationManager.requestAlwaysAuthorization()
                } else if status == .authorizedWhenInUse {
                    tempLocationManager.requestAlwaysAuthorization()
                }
                
                locationManager = tempLocationManager
            }
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}

