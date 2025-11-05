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
            VStack(spacing: 6) {
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
                    Button(action: {
                        selectedTimeControl = nil
                        showingTimePicker = true
                    }) {
                        HStack {
                            Text("Parc Ferme:")
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                            if let pfTime = raceConfig.parcFermeTime {
                                Text(formatTime(pfTime))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Select time")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .tint(raceConfig.parcFermeTime != nil ? .green : .gray)
                }
                
                // Lista de Time Controls con estilo Liquid Glass
                ForEach(raceConfig.timeControls) { tc in
                    Button(action: {
                        selectedTimeControl = tc
                        showingTimePicker = true
                    }) {
                        HStack {
                            Text(tc.name)
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                            if let time = tc.scheduledTime {
                                Text(formatTime(time))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Select time")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .tint(tc.scheduledTime != nil ? .green : .gray)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteTimeControl(tc)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                // Botón Add Time Control con estilo Liquid Glass
                Button(action: addTimeControl) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                        Text("Add Time Control")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .tint(.yellow)
                .padding(.top, 4)
                
                Spacer()
                    .frame(height: 4)
                
                // Botón Done con estilo Liquid Glass
                Button(action: onDone) {
                    Text("Done")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(.yellow)
                .padding(.top, 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .toolbar {
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
        .sheet(isPresented: $showingTimePicker) {
            TimePickerView(
                initialTime: getInitialTime(),
                minimumTime: getMinimumTime(),
                onTimeSelected: { time in
                    saveTime(time)
                }
            )
        }
        .onAppear {
            // Inicializar con 2 Time Controls por defecto (sin horarios)
            if raceConfig.timeControls.isEmpty {
                let defaultTC1 = TimeControl(name: "Time Control 1")
                let defaultTC2 = TimeControl(name: "Time Control 2")
                raceConfig.timeControls = [defaultTC1, defaultTC2]
            }
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
    
    private func deleteTimeControl(_ tc: TimeControl) {
        raceConfig.timeControls.removeAll { $0.id == tc.id }
    }
    
    private func validateAndCleanTimeControls() {
        // Validación se implementará después con la lógica completa
        // Por ahora solo estructura visual
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
        VStack {
            DatePicker(
                "Select Time",
                selection: $selectedTime,
                in: minimumTime...,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            
            Button("Done") {
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
            }
            .buttonStyle(.glassProminent)
            .tint(.yellow)
        }
        .padding()
    }
}

#Preview {
    TimeTableView(
        raceConfig: RaceConfiguration(),
        onDone: {}
    )
}

