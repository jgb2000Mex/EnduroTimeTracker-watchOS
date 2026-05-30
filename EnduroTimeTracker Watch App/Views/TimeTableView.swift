//
//  TimeTableView.swift
//  EnduroTimeTracker Watch App
//
//  Created by Javier Garza on 04/11/25.
//

import SwiftUI

struct TimeTableView: View {
    var raceConfig: RaceConfiguration
    @State private var selectedTimeControl: TimeControl?
    @State private var showingTimePicker = false
    @Environment(\.dismiss) var dismiss
    
    var onDone: () -> Void
    var onGo: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            // Header Section - Title positioned below system clock (estático, fuera del ScrollView)
            VStack {
                HStack {
                    Spacer()
                    // Title positioned to appear below system clock
                    Text("timetableTitle".localized)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.3)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .offset(y: -15) // Mismo offset que MenuView y SettingsView
                        .padding(.trailing, 12)
                }
                .padding(.top, -10) // Mismo padding que MenuView y SettingsView
                
                Spacer()
            }
            .zIndex(2) // Asegurar que el título esté por encima de las burbujas
            
            ScrollView {
                VStack(spacing: 0) {
                    // Espacio para el título estático
                    Spacer()
                        .frame(height: 20)
                    
                    VStack(spacing: .standardButtonSpacing) {
                        // Parc Fermé Toggle
                        HStack {
                            Text("parcFerme".localized)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yellow)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { raceConfig.hasParcFerme },
                                set: { raceConfig.hasParcFerme = $0 }
                            ))
                                .labelsHidden()
                                .tint(.green)
                        }
                        .padding(.horizontal, 8)
                        
                        // Parc Fermé Time Picker (si está activo)
                        if raceConfig.hasParcFerme {
                            parcFermeButton
                        }
                        
                        // Lista de Time Controls usando List para que swipeActions funcione
                        timeControlsList
                        
                        // Texto de advertencia de penalizaciones (solo si hay penalizaciones)
                        if raceConfig.hasPenalties {
                            Text("penaltyWarning".localized)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        
                        // Botón Add Time Control con estilo Glass
                        addTimeControlButton
                        
                        // Espaciado antes del botón de Cronómetro (reducido para que no quede tan abajo)
                        Spacer()
                            .frame(height: 18)
                        
                        // Botón de Cronómetro (shortcut para iniciar la carrera)
                        raceTimerButton
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer()
                        .frame(minHeight: 20)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            
            // Overlay con degradado del fondo para cubrir el área del toolbar y desvanecer burbujas
            // Mismo degradado que MenuView y SettingsView para consistencia
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.09, green: 0.145, blue: 0.229),  // blue-950 opaco
                        Color(red: 0.09, green: 0.145, blue: 0.229).opacity(0.8), // ligeramente transparente
                        Color(red: 0.09, green: 0.145, blue: 0.229).opacity(0.0) // completamente transparente
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90) // Altura suficiente para cubrir toolbar + título
                .allowsHitTesting(false) // No interceptar toques
                
                Spacer()
            }
            .zIndex(1) // Por encima del ScrollView pero debajo del título y toolbar
            .ignoresSafeArea(.container, edges: .top) // Para que cubra el toolbar y desvanezca las burbujas
        }
        .toolbar(content: toolbarContent)
        .navigationDestination(isPresented: $showingTimePicker) {
            TimePickerView(
                initialTime: getInitialTime(),
                minimumTime: getMinimumTime(),
                onTimeSelected: { time in
                    saveTime(time)
                    showingTimePicker = false
                }
            )
        }
        .onAppear(perform: initializeTimeControls)
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
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                onDone()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
        }
    }
    
    private func initializeTimeControls() {
        if raceConfig.timeControls.isEmpty {
            let defaultTC1 = TimeControl(name: "Time Control 1")
            let defaultTC2 = TimeControl(name: "Time Control 2")
            raceConfig.timeControls = [defaultTC1, defaultTC2]
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Obtiene el nombre de display para un Time Control
    /// - El primer TC siempre muestra "Race Start"
    /// - El último TC muestra "Race Finish" solo si hay al menos un TC con tiempo seleccionado
    /// - Los demás muestran "TC2", "TC3", etc.
    private func getDisplayName(for tc: TimeControl, at index: Int) -> String {
        let isFirst = index == 0
        let isLast = index == raceConfig.timeControls.count - 1
        
        // Verificar si hay al menos un TC con tiempo seleccionado (usuario ya presionó Done)
        let hasAnyTimeSelected = raceConfig.timeControls.contains { $0.scheduledTime != nil } ||
                                 (raceConfig.hasParcFerme && raceConfig.parcFermeTime != nil)
        
        if isFirst {
            return "raceStart".localized
        } else if isLast && hasAnyTimeSelected {
            return "raceFinish".localized
        } else {
            // Extraer el número del nombre (ej: "Time Control 2" -> "Tiempo Ideal 2" en español, "Time Control 2" en inglés)
            let name = tc.name
            if let numberMatch = name.range(of: #"\d+"#, options: .regularExpression) {
                let number = String(name[numberMatch])
                return "\("timeControlPrefix".localized) \(number)"
            } else {
                // Si no se puede extraer el número, usar el nombre completo
                return name
            }
        }
    }
    
    private func getInitialTime() -> Date {
        if let selectedTC = selectedTimeControl {
            // Si el TC seleccionado ya tiene hora, usar esa
            if let time = selectedTC.scheduledTime {
                return time
            }
            // Si no tiene hora, usar la hora mínima (que ya incluye +1 minuto)
            return getMinimumTime()
        } else if raceConfig.hasParcFerme {
            // Para Parc Fermé, usar la hora actual si no hay hora seleccionada
            if let pfTime = raceConfig.parcFermeTime {
                return pfTime
            }
            return Date()
        } else {
            return Date()
        }
    }
    
    private func getMinimumTime() -> Date {
        if let selectedTC = selectedTimeControl {
            // Encontrar el índice del TC seleccionado
            if let index = raceConfig.timeControls.firstIndex(where: { $0.id == selectedTC.id }) {
                // Si es el primer TC (índice 0)
                if index == 0 {
                    // Si hay Parc Fermé activo, usar esa hora + 1 minuto
                    if raceConfig.hasParcFerme, let pfTime = raceConfig.parcFermeTime {
                        return pfTime.addingTimeInterval(60) // +1 minuto
                    }
                    // Si no hay Parc Fermé, usar hora actual + 1 minuto
                    return Date().addingTimeInterval(60)
                } else {
                    // Si no es el primero, usar la hora del TC anterior + 1 minuto
                    let previousTC = raceConfig.timeControls[index - 1]
                    if let previousTime = previousTC.scheduledTime {
                        return previousTime.addingTimeInterval(60) // +1 minuto
                    }
                    // Si el anterior no tiene hora, calcular recursivamente
                    return getMinimumTimeForIndex(index - 1)
                }
            }
        } else if raceConfig.hasParcFerme {
            // Para Parc Fermé, la hora mínima es ahora (no necesita +1 minuto porque es el primero)
            return Date()
        }
        return Date()
    }
    
    private func getMinimumTimeForIndex(_ index: Int) -> Date {
        if index == 0 {
            if raceConfig.hasParcFerme, let pfTime = raceConfig.parcFermeTime {
                return pfTime.addingTimeInterval(60) // +1 minuto
            }
            return Date().addingTimeInterval(60) // +1 minuto
        } else {
            let previousTC = raceConfig.timeControls[index - 1]
            if let previousTime = previousTC.scheduledTime {
                return previousTime.addingTimeInterval(60) // +1 minuto
            }
            return getMinimumTimeForIndex(index - 1)
        }
    }
    
    private func saveTime(_ time: Date) {
        // Validar que la hora sea válida (al menos 1 minuto después del anterior)
        let minimumTime = getMinimumTime()
        let validatedTime = max(time, minimumTime)
        
        if let selectedTC = selectedTimeControl {
            // Actualizar Time Control existente
            if let index = raceConfig.timeControls.firstIndex(where: { $0.id == selectedTC.id }) {
                raceConfig.timeControls[index].scheduledTime = validatedTime
                // Validar y borrar TCs posteriores si es necesario
                validateAndCleanTimeControls()
            }
        } else if raceConfig.hasParcFerme {
            // Guardar Parc Fermé
            raceConfig.parcFermeTime = validatedTime
        }
    }
    
    private func addTimeControl() {
        // Crear nuevo TC sin horario (mostrará "Select time")
        let newTC = TimeControl(
            name: "Time Control \(raceConfig.timeControls.count + 1)"
        )
        raceConfig.timeControls.append(newTC)
    }
    
    private func canDeleteTimeControl(at index: Int) -> Bool {
        // Solo se pueden borrar Time Controls a partir del 3 (índice 2)
        // Time Control 1 (índice 0) y Time Control 2 (índice 1) no se pueden borrar
        return index >= 2
    }
    
    private func deleteTimeControl(_ tc: TimeControl) {
        // Validar que se puede borrar antes de hacerlo
        if let index = raceConfig.timeControls.firstIndex(where: { $0.id == tc.id }) {
            guard canDeleteTimeControl(at: index) else {
                return // No se puede borrar, salir sin hacer nada
            }
            raceConfig.timeControls.removeAll { $0.id == tc.id }
        }
    }
    
    private func validateAndCleanTimeControls() {
        // Validación se implementará después con la lógica completa
        // Por ahora solo estructura visual
    }
    
    private var parcFermeButton: some View {
        Button(action: {
            selectedTimeControl = nil
            showingTimePicker = true
        }) {
            HStack {
                Text("parcFermeLabel".localized)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2) // Permitir 2 líneas como los Time Controls
                Spacer()
                if let pfTime = raceConfig.parcFermeTime {
                    Text(formatTime(pfTime))
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.green)
                } else {
                    Text("selectTime".localized)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2) // Forzar 2 líneas para consistencia
                        .multilineTextAlignment(.trailing) // Alinear a la derecha
                }
            }
            .padding(.horizontal, 12)
        }
        .buttonStyle(GlassButtonStyle(isEnabled: raceConfig.parcFermeTime != nil, height: .standardButtonHeight, useGreenBorder: true))
    }
    
    private var addTimeControlButton: some View {
        Button(action: addTimeControl) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)
                Text("addTimeControl".localized)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.yellow)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .buttonStyle(GlassButtonStyle(height: .standardButtonHeight))
    }
    
    private var raceTimerButton: some View {
        Button(action: onGo) {
            HStack {
                // Left side: Icon and Text
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(raceConfig.isValid ? Color(red: 0.976, green: 0.451, blue: 0.086) : Color.gray)
                        .frame(width: 22, height: 22)
                    
                    Text("raceTimerButton".localized)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(raceConfig.isValid ? .white : .gray)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Right side: More button (igual que en MenuView)
                Button(action: {
                    // More action
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
        }
        .buttonStyle(GlassButtonStyle(isEnabled: raceConfig.isValid, height: .standardButtonHeight))
        .disabled(!raceConfig.isValid)
    }
    
    private var timeControlsList: some View {
        List {
            ForEach(Array(raceConfig.timeControls.enumerated()), id: \.element.id) { index, tc in
                timeControlRow(index: index, tc: tc)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(height: CGFloat(raceConfig.timeControls.count) * (.standardButtonHeight + .standardButtonSpacing))
        .scrollDisabled(true)
        .padding(.bottom, 0) // El espaciado se maneja con listRowInsets
    }
    
    /// Obtiene los controles ordenados (igual que getAllControls en RaceView)
    private func getAllControlsOrdered() -> [(name: String, time: Date, originalIndex: Int)] {
        var controls: [(name: String, time: Date, originalIndex: Int)] = []
        
        if raceConfig.hasParcFerme, let pfTime = raceConfig.parcFermeTime {
            controls.append(("Parc Ferme", pfTime, -1)) // -1 indica Parc Ferme
        }
        
        // Incluir Time Controls que tengan hora seleccionada
        for (index, tc) in raceConfig.timeControls.enumerated() {
            if let time = tc.scheduledTime {
                controls.append((tc.name, time, index))
            }
        }
        
        return controls.sorted { $0.time < $1.time }
    }
    
    /// Obtiene el tiempo ajustado con penalizaciones para un TimeControl
    private func getAdjustedTime(for tc: TimeControl, at index: Int) -> Date? {
        guard let originalTime = tc.scheduledTime else { return nil }
        
        // Obtener todos los controles ordenados
        let allControls = getAllControlsOrdered()
        
        // Encontrar el índice de este control en la lista ordenada
        guard let controlIndex = allControls.firstIndex(where: { $0.name == tc.name && $0.time == originalTime }) else {
            return originalTime
        }
        
        // Obtener la penalización acumulada para este índice
        let accumulatedPenalty = raceConfig.getAccumulatedPenalty(for: controlIndex)
        
        // Aplicar la penalización
        return originalTime.addingTimeInterval(TimeInterval(accumulatedPenalty * 60))
    }
    
    /// Verifica si un TimeControl tiene penalización aplicada (positiva o negativa)
    private func hasPenalty(for tc: TimeControl, at index: Int) -> Bool {
        guard tc.scheduledTime != nil else { return false }
        
        let allControls = getAllControlsOrdered()
        guard let controlIndex = allControls.firstIndex(where: { $0.name == tc.name && $0.time == tc.scheduledTime }) else {
            return false
        }
        
        return raceConfig.getAccumulatedPenalty(for: controlIndex) != 0
    }
    
    private func timeControlRow(index: Int, tc: TimeControl) -> some View {
        let hasPenaltyApplied = hasPenalty(for: tc, at: index)
        let adjustedTime = getAdjustedTime(for: tc, at: index)
        let isLast = index == raceConfig.timeControls.count - 1
        
        return HStack {
            Text(getDisplayName(for: tc, at: index))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Spacer()
            if let time = adjustedTime {
                Text(formatTime(time))
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(hasPenaltyApplied ? .red : .green)
            } else {
                Text("selectTime".localized)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2) // Forzar 2 líneas para consistencia
                    .multilineTextAlignment(.trailing) // Alinear a la derecha
            }
        }
        .padding(.horizontal, 12)
        .frame(height: .standardButtonHeight)
        .background(timeControlBackground(isActive: tc.scheduledTime != nil))
        .opacity(tc.scheduledTime != nil ? 1.0 : 0.8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTimeControl = tc
            showingTimePicker = true
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: isLast ? 0 : .standardButtonSpacing, trailing: 0))
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDeleteTimeControl(at: index) {
                Button(role: .destructive) {
                    deleteTimeControl(tc)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .imageScale(.small)
                }
            }
        }
    }
    
    private func timeControlBackground(isActive: Bool) -> some View {
        // Reutilizar los valores de GlassButtonStyle para mantener consistencia
        let style = GlassButtonStyle(isEnabled: isActive, useGreenBorder: isActive)
        let cornerRadius = style.cornerRadius
        
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Material.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(isActive ? 0.15 : 0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        // Borde verde si está activo, sino usar opacidad estándar
                        isActive ? Color.green.opacity(0.6) : Color.white.opacity(isActive ? 0.45 : 0.3),
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
    }
}

// MARK: - Time Picker View
struct TimePickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTime: Date
    let localizationManager = LocalizationManager.shared
    
    let minimumTime: Date
    let onTimeSelected: (Date) -> Void
    
    init(initialTime: Date, minimumTime: Date, onTimeSelected: @escaping (Date) -> Void) {
        // Asegurar que initialTime no sea menor que minimumTime
        let validInitialTime = max(initialTime, minimumTime)
        _selectedTime = State(initialValue: validInitialTime)
        self.minimumTime = minimumTime
        self.onTimeSelected = onTimeSelected
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            // Header Section - Title positioned below system clock (estático, fuera del ScrollView)
            VStack {
                HStack {
                    Spacer()
                    // Title positioned to appear below system clock
                    Text("chooseTime".localized)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.3)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .offset(y: -5) // Ajustado para juntar el título a la hora (solo un punto)
                        .padding(.trailing, 12)
                }
                .padding(.top, 3) // Ajustado para juntar el título a la hora (solo un punto)
                
                Spacer()
            }
            .zIndex(2) // Asegurar que el título esté por encima del contenido
            
            VStack(spacing: 0) {
                // Espacio para el título estático
                Spacer()
                    .frame(height: 20)
                
                // DatePicker con altura para mostrar solo 3 valores
                DatePicker(
                    "selectTime".localized,
                    selection: $selectedTime,
                    in: minimumTime...,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 80) // Altura para mostrar solo 3 valores
                
                // Espaciado antes del botón Done (aumentado para que no esté tan cerca)
                Spacer()
                    .frame(height: 12)
                
                // Botón Done igual al de WelcomeView
                Button(action: {
                    // Normalizar el tiempo seleccionado a :00 segundos (sin segundos ni microsegundos)
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
                    guard let normalizedTime = calendar.date(from: components) else {
                        onTimeSelected(selectedTime)
                        dismiss()
                        return
                    }
                    
                    // Validar que la hora normalizada sea mayor o igual a la mínima
                    let validatedTime = max(normalizedTime, minimumTime)
                    onTimeSelected(validatedTime)
                    dismiss()
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
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
            
            // Overlay con degradado del fondo para cubrir el área del toolbar y desvanecer contenido
            // Mismo degradado que MenuView y SettingsView para consistencia
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.09, green: 0.145, blue: 0.229),  // blue-950 opaco
                        Color(red: 0.09, green: 0.145, blue: 0.229).opacity(0.8), // ligeramente transparente
                        Color(red: 0.09, green: 0.145, blue: 0.229).opacity(0.0) // completamente transparente
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90) // Altura suficiente para cubrir toolbar + título
                .allowsHitTesting(false) // No interceptar toques
                
                Spacer()
            }
            .zIndex(1) // Por encima del contenido pero debajo del título
            .ignoresSafeArea(.container, edges: .top) // Para que cubra el toolbar y desvanezca el contenido
        }
        .toolbar(content: timePickerToolbarContent)
    }
    
    @ToolbarContentBuilder
    private func timePickerToolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
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
    TimeTableView(
        raceConfig: RaceConfiguration(),
        onDone: {},
        onGo: {}
    )
}
