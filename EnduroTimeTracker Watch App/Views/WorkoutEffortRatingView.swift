//
//  WorkoutEffortRatingView.swift
//  EnduroTimeTracker Watch App
//
//  Interfaz inspirada en la pantalla nativa de esfuerzo de Apple Fitness (watchOS).
//  Apple no expone esta UI como API pública; replicamos el diseño e interacción.
//

import SwiftUI
import WatchKit

struct WorkoutEffortRatingView: View {
    @State private var selectedScore = 6
    @State private var crownValue = 6.0
    @FocusState private var isCrownFocused: Bool
    
    let onContinue: (Int) -> Void
    
    private let barHeights: [CGFloat] = [26, 40, 52, 64, 76]
    
    var body: some View {
        ZStack {
            effortBackground
            
            VStack(spacing: 0) {
                toolbarRow
                
                Spacer(minLength: 4)
                
                effortScale
                    .frame(height: 88)
                    .padding(.horizontal, 6)
                
                Spacer(minLength: 6)
                
                effortSummaryCapsule
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: 1.0,
            through: 10.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            selectedScore = min(10, max(1, Int(newValue.rounded())))
        }
        .onAppear {
            crownValue = Double(selectedScore)
            isCrownFocused = true
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbarRow: some View {
        HStack {
            Color.clear
                .frame(width: 36, height: 36)
            
            Spacer()
            
            Button(action: { onContinue(selectedScore) }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }
    
    // MARK: - Scale
    
    private var effortScale: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / 10
            let thumbX = columnWidth * (CGFloat(selectedScore) - 0.5) - geometry.size.width / 2
            
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<5, id: \.self) { barIndex in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.55, green: 0.32, blue: 0.78).opacity(0.55),
                                        Color(red: 0.42, green: 0.24, blue: 0.62).opacity(0.45)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: columnWidth * 2 - 3, height: barHeights[barIndex])
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                HStack(spacing: 0) {
                    ForEach(1...10, id: \.self) { score in
                        Circle()
                            .fill(Color.white.opacity(score == selectedScore ? 0.9 : 0.35))
                            .frame(width: score == selectedScore ? 5 : 4, height: score == selectedScore ? 5 : 4)
                            .frame(width: columnWidth, height: 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectScore(score)
                            }
                    }
                }
                .padding(.bottom, 2)
                
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 10, height: min(geometry.size.height - 8, 72))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .offset(x: thumbX, y: -10)
                    .animation(.easeOut(duration: 0.15), value: selectedScore)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(0, value.location.x), geometry.size.width)
                        let score = Int((x / columnWidth).rounded(.down)) + 1
                        selectScore(min(10, max(1, score)))
                    }
            )
        }
    }
    
    private var effortSummaryCapsule: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                Text("\(selectedScore)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            Text(effortDescription(for: selectedScore))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
    }
    
    private var effortBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.10, blue: 0.38),
                Color(red: 0.34, green: 0.16, blue: 0.52),
                Color(red: 0.26, green: 0.12, blue: 0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private func selectScore(_ score: Int) {
        guard score != selectedScore else { return }
        selectedScore = score
        crownValue = Double(score)
        WKInterfaceDevice.current().play(.click)
    }
    
    private func effortDescription(for score: Int) -> String {
        switch score {
        case 1, 2:
            return "effortEasy".localized
        case 3, 4:
            return "effortLight".localized
        case 5, 6:
            return "effortModerate".localized
        case 7, 8:
            return "effortHard".localized
        default:
            return "effortAllOut".localized
        }
    }
}

#Preview {
    WorkoutEffortRatingView(onContinue: { _ in })
}
