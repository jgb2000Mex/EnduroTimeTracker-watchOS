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
    
    var body: some View {
        VStack(spacing: 8) {
            // Título
            Text("Time Tracker Settings")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.top, 4)
            
            Spacer()
                .frame(height: 4)
            
            // Botones del menú
            VStack(spacing: 8) {
                // Botón TimeTable con estilo Liquid Glass
                Button(action: onTimeTable) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                        Text("TimeTable")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                }
                .buttonStyle(.glass)
                .tint(.yellow)
                
                // Botón Go! con estilo Liquid Glass
                Button(action: onGo) {
                    VStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(raceConfig.isValid ? .white : .gray)
                        Text("Go!")
                            .font(.caption)
                            .foregroundColor(raceConfig.isValid ? .white : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                }
                .buttonStyle(.glass)
                .tint(.yellow)
                .disabled(!raceConfig.isValid)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    MenuView(
        raceConfig: RaceConfiguration(),
        onTimeTable: {},
        onGo: {}
    )
}

