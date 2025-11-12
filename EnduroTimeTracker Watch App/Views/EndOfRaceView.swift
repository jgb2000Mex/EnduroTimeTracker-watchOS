//
//  EndOfRaceView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct EndOfRaceView: View {
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            // Spacer para dejar espacio para el header del sistema y separar del reloj
            Spacer()
                .frame(height: 20)
            
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Icono de bandera a cuadros (Finish Flag)
            Image("ChequeredFlag")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .padding(.bottom, 1)
            
            // Mensaje End of Race
            Text("endOfRace".localized)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Espaciado antes del botón Dismiss (reducido)
            Spacer()
                .frame(height: 6)
            
            // Botón Dismiss con estilo Glass estandarizado
            Button(action: onDismiss) {
                Text("dismissButton".localized)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassButtonStyle(height: .compactButtonHeight))
            .padding(.horizontal, 30)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }
}

#Preview {
    EndOfRaceView(onDismiss: {})
}

