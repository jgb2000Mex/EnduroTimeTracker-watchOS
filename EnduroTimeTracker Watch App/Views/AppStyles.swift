//
//  AppStyles.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

// MARK: - Button Heights
extension CGFloat {
    static let standardButtonHeight: CGFloat = 75
    static let compactButtonHeight: CGFloat = 50 // Para botones como Start, Done, Dismiss
}

// MARK: - Spacing
extension CGFloat {
    static let standardButtonSpacing: CGFloat = 12 // Espaciado estándar entre botones
    static let emphasizedButtonSpacing: CGFloat = 36 // Espaciado enfatizado (triplicado) para botones especiales como "Agregar punto de control" o "Dismiss/Done"
}

// MARK: - Background Gradient
extension View {
    func appBackground() -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.09, green: 0.145, blue: 0.229),  // blue-950
                    Color(red: 0.118, green: 0.227, blue: 0.441), // blue-900
                    Color(red: 0.09, green: 0.145, blue: 0.229)   // blue-950
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var cornerRadius: CGFloat = 22
    var height: CGFloat? = nil // Opcional: altura fija para las burbujas
    var useGreenBorder: Bool = false // Solo para TimeTableView cuando hay valor seleccionado
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(height: height) // Aplicar altura si se especifica
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        Material.ultraThinMaterial
                    )
                    .overlay(
                        // Las burbujas inactivas son más claras (mayor opacidad)
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.gray.opacity(isEnabled ? 0.15 : 0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                // Borde verde solo si useGreenBorder es true Y está habilitado (solo en TimeTableView)
                                // Opacidad del borde: 0.45 para activos, 0.3 para inactivos
                                (useGreenBorder && isEnabled) ? Color.green.opacity(0.6) : Color.white.opacity(isEnabled ? 0.45 : 0.3),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius - 2)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            )
            .opacity(isEnabled ? 1.0 : 0.8) // Las inactivas son más visibles
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

