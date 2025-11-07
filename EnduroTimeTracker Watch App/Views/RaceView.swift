//
//  RaceView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct RaceView: View {
    let raceConfig: RaceConfiguration
    @State private var currentTimeControlIndex = 0
    @State private var timeRemaining: TimeInterval = 0
    @State private var showGoScreen = false
    @State private var timer: Timer?
    @Environment(\.dismiss) var dismiss
    
    var onBack: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
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
            
            if showGoScreen {
                GoView(
                    timeControlName: getCurrentTimeControlName(),
                    onContinue: {
                        showGoScreen = false
                        moveToNextTimeControl()
                    }
                )
            } else if getCurrentTimeControl() == nil {
                // No hay más Time Controls - mostrar End of Race
                EndOfRaceView(onDismiss: {
                    onBack()
                    dismiss()
                })
            } else {
                VStack(spacing: 1) {
                    // Spacer para dejar espacio para el header del sistema
                    Spacer()
                        .frame(height: 2)
                    
                    // Nombre del siguiente TC
                    Text(getCurrentTimeControlName())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 4)
                    
                    // Countdown grande
                    Text(formatCountdown(timeRemaining))
                        .font(.system(size: 55, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .monospacedDigit()
                    
                    Spacer()
                        .frame(height: 15)
                    
                    // Información del siguiente TC
                    VStack(spacing: 2) {
                        Text("Time of Next TC")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        Text(formatTime(getCurrentTimeControlTime()))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            updateTimeRemaining()
            startTimer()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    onBack()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        // Nota: watchOS maneja automáticamente el always-on display
        // El timer continuará funcionando en background
    }
    
    private func getCurrentTimeControl() -> (name: String, time: Date)? {
        let allControls = getAllControls()
        guard currentTimeControlIndex < allControls.count else {
            return nil
        }
        return allControls[currentTimeControlIndex]
    }
    
    private func getAllControls() -> [(name: String, time: Date)] {
        var controls: [(name: String, time: Date)] = []
        
        if raceConfig.hasParcFerme, let pfTime = raceConfig.parcFermeTime {
            controls.append(("Parc Ferme", pfTime))
        }
        
        // Solo incluir Time Controls que tengan hora seleccionada
        for tc in raceConfig.timeControls {
            if let time = tc.scheduledTime {
                controls.append((tc.name, time))
            }
        }
        
        return controls.sorted { $0.time < $1.time }
    }
    
    private func getCurrentTimeControlName() -> String {
        if let control = getCurrentTimeControl() {
            return control.name
        }
        return "End of Race"
    }
    
    private func getCurrentTimeControlTime() -> Date {
        if let control = getCurrentTimeControl() {
            return control.time
        }
        return Date()
    }
    
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func updateTimeRemaining() {
        guard let control = getCurrentTimeControl() else {
            // No hay más Time Controls - la carrera terminó
            timeRemaining = 0
            showGoScreen = false // Asegurar que no muestre GO!
            return
        }
        
        // Usar la fecha actual del sistema
        let now = Date()
        let calendar = Calendar.current
        
        // Normalizar el tiempo actual al segundo exacto (sin microsegundos)
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        guard let normalizedNow = calendar.date(from: nowComponents) else {
            timeRemaining = max(0, control.time.timeIntervalSince(now))
            checkGoCondition()
            return
        }
        
        // Normalizar el tiempo del control al minuto exacto (:00 segundos)
        // Esto asegura que cuando el usuario selecciona "5:16", se interprete como "5:16:00"
        let controlComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: control.time)
        guard let normalizedControlTime = calendar.date(from: controlComponents) else {
            // Fallback: usar el tiempo directamente
            timeRemaining = max(0, control.time.timeIntervalSince(normalizedNow))
            checkGoCondition()
            return
        }
        
        // Calcular diferencia entre el tiempo del control normalizado (:00) y el tiempo actual normalizado
        // Esto asegura que si el usuario seleccionó "5:16 p.m.", cuenta hacia "5:16:00" exactamente
        let remaining = normalizedControlTime.timeIntervalSince(normalizedNow)
        timeRemaining = max(0, remaining)
        
        checkGoCondition()
    }
    
    private func checkGoCondition() {
        // Si ya no hay más Time Controls, no mostrar GO!
        guard let _ = getCurrentTimeControl() else {
            showGoScreen = false
            timer?.invalidate()
            return
        }
        
        // Verificar si llegó a 0 (con un pequeño margen para evitar problemas de precisión)
        if timeRemaining <= 0.5 && !showGoScreen {
            // Verificar si hay más Time Controls después de este
            let allControls = getAllControls()
            let isLastControl = currentTimeControlIndex >= allControls.count - 1
            
            if isLastControl {
                // Es el último Time Control - avanzar el índice para que se muestre End of Race
                showGoScreen = false
                timer?.invalidate() // Detener el timer primero
                // Usar DispatchQueue para asegurar que la actualización de UI ocurra en el siguiente ciclo
                DispatchQueue.main.async {
                    self.currentTimeControlIndex += 1 // Avanzar para que getCurrentTimeControl() retorne nil
                }
            } else {
                // Hay más Time Controls - mostrar GO!
                showGoScreen = true
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        
        // Actualizar inmediatamente
        updateTimeRemaining()
        
        // Sincronizar el timer con el segundo del sistema
        let calendar = Calendar.current
        let now = Date()
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        
        // Calcular cuándo será el próximo segundo exacto
        guard let currentSecond = calendar.date(from: nowComponents),
              let nextSecond = calendar.date(byAdding: .second, value: 1, to: currentSecond) else {
            // Fallback: usar timer normal
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // Verificar si todavía hay controles antes de actualizar
                if self.getCurrentTimeControl() == nil {
                    self.timer?.invalidate()
                    return
                }
                self.updateTimeRemaining()
            }
            RunLoop.current.add(timer!, forMode: .common)
            return
        }
        
        let delay = nextSecond.timeIntervalSince(now)
        
        // Programar el primer tick para el próximo segundo exacto
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.updateTimeRemaining()
            
            // Luego continuar con intervalos de 1 segundo exactos
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // Verificar si todavía hay controles antes de actualizar
                if self.getCurrentTimeControl() == nil {
                    self.timer?.invalidate()
                    return
                }
                self.updateTimeRemaining()
            }
            
            // Asegurar que el timer se ejecute en el run loop común para mejor precisión
            if let timer = self.timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    private func moveToNextTimeControl() {
        let allControls = getAllControls()
        if currentTimeControlIndex < allControls.count - 1 {
            currentTimeControlIndex += 1
            updateTimeRemaining()
            // Si ya no hay más controles, actualizar el timer para que se detenga
            if getCurrentTimeControl() == nil {
                timer?.invalidate()
            }
        } else {
            // Ya no hay más Time Controls - invalidar el timer
            timer?.invalidate()
        }
    }
}


#Preview {
    let config = RaceConfiguration()
    config.hasParcFerme = true
    config.parcFermeTime = Date().addingTimeInterval(300)
    config.timeControls = [
        TimeControl(name: "Time Control 1", scheduledTime: Date().addingTimeInterval(360))
    ]
    
    return RaceView(
        raceConfig: config,
        onBack: {}
    )
}

