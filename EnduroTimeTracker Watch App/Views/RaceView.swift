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
    
    // Estado para mostrar el overlay de Screen Lock al iniciar la carrera
    // Solo se muestra una vez al inicio, no entre cambios de Time Controls
    @State private var showInitialScreenLockOverlay = true
    @State private var hasShownInitialScreenLockOverlay = false // Flag para asegurar que solo se muestre una vez
    
    // Estado para el bloqueo de pantalla
    @State private var isScreenLocked = false
    @State private var unlockClickCount = 0
    @State private var lastUnlockClickTime: Date?
    @State private var showUnlockOverlay = false
    @State private var hasShownUnlockOverlay = false
    
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
                // Desbloquear automáticamente cuando aparece End of Race
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
                .onAppear {
                    // Desbloquear automáticamente cuando aparece End of Race
                    isScreenLocked = false
                    unlockClickCount = 0
                    showUnlockOverlay = false // Ocultar overlay al desbloquear
                }
            } else {
                ZStack {
                    VStack(spacing: 1) {
                        // Spacer para dejar espacio para el header del sistema y toolbar
                        Spacer()
                            .frame(height: 12)
                        
                        // Nombre del siguiente TC
                        Text(getTimeLeftTitle())
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
                            .frame(height: 8)
                        
                        // Información del siguiente TC
                        VStack(spacing: 2) {
                            Text(getTimeOfNextTCTitle())
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                            Text(formatTime(getCurrentTimeControlTime()))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Overlay de Screen Lock que aparece solo una vez al iniciar la carrera
                    // No aparece entre cambios de Time Controls
                    if showInitialScreenLockOverlay {
                        initialScreenLockOverlay
                            .zIndex(1000)
                    }
                    
                    // Overlay de bloqueo de pantalla (invisible, solo bloquea toques)
                    // Debe estar por encima del overlay informativo para capturar los clicks
                    if isScreenLocked {
                        screenLockOverlay
                            .zIndex(1003)
                    }
                    
                    // Overlay informativo de desbloqueo
                    if showUnlockOverlay {
                        unlockOverlay
                            .zIndex(1002)
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
            
            // Mostrar overlay de Screen Lock solo una vez al iniciar la carrera
            // No se muestra entre cambios de Time Controls
            if !hasShownInitialScreenLockOverlay {
                hasShownInitialScreenLockOverlay = true
                showInitialScreenLockOverlay = true
                
                // Se cierra automáticamente después de 6 segundos
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showInitialScreenLockOverlay = false
                    }
                }
            }
            
            // NO iniciar workout aquí - se iniciará cuando llegue al primer Time Control (TC1)
            // Ver checkGoCondition() y moveToNextTimeControl()
        }
        // NOTA: No finalizar el workout en onDisappear porque puede llamarse múltiples veces
        // El workout se finaliza explícitamente cuando termina la carrera (en EndOfRaceView)
        .toolbar {
            // Solo mostrar toolbar cuando no estamos en End of Race
            if getCurrentTimeControl() != nil {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: {
                            // Solo permitir regresar si la pantalla no está bloqueada
                            if !isScreenLocked {
                                onBack()
                                dismiss()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                        .disabled(isScreenLocked) // Deshabilitar el botón cuando está bloqueado
                        
                        Button(action: {
                            // Solo permite bloquear cuando está desbloqueado
                            // Para desbloquear, se requieren 4 clicks en la pantalla
                            if !isScreenLocked {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isScreenLocked = true
                                    // Mostrar overlay informativo de desbloqueo
                                    showUnlockOverlay = true
                                    hasShownUnlockOverlay = false
                                    
                                    // Se cierra automáticamente después de 6 segundos
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            showUnlockOverlay = false
                                        }
                                    }
                                }
                            }
                        }) {
                            Image(systemName: isScreenLocked ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(isScreenLocked ? .red : .green)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .disabled(isScreenLocked) // Deshabilitar el botón cuando está bloqueado
                    }
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
    
    private func getTimeLeftTitle() -> String {
        guard let control = getCurrentTimeControl() else {
            return "End of Race"
        }
        
        let allControls = getAllControls()
        let isParcFerme = control.name == "Parc Ferme"
        let isLastControl = currentTimeControlIndex >= allControls.count - 1
        
        // Verificar si es TC1 (primer control que no es Parc Ferme)
        let firstNonParcFermeIndex = allControls.firstIndex { $0.name != "Parc Ferme" } ?? -1
        let isTC1 = currentTimeControlIndex == firstNonParcFermeIndex && !isParcFerme
        
        if isParcFerme {
            return "Time left for Parc Ferme"
        } else if isTC1 {
            return "Time left to Begin Race"
        } else if isLastControl {
            return "Time left to Finish Race"
        } else {
            // TC2 en adelante: extraer el número del nombre (ej: "Time Control 2" -> "TC2")
            // Intentar extraer el número del nombre del TC
            let name = control.name
            if let numberMatch = name.range(of: #"\d+"#, options: .regularExpression) {
                let number = String(name[numberMatch])
                return "Time left for TC\(number)"
            } else {
                // Si no se puede extraer el número, usar el nombre completo
                return "Time left for \(name)"
            }
        }
    }
    
    private func getTimeOfNextTCTitle() -> String {
        guard let control = getCurrentTimeControl() else {
            return "End of Race"
        }
        
        let allControls = getAllControls()
        let isParcFerme = control.name == "Parc Ferme"
        let isLastControl = currentTimeControlIndex >= allControls.count - 1
        
        // Verificar si es TC1 (primer control que no es Parc Ferme)
        let firstNonParcFermeIndex = allControls.firstIndex { $0.name != "Parc Ferme" } ?? -1
        let isTC1 = currentTimeControlIndex == firstNonParcFermeIndex && !isParcFerme
        
        // Verificar si Parc Ferme ya pasó (si existe y su índice es menor al actual)
        let parcFermeIndex = allControls.firstIndex { $0.name == "Parc Ferme" }
        let parcFermeHasPassed = parcFermeIndex != nil && currentTimeControlIndex > parcFermeIndex!
        
        if isParcFerme {
            return "Time to enter Parc Ferme"
        } else if isTC1 && (parcFermeIndex == nil || parcFermeHasPassed) {
            return "Time of Race Start"
        } else if isLastControl {
            return "Time of Race Finish"
        } else {
            // TC2 en adelante: extraer el número del nombre (ej: "Time Control 2" -> "TC2")
            let name = control.name
            if let numberMatch = name.range(of: #"\d+"#, options: .regularExpression) {
                let number = String(name[numberMatch])
                return "Time of TC\(number)"
            } else {
                // Si no se puede extraer el número, usar el nombre completo
                return "Time of \(name)"
            }
        }
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
    
    // MARK: - Screen Lock Overlay (informativo al inicio)
    private var initialScreenLockOverlay: some View {
        ZStack {
            // Fondo semi-transparente
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 20) {
                Spacer()
                
                // Icono de Padlock grande y centrado
                Image(systemName: "lock.fill")
                    .font(.system(size: 70, weight: .bold))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.bottom, 8)
                
                // Mensaje
                Text("Lock screen to prevent accidental touches")
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
                showInitialScreenLockOverlay = false
            }
        }
        .allowsHitTesting(showInitialScreenLockOverlay) // Solo permitir toques cuando está visible
    }
    
    // MARK: - Unlock Overlay
    private var unlockOverlay: some View {
        ZStack {
            // Fondo semi-transparente (misma opacidad que Screen Lock overlay)
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 20) {
                Spacer()
                
                // Icono de desbloqueo grande y centrado
                // Usando lock.open.fill para consistencia con el icono de bloqueo
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 70, weight: .bold))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, options: .repeating)
                    .padding(.bottom, 8)
                
                // Mensaje
                Text("To unlock press screen 4 times")
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
                showUnlockOverlay = false
            }
        }
        .allowsHitTesting(showUnlockOverlay) // Solo permitir toques cuando está visible
    }
    
    // MARK: - Screen Lock Overlay
    private var screenLockOverlay: some View {
        ZStack {
            // Overlay invisible que bloquea los toques pero permite ver el contenido
            // Solo captura los toques para detectar los 4 clicks de desbloqueo
            Color.clear
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleUnlockTap()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true) // Permitir toques para detectar los 4 clicks
    }
    
    /// Maneja los taps para desbloquear la pantalla (requiere 4 clicks)
    private func handleUnlockTap() {
        let now = Date()
        
        // Si han pasado más de 2 segundos desde el último click, resetear el contador
        // Aumentado a 3 segundos para dar más tiempo entre clicks
        if let lastClick = lastUnlockClickTime, now.timeIntervalSince(lastClick) > 2.0 {
            unlockClickCount = 0
        }
        
        unlockClickCount += 1
        lastUnlockClickTime = now
        
        print("🔓 [Screen Lock] Click \(unlockClickCount) de 4 para desbloquear")
        
        // Si se han hecho 4 clicks, desbloquear
        if unlockClickCount >= 4 {
            print("🔓 [Screen Lock] Desbloqueando pantalla")
            withAnimation(.easeOut(duration: 0.3)) {
                isScreenLocked = false
                unlockClickCount = 0
                lastUnlockClickTime = nil
                showUnlockOverlay = false // Ocultar overlay al desbloquear
            }
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

