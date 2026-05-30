//
//  WarningView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct WarningView: View {
    @State private var doNotShowAgain = false
    let localizationManager = LocalizationManager.shared
    var onDone: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 0) {
                    // Espacio superior
                    Spacer()
                        .frame(height: 1)
                    
                    // Warning Icon centrado
                    Image("WarningIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.yellow)
                        .padding(.bottom, 16)
                    
                    // Mensaje de advertencia
                    Text("warningMessage".localized)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    
                    // Checkbox "Do not show again"
                    HStack(spacing: 8) {
                        Button(action: {
                            doNotShowAgain.toggle()
                            if doNotShowAgain {
                                // Guardar preferencia en UserDefaults
                                UserDefaults.standard.set(true, forKey: "warningDismissed")
                            }
                        }) {
                            Image(systemName: doNotShowAgain ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundColor(doNotShowAgain ? .yellow : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("doNotShowAgain".localized)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.8)
                            .lineLimit(2)
                    }
                    .padding(.bottom, 16)
                    
                    // Botón Done con estilo Glass (estandarizado según AppStyles)
                    Button(action: {
                        onDone()
                    }) {
                        Text("doneButton".localized)
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
                    
                    Spacer()
                        .frame(minHeight: 20)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
        }
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
}

#Preview {
    WarningView(onDone: {})
}

