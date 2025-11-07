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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Parc Fermé Toggle
                HStack {
                    Text("Parc Ferme")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)
                    
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
                
                // Botón Add Time Control con estilo Glass
                addTimeControlButton
                
                Spacer()
                    .frame(height: 4)
                
                // Botón Done con estilo Glass
                doneButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .background(backgroundGradient)
        .toolbar(content: toolbarContent)
        .sheet(isPresented: $showingTimePicker, content: timePickerSheet)
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
    
    @ViewBuilder
    private func timePickerSheet() -> some View {
        TimePickerView(
            initialTime: getInitialTime(),
            minimumTime: getMinimumTime(),
            onTimeSelected: { time in
                saveTime(time)
            }
        )
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
    
    private var mainContent: some View {
        ScrollView {
            scrollContent
        }
    }
    
    private var scrollContent: some View {
        VStack(spacing: 12) {
            // Parc Fermé Toggle
            HStack {
                Text("Parc Ferme")
                    .font(.caption)
                    .foregroundColor(.white)
                
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
            
            // Botón Add Time Control con estilo Glass
            addTimeControlButton
            
            Spacer()
                .frame(height: 4)
            
            // Botón Done con estilo Glass
            doneButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
    
    private var parcFermeButton: some View {
        Button(action: {
            selectedTimeControl = nil
            showingTimePicker = true
        }) {
            HStack {
                Text("Parc Ferme:")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                if let pfTime = raceConfig.parcFermeTime {
                    Text(formatTime(pfTime))
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.green)
                } else {
                    Text("Select time")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
        }
        .buttonStyle(GlassButtonStyle(isEnabled: raceConfig.parcFermeTime != nil, height: 80, useGreenBorder: true))
    }
    
    private var addTimeControlButton: some View {
        Button(action: addTimeControl) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
                Text("Add Time Control")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.yellow)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
        }
        .buttonStyle(GlassButtonStyle(height: 60))
        .padding(.top, 10)
    }
    
    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
        }
        .buttonStyle(GlassButtonStyle())
        .padding(.top, 10)
        .padding(.horizontal, 30)
    }
    
    private var timeControlsList: some View {
        List {
            ForEach(Array(raceConfig.timeControls.enumerated()), id: \.element.id) { index, tc in
                timeControlRow(index: index, tc: tc)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(height: CGFloat(raceConfig.timeControls.count) * 95)
        .scrollDisabled(true)
    }
    
    private func timeControlRow(index: Int, tc: TimeControl) -> some View {
        HStack {
            Text(tc.name)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            if let time = tc.scheduledTime {
                Text(formatTime(time))
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.green)
            } else {
                Text("Select time")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 75)
        .background(timeControlBackground(isActive: tc.scheduledTime != nil))
        .opacity(tc.scheduledTime != nil ? 1.0 : 0.8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTimeControl = tc
            showingTimePicker = true
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
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
        RoundedRectangle(cornerRadius: 32)
            .fill(Material.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.gray.opacity(isActive ? 0.25 : 0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        isActive ? Color.green.opacity(0.6) : Color.white.opacity(0.4),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30)
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
            
            VStack(spacing: 16) {
                // Espacio superior para separar del botón de back
                Spacer()
                    .frame(height: 10)
                
                // DatePicker con altura para mostrar solo 3 valores
                DatePicker(
                    "Select Time",
                    selection: $selectedTime,
                    in: minimumTime...,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 80) // Altura para mostrar solo 3 valores
                
            
                
                // Botón Done con ancho completo de la pantalla (igual que otros menús)
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
                    Text("Done")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlassButtonStyle(height: 50))
            }
            .padding(.horizontal, 8) // Padding del VStack (igual que otros menús)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    TimeTableView(
        raceConfig: RaceConfiguration(),
        onDone: {}
    )
}

