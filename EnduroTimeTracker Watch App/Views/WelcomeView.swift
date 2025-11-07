//
//  WelcomeView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct WelcomeView: View {
    var onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            // Icono con tamaño reducido
            Image(systemName: "timer")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
                .symbolEffect(.pulse, options: .repeating)
            
            Spacer()
                .frame(height: 4)
            
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
    }
}

#Preview {
    WelcomeView(onStart: {})
}

