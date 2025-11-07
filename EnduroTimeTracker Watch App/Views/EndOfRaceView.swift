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
        VStack(spacing: 8) {
            // Spacer para dejar espacio para el header del sistema
            Spacer()
                .frame(height: 2)
            
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Mensaje End of Race
            Text("End of Race")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
            
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Botón Dismiss con estilo Glass
            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(GlassButtonStyle())
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

