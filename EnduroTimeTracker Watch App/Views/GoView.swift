//
//  GoView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct GoView: View {
    let timeControlName: String
    let onContinue: () -> Void
    
    @State private var nextTimeControlTime: Date = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Spacer para dejar espacio para el header del sistema
            Spacer()
                .frame(height: 2)
            
            // Nombre del TC
            Text(timeControlName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 4)
                .padding(.bottom, -5)
            
            // GO! grande
            Text("GO!")
                .font(.system(size: 70, weight: .bold, design: .rounded))
                .foregroundColor(.green)
            
            Spacer()
                .frame(height: 20)
            
            // Información del siguiente TC
            VStack(spacing: 2) {
                Text("Time of Next TC")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Text(formatTime(nextTimeControlTime))
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .onAppear {
            // Auto-continuar después de 2 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onContinue()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    GoView(
        timeControlName: "Time Control 1",
        onContinue: {}
    )
}

