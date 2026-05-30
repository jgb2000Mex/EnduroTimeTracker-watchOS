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
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Nombre del TC
            Text(timeControlName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.bottom, 1)
            
            // GO! grande
            Text("goText".localized)
                .font(.system(size: 70, weight: .bold, design: .rounded))
                .foregroundColor(.green)
            
            Spacer()
                .frame(maxHeight: .infinity)
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
}

#Preview {
    GoView(
        timeControlName: "Time Control 1",
        onContinue: {}
    )
}

