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
    
    // Estados para penalizaciones
    @State private var showPenaltyConfirmation = false
    @State private var showPenaltyPicker = false
    @State private var selectedPenaltyMinutes = 1
    
    // Timestamp para rastrear cuándo se entró a la vista
    // Esto previene que GO! aparezca durante los primeros 3 segundos
    @State private var viewAppearedAt: Date?
    
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
            
            // Verificar primero si la carrera ya acabó (no hay más controles)
            // Si acabó, no mostrar GO! aunque showGoScreen esté en true
            if getCurrentTimeControl() == nil {
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
                    // Asegurar que showGoScreen esté en false cuando aparece End of Race
                    showGoScreen = false
                    // Desbloquear automáticamente cuando aparece End of Race
                    isScreenLocked = false
                    unlockClickCount = 0
                    showUnlockOverlay = false // Ocultar overlay al desbloquear
                }
            } else {
                // Determinar qué mostrar: GO! o countdown timer
                // Solo mostrar GO! si showGoScreen es true Y han pasado al menos 5 segundos desde que se entró a la vista
                let shouldShowGo = showGoScreen && 
                                   viewAppearedAt != nil && 
                                   Date().timeIntervalSince(viewAppearedAt!) >= 5.0
                
                if shouldShowGo {
                    // Mostrar pantalla GO! solo si se cumplen todas las condiciones
                    GoView(
                        timeControlName: getCurrentTimeControlName(),
                        onContinue: {
                            showGoScreen = false
                            moveToNextTimeControl()
                        }
                    )
                } else {
                    // Mostrar countdown timer (ya sea porque showGoScreen es false o porque no han pasado 5 segundos)
                    ZStack {
                        VStack(spacing: 1) {
                            // Spacer para dejar espacio para el header del sistema y toolbar
                            Spacer()
                                .frame(height: 12)
                            
                            // Nombre del siguiente TC
                            Text(getTimeLeftTitle())
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 8)
                            
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
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(2)
                                Text(formatTime(getCurrentTimeControlTime()))
                                    .font(.system(size: 35, weight: .bold, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
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
                        
                        // Overlay de confirmación de penalización
                        if showPenaltyConfirmation {
                            penaltyConfirmationOverlay
                                .zIndex(1004)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPenaltyPicker) {
            penaltyPickerView
        }
        .onAppear {
            showGoScreen = false
            viewAppearedAt = Date()
            
            if getCurrentTimeControl() != nil {
                resetAlerts()
                advancePastExpiredControls()
            }
            
            startTimer()
            
            if !hasShownInitialScreenLockOverlay {
                hasShownInitialScreenLockOverlay = true
                showInitialScreenLockOverlay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showInitialScreenLockOverlay = false
                    }
                }
            } else {
                showInitialScreenLockOverlay = false
            }
        }
        .toolbar {
            if getCurrentTimeControl() != nil && !showPenaltyConfirmation && !showPenaltyPicker {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Button(action: {
                            if !isScreenLocked {
                                onBack()
                                dismiss()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                        .disabled(isScreenLocked)
                        
                        Button(action: {
                            if !isScreenLocked {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isScreenLocked = true
                                    showUnlockOverlay = true
                                    hasShownUnlockOverlay = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
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
                        .disabled(isScreenLocked)
                        
                        Button(action: {
                            if !isScreenLocked && isPenaltyButtonEnabled() {
                                showPenaltyConfirmation = true
                            }
                        }) {
                            Image("Penalty icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(isPenaltyButtonEnabled() ? .white : .gray)
                        }
                        .disabled(isScreenLocked || !isPenaltyButtonEnabled())
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func getCurrentTimeControl() -> (name: String, time: Date)? {
        let allControls = getAllControls()
        guard currentTimeControlIndex < allControls.count else {
            return nil
        }
        return allControls[currentTimeControlIndex]
    }
    
    private func getFirstNonParcFermeIndex() -> Int {
        let allControls = getAllControls()
        return allControls.firstIndex { $0.name != "Parc Ferme" } ?? -1
    }
    
    private func resetAlerts() {
        alert2MinutesTriggered = false
        alert1MinuteTriggered = false
        alertExactTimeTriggered = false
    }
    
    private func advancePastExpiredControls() {
        let now = Date()
        let calendar = Calendar.current
        let threshold: TimeInterval = 5.0
        
        var maxIterations = 10
        while maxIterations > 0, let control = getCurrentTimeControl() {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: control.time)
            guard let normalizedTime = calendar.date(from: components),
                  now.timeIntervalSince(normalizedTime) > threshold else {
                break
            }
            
            showGoScreen = false
            moveToNextTimeControl()
            viewAppearedAt = Date()
            maxIterations -= 1
        }
    }
    
    /// Obtiene los controles originales (sin ajustar por penalizaciones)
    private func getOriginalControls() -> [(name: String, time: Date)] {
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
    
    private func getAllControls() -> [(name: String, time: Date)] {
        let sortedControls = getOriginalControls()
        
        // Aplicar penalizaciones a los tiempos
        var adjustedControls: [(name: String, time: Date)] = []
        for (index, control) in sortedControls.enumerated() {
            let accumulatedPenalty = raceConfig.getAccumulatedPenalty(for: index)
            let adjustedTime = control.time.addingTimeInterval(TimeInterval(accumulatedPenalty * 60))
            adjustedControls.append((control.name, adjustedTime))
        }
        
        return adjustedControls
    }
    
    private func isPenaltyButtonEnabled() -> Bool {
        let originalControls = getOriginalControls()
        guard currentTimeControlIndex < originalControls.count else { return false }
        
        let currentControl = originalControls[currentTimeControlIndex]
        if currentControl.name == "Parc Ferme" { return false }
        
        let parcFermeIndex = originalControls.firstIndex { $0.name == "Parc Ferme" }
        if let pfIndex = parcFermeIndex, currentTimeControlIndex <= pfIndex { return false }
        
        let firstNonParcFermeIndex = originalControls.firstIndex { $0.name != "Parc Ferme" } ?? -1
        return currentTimeControlIndex > firstNonParcFermeIndex
    }
    
    /// Calcula el máximo de minutos negativos permitidos para una penalización
    /// Basado en el tiempo disponible hasta el siguiente Time Control
    /// La penalización se aplica desde el control actual en adelante
    private func getMaxNegativePenaltyMinutes() -> Int {
        let originalControls = getOriginalControls()
        print("🔍 [getMaxNegativePenaltyMinutes] currentTimeControlIndex: \(currentTimeControlIndex), totalControls: \(originalControls.count)")
        guard currentTimeControlIndex < originalControls.count - 1 else {
            print("🔍 [getMaxNegativePenaltyMinutes] Es el último control (índice \(currentTimeControlIndex) de \(originalControls.count)), retornando 0")
            return 0 // No se puede restar tiempo si es el último control
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Obtener el siguiente control
        let nextIndex = currentTimeControlIndex + 1
        guard nextIndex < originalControls.count else {
            print("🔍 [getMaxNegativePenaltyMinutes] nextIndex fuera de rango: \(nextIndex) >= \(originalControls.count)")
            return 0
        }
        
        let nextControlOriginal = originalControls[nextIndex]
        print("🔍 [getMaxNegativePenaltyMinutes] Siguiente control: \(nextControlOriginal.name) a las \(nextControlOriginal.time)")
        
        // Calcular la penalización acumulada actual hasta el control actual (antes de aplicar la nueva)
        let currentAccumulatedPenalty = raceConfig.getAccumulatedPenalty(for: currentTimeControlIndex)
        print("🔍 [getMaxNegativePenaltyMinutes] Penalización acumulada hasta control actual: \(currentAccumulatedPenalty) minutos")
        
        // El tiempo del siguiente control con las penalizaciones actuales (sin la nueva penalización)
        // La penalización se aplica desde el control actual en adelante, así que el siguiente control
        // ya tiene la penalización acumulada hasta el control actual
        let nextControlTimeWithCurrentPenalties = nextControlOriginal.time.addingTimeInterval(TimeInterval(currentAccumulatedPenalty * 60))
        print("🔍 [getMaxNegativePenaltyMinutes] Tiempo del siguiente control con penalizaciones: \(nextControlTimeWithCurrentPenalties)")
        
        // Normalizar tiempos
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        guard let normalizedNow = calendar.date(from: nowComponents) else {
            print("🔍 [getMaxNegativePenaltyMinutes] Error normalizando tiempo actual")
            return 0
        }
        
        let nextComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextControlTimeWithCurrentPenalties)
        guard let normalizedNext = calendar.date(from: nextComponents) else {
            print("🔍 [getMaxNegativePenaltyMinutes] Error normalizando tiempo del siguiente control")
            return 0
        }
        
        // Calcular la diferencia en minutos (tiempo disponible hasta el siguiente control)
        let timeDifference = normalizedNext.timeIntervalSince(normalizedNow)
        let minutesAvailable = Int(timeDifference / 60)
        
        print("🔍 [getMaxNegativePenaltyMinutes] now: \(normalizedNow), next: \(normalizedNext), diff: \(timeDifference) segundos, minutes: \(minutesAvailable)")
        
        // El máximo negativo es el tiempo disponible (no puede ser negativo)
        // Si hay menos de 1 minuto disponible, no se puede restar nada
        let result = max(0, minutesAvailable)
        print("🔍 [getMaxNegativePenaltyMinutes] returning: \(result)")
        return result
    }
    
    /// Aplica una penalización desde el control actual en adelante
    /// Si la penalización es negativa y excede el tiempo disponible, se ajusta al máximo permitido
    private func applyPenalty(minutes: Int) {
        var adjustedMinutes = minutes
        
        // Si es una penalización negativa, validar y ajustar si es necesario
        if minutes < 0 {
            let maxNegative = getMaxNegativePenaltyMinutes()
            let minValue = -maxNegative
            if minutes < minValue {
                // Ajustar al máximo negativo permitido
                adjustedMinutes = minValue
                print("⚠️ [Penalty] Penalización negativa ajustada de \(minutes) a \(adjustedMinutes) minutos (máximo permitido)")
            }
        }
        
        let originalControls = getOriginalControls()
        let totalControls = originalControls.count
        raceConfig.applyPenalty(minutes: adjustedMinutes, fromIndex: currentTimeControlIndex, totalControls: totalControls)
        
        // Actualizar el tiempo restante para reflejar la penalización
        updateTimeRemaining()
    }
    
    private func getCurrentTimeControlName() -> String {
        if let control = getCurrentTimeControl() {
            return control.name
        }
        return "endOfRace".localized
    }
    
    private func getTimeLeftTitle() -> String {
        guard let control = getCurrentTimeControl() else { return "endOfRace".localized }
        
        let allControls = getAllControls()
        let isParcFerme = control.name == "Parc Ferme"
        let isLastControl = currentTimeControlIndex >= allControls.count - 1
        let firstNonParcFermeIndex = getFirstNonParcFermeIndex()
        let isTC1 = currentTimeControlIndex == firstNonParcFermeIndex && !isParcFerme
        
        if isParcFerme { return "timeLeftForParcFerme".localized }
        if isTC1 { return "timeLeftToBeginRace".localized }
        if isLastControl { return "timeLeftToFinishRace".localized }
        
        if let numberMatch = control.name.range(of: #"\d+"#, options: .regularExpression) {
            let number = String(control.name[numberMatch])
            return "\(LocalizationManager.shared.localizedString("timeLeftForTC")) \(number)"
        }
        return "\(LocalizationManager.shared.localizedString("timeLeftForTC")) \(control.name)"
    }
    
    private func getTimeOfNextTCTitle() -> String {
        guard let control = getCurrentTimeControl() else { return "endOfRace".localized }
        
        let allControls = getAllControls()
        let isParcFerme = control.name == "Parc Ferme"
        let isLastControl = currentTimeControlIndex >= allControls.count - 1
        let firstNonParcFermeIndex = getFirstNonParcFermeIndex()
        let isTC1 = currentTimeControlIndex == firstNonParcFermeIndex && !isParcFerme
        let parcFermeIndex = allControls.firstIndex { $0.name == "Parc Ferme" }
        let parcFermeHasPassed = parcFermeIndex != nil && currentTimeControlIndex > parcFermeIndex!
        
        if isParcFerme { return "timeToEnterParcFerme".localized }
        if isTC1 && (parcFermeIndex == nil || parcFermeHasPassed) { return "timeOfRaceStart".localized }
        if isLastControl { return "timeOfRaceFinish".localized }
        
        if let numberMatch = control.name.range(of: #"\d+"#, options: .regularExpression) {
            let number = String(control.name[numberMatch])
            return "\(LocalizationManager.shared.localizedString("timeOfTC")) \(number)"
        }
        return "\(LocalizationManager.shared.localizedString("timeOfTC")) \(control.name)"
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
            timeRemaining = 0
            showGoScreen = false
            return
        }
        
        let currentControlId = getCurrentTimeControlId()
        if currentControlId != lastTimeControlId {
            resetAlerts()
            lastTimeControlId = currentControlId
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        guard let normalizedNow = calendar.date(from: nowComponents) else {
            timeRemaining = max(0, control.time.timeIntervalSince(now))
            checkGoCondition()
            checkAlerts()
            return
        }
        
        let controlComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: control.time)
        guard let normalizedControlTime = calendar.date(from: controlComponents) else {
            timeRemaining = max(0, control.time.timeIntervalSince(normalizedNow))
            checkGoCondition()
            checkAlerts()
            return
        }
        
        timeRemaining = max(0, normalizedControlTime.timeIntervalSince(normalizedNow))
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
        guard let appearedAt = viewAppearedAt,
              Date().timeIntervalSince(appearedAt) >= 5.0,
              timeRemaining >= -5.0 else {
            return
        }
        
        let totalSeconds = Int(timeRemaining)
        
        if totalSeconds == 120 && !alert2MinutesTriggered {
            playNotificationAlert()
            alert2MinutesTriggered = true
        } else if totalSeconds == 60 && !alert1MinuteTriggered {
            playNotificationAlert()
            alert1MinuteTriggered = true
        } else if totalSeconds == 0 && !alertExactTimeTriggered {
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
        guard let currentControl = getCurrentTimeControl() else {
            showGoScreen = false
            timer?.invalidate()
            return
        }
        
        guard let appearedAt = viewAppearedAt,
              Date().timeIntervalSince(appearedAt) >= 5.0 else {
            showGoScreen = false
            return
        }
        
        guard timeRemaining <= 0.5 && !showGoScreen else { return }
        
        let allControls = getAllControls()
        let isLastControl = currentTimeControlIndex >= allControls.count - 1
        let isParcFerme = currentControl.name == "Parc Ferme"
        
        if isLastControl {
            showGoScreen = false
            timer?.invalidate()
            DispatchQueue.main.async {
                self.currentTimeControlIndex += 1
            }
        } else {
            showGoScreen = true
            
            if !isParcFerme && !workoutStarted {
                let firstNonParcFermeIndex = getFirstNonParcFermeIndex()
                if currentTimeControlIndex == firstNonParcFermeIndex {
                    startHealthKitWorkout()
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
        guard currentTimeControlIndex < allControls.count - 1 else {
            timer?.invalidate()
            return
        }
        
        currentTimeControlIndex += 1
        
        guard let currentControl = getCurrentTimeControl(),
              currentControl.name != "Parc Ferme" else {
            resetAlerts()
            lastTimeControlId = getCurrentTimeControlId()
            updateTimeRemaining()
            if getCurrentTimeControl() == nil {
                timer?.invalidate()
            }
            return
        }
        
        let firstNonParcFermeIndex = getFirstNonParcFermeIndex()
        if currentTimeControlIndex == firstNonParcFermeIndex && !workoutStarted {
            let now = Date()
            if currentControl.time <= now {
                startHealthKitWorkout()
            } else {
                let timeUntilTC1 = currentControl.time.timeIntervalSince(now)
                DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilTC1) {
                    if !self.workoutStarted, self.currentTimeControlIndex == firstNonParcFermeIndex {
                        self.startHealthKitWorkout()
                    }
                }
            }
        }
        
        resetAlerts()
        lastTimeControlId = getCurrentTimeControlId()
        updateTimeRemaining()
        
        if getCurrentTimeControl() == nil {
            timer?.invalidate()
        }
    }
    
    // MARK: - HealthKit Integration
    
    private func startHealthKitWorkout() {
        guard !workoutStarted,
              let currentControl = getCurrentTimeControl(),
              currentControl.name != "Parc Ferme" else {
            return
        }
        
        let allControls = getAllControls()
        let firstNonParcFerme = allControls.first { $0.name != "Parc Ferme" }
        guard let tc1 = firstNonParcFerme,
              currentControl.name == tc1.name,
              currentControl.time == tc1.time else {
            return
        }
        
        let now = Date()
        let actualStartTime = currentControl.time > now ? now : currentControl.time
        
        Task {
            do {
                try await healthKitManager.startWorkout(startTime: actualStartTime)
                await MainActor.run {
                    workoutStarted = true
                }
            } catch {
                print("Error iniciando workout: \(error.localizedDescription)")
            }
        }
    }
    
    private func endHealthKitWorkout() {
        guard workoutStarted else { return }
        
        Task {
            do {
                try await healthKitManager.endWorkout(endTime: Date())
                await MainActor.run {
                    workoutStarted = false
                }
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
                Text("lockScreenMessage".localized)
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
                Text("unlockMessage".localized)
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
    
    // MARK: - Penalty Overlays
    
    private var penaltyConfirmationOverlay: some View {
        ZStack {
            // Fondo semi-transparente
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 8) {
                Spacer()
                
                // Icono de penalización (más grande)
                Image("Penalty icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
                
                // Mensaje
                Text("penaltyConfirmationQuestion".localized)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 12)
                
                // Botones YES y NO con estilo Glass (sin outline grueso)
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showPenaltyConfirmation = false
                            showPenaltyPicker = true
                        }
                    }) {
                        Text("yesButton".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 65, height: 36)
                    }
                    .buttonStyle(GlassButtonStyle(cornerRadius: 18, height: 36))
                    
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showPenaltyConfirmation = false
                        }
                    }) {
                        Text("noButton".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 65, height: 36)
                    }
                    .buttonStyle(GlassButtonStyle(cornerRadius: 18, height: 36))
                }
                .padding(.top, 4)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
    
    private var penaltyPickerView: some View {
        ZStack {
            // Background
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
            
            VStack(spacing: 0) {
                // Espacio superior mínimo
                Spacer()
                    .frame(height: 4)
                
                // Título compacto
                Text("penaltyMinutes".localized)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .padding(.top, 8)
                
                // Stepper para seleccionar minutos (estilo WatchOS nativo)
                HStack(spacing: 8) {
                    // Botón menos (verde como en WatchOS, tamaño reducido)
                    Button(action: {
                        // Por ahora, permitir bajar sin restricciones para probar
                        selectedPenaltyMinutes -= 1
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Número de minutos con "min" al lado (font reducido 1 punto)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(selectedPenaltyMinutes)")
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("minutesLabel".localized)
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    // Botón más (verde como en WatchOS, tamaño reducido)
                    Button(action: {
                        selectedPenaltyMinutes += 1
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 12)
                
                Spacer()
                    .frame(minHeight: 8)
                
                // Botón Done con estilo Glass (estandarizado según AppStyles)
                Button(action: {
                    // Por ahora, aplicar sin validación para probar
                    applyPenalty(minutes: selectedPenaltyMinutes)
                    selectedPenaltyMinutes = selectedPenaltyMinutes >= 0 ? 1 : 0 // Resetear: positivo a 1, negativo a 0
                    showPenaltyPicker = false
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
                .padding(.bottom, 8)
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

