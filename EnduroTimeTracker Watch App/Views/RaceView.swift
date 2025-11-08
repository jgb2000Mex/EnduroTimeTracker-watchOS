//
//  RaceView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI
import WatchKit
import AVFoundation

struct RaceView: View {
    let raceConfig: RaceConfiguration
    @State private var currentTimeControlIndex = 0
    @State private var timeRemaining: TimeInterval = 0
    @State private var showGoScreen = false
    @State private var timer: Timer?
    @Environment(\.dismiss) var dismiss
    
    // HealthKit Manager
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var workoutStarted = false
    
    // Estados para rastrear qué alertas ya se han activado
    @State private var alert2MinutesTriggered = false
    @State private var alert1MinuteTriggered = false
    @State private var alertExactTimeTriggered = false
    @State private var lastTimeControlId: UUID? = nil
    
    // Estado para mostrar el overlay de Water Lock al iniciar la carrera
    // Solo se muestra una vez al inicio, no entre cambios de Time Controls
    @State private var showWaterLockOverlay = true
    @State private var hasShownWaterLockOverlay = false // Flag para asegurar que solo se muestre una vez
    
    var onBack: () -> Void
    var onRaceEnd: (() -> Void)? = nil // Callback opcional para cuando termina la carrera
    
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
                    // Finalizar workout de HealthKit
                    endHealthKitWorkout()
                    
                    // Si hay un callback de fin de carrera, usarlo (para resetear y volver a Welcome)
                    // Si no, usar el comportamiento anterior (volver al menu)
                    if let onRaceEnd = onRaceEnd {
                        onRaceEnd()
                    } else {
                        onBack()
                        dismiss()
                    }
                })
            } else {
                ZStack {
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
                    
                    // Overlay de Water Lock que aparece solo una vez al iniciar la carrera
                    // No aparece entre cambios de Time Controls
                    if showWaterLockOverlay {
                        waterLockOverlay
                            .zIndex(1000)
                    }
                }
            }
        }
        .onAppear {
            // Log del estado inicial
            let allControls = getAllControls()
            print("🚀 [RaceView] onAppear - Iniciando carrera")
            print("🚀 [RaceView] Total de controles: \(allControls.count)")
            for (index, control) in allControls.enumerated() {
                print("🚀 [RaceView] Control \(index): \(control.name) a las \(control.time)")
            }
            print("🚀 [RaceView] Índice inicial: \(currentTimeControlIndex)")
            if let currentControl = getCurrentTimeControl() {
                print("🚀 [RaceView] Control actual: \(currentControl.name) a las \(currentControl.time)")
            }
            
            updateTimeRemaining()
            startTimer()
            
            // Mostrar overlay de Water Lock solo una vez al iniciar la carrera
            // No se muestra entre cambios de Time Controls
            if !hasShownWaterLockOverlay {
                hasShownWaterLockOverlay = true
                showWaterLockOverlay = true
                
                // Se cierra automáticamente después de 6 segundos
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showWaterLockOverlay = false
                    }
                }
            }
            
            // NO iniciar workout aquí - se iniciará cuando llegue al primer Time Control (TC1)
            // Ver checkGoCondition() y moveToNextTimeControl()
        }
        // NOTA: No finalizar el workout en onDisappear porque puede llamarse múltiples veces
        // El workout se finaliza explícitamente cuando termina la carrera (en EndOfRaceView)
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
        
        // Resetear alertas si cambió el Time Control
        let currentControlId = getCurrentTimeControlId()
        if currentControlId != lastTimeControlId {
            alert2MinutesTriggered = false
            alert1MinuteTriggered = false
            alertExactTimeTriggered = false
            lastTimeControlId = currentControlId
        }
        
        // Usar la fecha actual del sistema
        let now = Date()
        let calendar = Calendar.current
        
        // Normalizar el tiempo actual al segundo exacto (sin microsegundos)
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        guard let normalizedNow = calendar.date(from: nowComponents) else {
            timeRemaining = max(0, control.time.timeIntervalSince(now))
            checkGoCondition()
            checkAlerts()
            return
        }
        
        // Normalizar el tiempo del control al minuto exacto (:00 segundos)
        // Esto asegura que cuando el usuario selecciona "5:16", se interprete como "5:16:00"
        let controlComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: control.time)
        guard let normalizedControlTime = calendar.date(from: controlComponents) else {
            // Fallback: usar el tiempo directamente
            timeRemaining = max(0, control.time.timeIntervalSince(normalizedNow))
            checkGoCondition()
            checkAlerts()
            return
        }
        
        // Calcular diferencia entre el tiempo del control normalizado (:00) y el tiempo actual normalizado
        // Esto asegura que si el usuario seleccionó "5:16 p.m.", cuenta hacia "5:16:00" exactamente
        let remaining = normalizedControlTime.timeIntervalSince(normalizedNow)
        timeRemaining = max(0, remaining)
        
        checkGoCondition()
        checkAlerts()
    }
    
    private func getCurrentTimeControlId() -> UUID? {
        let allControls = getAllControls()
        guard currentTimeControlIndex < allControls.count else {
            return nil
        }
        // Necesitamos obtener el ID del Time Control actual
        // Buscar en la configuración para encontrar el control correspondiente
        let control = allControls[currentTimeControlIndex]
        
        // Buscar el Time Control en la configuración que coincida con el nombre y tiempo
        if control.name == "Parc Ferme" {
            // Para Parc Fermé, usar un UUID único basado en el nombre
            return UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        } else {
            // Buscar el Time Control en la lista
            if let tc = raceConfig.timeControls.first(where: { $0.name == control.name && $0.scheduledTime == control.time }) {
                return tc.id
            }
        }
        return nil
    }
    
    private func checkAlerts() {
        // Verificar si debemos activar las alertas
        let totalSeconds = Int(timeRemaining)
        
        // Alerta a los 2 minutos (120 segundos exactos)
        // Verificamos cuando estamos en el segundo 120 o justo después de pasar de 121 a 120
        if totalSeconds == 120 && !alert2MinutesTriggered {
            playNotificationAlert()
            alert2MinutesTriggered = true
        }
        
        // Alerta a 1 minuto (60 segundos exactos)
        // Verificamos cuando estamos en el segundo 60 o justo después de pasar de 61 a 60
        if totalSeconds == 60 && !alert1MinuteTriggered {
            playNotificationAlert()
            alert1MinuteTriggered = true
        }
        
        // Alerta en el momento exacto (0 segundos)
        // Verificamos cuando el tiempo restante es 0 o muy cercano a 0
        if totalSeconds == 0 && !alertExactTimeTriggered {
            playNotificationAlert()
            alertExactTimeTriggered = true
        }
    }
    
    private func playNotificationAlert() {
        // Configurar la sesión de audio para maximizar el volumen
        // Aunque watchOS no permite cambiar el volumen del sistema directamente,
        // podemos configurar la sesión de audio para que tenga prioridad y se reproduzca
        // al máximo nivel posible según la configuración del dispositivo
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Usar categoría .playback con opciones para dar prioridad al audio
            // .duckOthers reduce el volumen de otros sonidos para dar prioridad a este
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: [])
        } catch {
            // Si falla la configuración de audio, continuar con haptics
            print("Error configurando audio session: \(error)")
        }
        
        let device = WKInterfaceDevice.current()
        
        // Reproducir exactamente 3 timbres y 3 vibraciones con delays entre cada uno
        // Usar .notification que es el mismo que WhatsApp, repetido 3 veces para hacerlo más notorio
        // El patrón será: notificación - pausa - notificación - pausa - notificación
        // Con 400ms de separación entre cada una para que sean claramente distinguibles
        let delays: [TimeInterval] = [0.0, 0.4, 0.8] // 400ms entre cada alerta
        
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Reproducir haptic de notificación (similar a WhatsApp)
                // Este tipo de haptic reproduce automáticamente el sonido de notificación
                // Al repetirlo 3 veces con la sesión de audio configurada para prioridad,
                // el sonido y haptic serán más notorios
                device.play(.notification)
            }
        }
    }
    
    private func checkGoCondition() {
        // Si ya no hay más Time Controls, no mostrar GO!
        guard let currentControl = getCurrentTimeControl() else {
            showGoScreen = false
            timer?.invalidate()
            return
        }
        
        // Verificar si llegó a 0 (con un pequeño margen para evitar problemas de precisión)
        if timeRemaining <= 0.5 && !showGoScreen {
            // Verificar si hay más Time Controls después de este
            let allControls = getAllControls()
            let isLastControl = currentTimeControlIndex >= allControls.count - 1
            let isParcFerme = currentControl.name == "Parc Ferme"
            
            print("⏰ [RaceView] checkGoCondition - Llegamos a: \(currentControl.name)")
            print("⏰ [RaceView] Índice actual: \(currentTimeControlIndex), Es último: \(isLastControl), Es Parc Ferme: \(isParcFerme)")
            
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
                // Si es Parc Ferme, solo mostrar pantalla GO! (no iniciar workout)
                // Si es TC1, verificar si debemos iniciar workout
                print("⏰ [RaceView] Mostrando pantalla GO! para: \(currentControl.name)")
                showGoScreen = true
                
                // Si llegamos a TC1 (no Parc Ferme) y el workout no ha iniciado, iniciarlo ahora
                if !isParcFerme && !workoutStarted {
                    let firstNonParcFermeIndex = allControls.firstIndex { $0.name != "Parc Ferme" } ?? -1
                    if currentTimeControlIndex == firstNonParcFermeIndex {
                        print("✅ [Workout] Llegamos al tiempo de TC1, iniciando workout ahora")
                        startHealthKitWorkout()
                    }
                }
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
        let previousIndex = currentTimeControlIndex
        let previousControl = getCurrentTimeControl()
        
        print("🔄 [RaceView] moveToNextTimeControl() llamado")
        print("🔄 [RaceView] Índice anterior: \(previousIndex)")
        if let prev = previousControl {
            print("🔄 [RaceView] Control anterior: \(prev.name) a las \(prev.time)")
        }
        
        if currentTimeControlIndex < allControls.count - 1 {
            currentTimeControlIndex += 1
            
            let currentControl = getCurrentTimeControl()
            print("🔄 [RaceView] Índice nuevo: \(currentTimeControlIndex)")
            if let curr = currentControl {
                print("🔄 [RaceView] Control nuevo: \(curr.name) a las \(curr.time)")
            }
            
            // Verificar si llegamos al primer Time Control REAL (TC1, no Parc Fermé)
            // TC1 es el primer control que NO es "Parc Ferme"
            let isParcFerme = currentControl?.name == "Parc Ferme"
            
            if let currentControl = currentControl, !isParcFerme {
                // Este es el primer Time Control real (TC1) - verificar si debemos iniciar workout
                // Verificar que realmente sea el primer Time Control (no Parc Fermé) en la lista
                let firstNonParcFermeIndex = allControls.firstIndex { $0.name != "Parc Ferme" } ?? -1
                let isFirstRealTimeControl = currentTimeControlIndex == firstNonParcFermeIndex
                
                print("🔍 [Workout] Verificando si es TC1...")
                print("🔍 [Workout] Es Parc Ferme: \(isParcFerme)")
                print("🔍 [Workout] Índice actual: \(currentTimeControlIndex)")
                print("🔍 [Workout] Primer TC real en índice: \(firstNonParcFermeIndex)")
                print("🔍 [Workout] Es primer TC real: \(isFirstRealTimeControl)")
                print("🔍 [Workout] Workout ya iniciado: \(workoutStarted)")
                
                if isFirstRealTimeControl && !workoutStarted {
                    // Verificar si el tiempo de TC1 ya llegó o es el tiempo actual
                    let now = Date()
                    let tc1Time = currentControl.time
                    
                    print("🔍 [Workout] TC1 programado para: \(tc1Time)")
                    print("🔍 [Workout] Tiempo actual: \(now)")
                    print("🔍 [Workout] TC1 ya pasó o es ahora: \(tc1Time <= now)")
                    
                    // Solo iniciar workout si el tiempo de TC1 ya llegó o es el tiempo actual
                    // NO iniciar si TC1 es futuro (eso causaría que HealthKit use el tiempo actual)
                    if tc1Time <= now {
                        print("✅ [Workout] Llegamos al primer Time Control REAL (TC1): \(currentControl.name)")
                        print("✅ [Workout] TC1 ya llegó, iniciando workout desde TC1: \(tc1Time)")
                        startHealthKitWorkout()
                    } else {
                        print("⏳ [Workout] TC1 es futuro, NO iniciar workout todavía")
                        print("⏳ [Workout] El workout se iniciará automáticamente cuando llegue el tiempo de TC1")
                        print("⏳ [Workout] Programando inicio de workout para: \(tc1Time)")
                        
                        // Programar el inicio del workout para cuando llegue TC1
                        let timeUntilTC1 = tc1Time.timeIntervalSince(now)
                        DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilTC1) {
                            // Verificar nuevamente que todavía no se haya iniciado y que sigamos en TC1
                            if !self.workoutStarted, let currentControl = self.getCurrentTimeControl(),
                               currentControl.name == tc1Time.description || self.currentTimeControlIndex == firstNonParcFermeIndex {
                                print("✅ [Workout] Tiempo de TC1 llegó, iniciando workout ahora")
                                self.startHealthKitWorkout()
                            }
                        }
                    }
                } else if workoutStarted {
                    print("ℹ️ [Workout] Workout ya iniciado, continuando con Time Control: \(currentControl.name)")
                } else {
                    print("⚠️ [Workout] No es el primer Time Control real (índice: \(currentTimeControlIndex), primer TC: \(firstNonParcFermeIndex))")
                }
            } else if isParcFerme {
                print("ℹ️ [Workout] Llegamos a Parc Ferme - NO iniciar workout todavía")
                print("ℹ️ [Workout] El workout comenzará cuando lleguemos a TC1")
            } else {
                print("⚠️ [Workout] No se pudo obtener el control actual")
            }
            
            // Resetear alertas para el nuevo Time Control
            alert2MinutesTriggered = false
            alert1MinuteTriggered = false
            alertExactTimeTriggered = false
            lastTimeControlId = getCurrentTimeControlId()
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
    
    // MARK: - HealthKit Integration
    
    /// Obtiene el primer Time Control (no Parc Fermé) para iniciar el workout desde ahí
    private func getFirstTimeControl() -> Date? {
        let allControls = getAllControls()
        // Buscar el primer control que NO sea Parc Fermé
        for control in allControls {
            if control.name != "Parc Ferme" {
                return control.time
            }
        }
        // Si no hay Time Controls, usar el primer control disponible (Parc Fermé como fallback)
        return allControls.first?.time
    }
    
    /// Inicia el workout de HealthKit desde el Time Control actual (TC1)
    /// IMPORTANTE: Este método solo debe llamarse cuando el control actual es TC1 (no Parc Fermé)
    private func startHealthKitWorkout() {
        guard !workoutStarted else { 
            print("⚠️ [Workout] Workout ya está iniciado, ignorando llamada")
            return 
        }
        
        // Obtener el Time Control actual (debe ser TC1, no Parc Fermé)
        guard let currentControl = getCurrentTimeControl() else {
            print("❌ [Workout] No hay Time Control actual")
            return
        }
        
        // Verificar explícitamente que NO sea Parc Ferme
        guard currentControl.name != "Parc Ferme" else {
            print("❌ [Workout] ERROR: Intento de iniciar workout en Parc Ferme (no permitido)")
            print("❌ [Workout] El workout solo debe iniciarse en TC1")
            return
        }
        
        // Verificar que realmente sea el primer Time Control (TC1)
        let allControls = getAllControls()
        let firstNonParcFerme = allControls.first { $0.name != "Parc Ferme" }
        guard let tc1 = firstNonParcFerme, currentControl.name == tc1.name, currentControl.time == tc1.time else {
            print("❌ [Workout] ERROR: El control actual no es TC1")
            print("❌ [Workout] Control actual: \(currentControl.name) a las \(currentControl.time)")
            if let tc1 = firstNonParcFerme {
                print("❌ [Workout] TC1 esperado: \(tc1.name) a las \(tc1.time)")
            }
            return
        }
        
        // Usar el tiempo del Time Control actual como startTime
        let tc1Time = currentControl.time
        let now = Date()
        let actualStartTime: Date
        
        // HealthKit no acepta fechas futuras para startActivity
        if tc1Time > now {
            // El Time Control es futuro, usar tiempo actual
            actualStartTime = now
            print("⚠️ [Workout] TC1 es futuro (\(tc1Time)), iniciando workout con tiempo actual (\(now))")
        } else {
            // El Time Control es pasado o presente, usar su tiempo exacto
            actualStartTime = tc1Time
            print("✅ [Workout] Iniciando workout desde TC1: \(currentControl.name) a las \(tc1Time)")
        }
        
        // Iniciar el workout de forma asíncrona
        Task {
            do {
                try await healthKitManager.startWorkout(startTime: actualStartTime)
                await MainActor.run {
                    workoutStarted = true
                }
                print("✅ [Workout] Workout iniciado exitosamente desde: \(actualStartTime)")
            } catch {
                print("❌ [Workout] Error iniciando workout: \(error.localizedDescription)")
            }
        }
    }
    
    /// Finaliza el workout de HealthKit cuando termina la carrera
    private func endHealthKitWorkout() {
        guard workoutStarted else { return }
        
        Task {
            do {
                try await healthKitManager.endWorkout(endTime: Date())
                await MainActor.run {
                    workoutStarted = false
                }
                print("Workout finalizado y guardado")
            } catch {
                print("Error finalizando workout: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Water Lock Overlay
    private var waterLockOverlay: some View {
        ZStack {
            // Fondo semi-transparente
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 20) {
                Spacer()
                
                // Icono de Water Lock grande y centrado
                Image(systemName: "drop.fill")
                    .font(.system(size: 70, weight: .bold))
                    .foregroundColor(.cyan)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.bottom, 8)
                
                // Mensaje
                Text("Enable Water Lock to avoid accidental touches")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // Cerrar el overlay al tocar
            withAnimation(.easeOut(duration: 0.3)) {
                showWaterLockOverlay = false
            }
        }
        .allowsHitTesting(showWaterLockOverlay) // Solo permitir toques cuando está visible
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

