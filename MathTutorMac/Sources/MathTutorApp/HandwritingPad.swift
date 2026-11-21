import SwiftUI

struct HandwritingPad: View {
    @EnvironmentObject private var viewModel: TutorViewModel
    @State private var strokes: [[CGPoint]] = []
    @State private var activeStroke: [CGPoint] = []
    @State private var canvasSize = CGSize(width: 1, height: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                ZStack {
                    Color.white
                    ForEach(Array(allStrokes.enumerated()), id: \.offset) { _, stroke in
                        Path { path in
                            add(stroke, to: &path)
                        }
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            activeStroke.append(value.location)
                        }
                        .onEnded { _ in
                            if !activeStroke.isEmpty {
                                strokes.append(activeStroke)
                            }
                            activeStroke = []
                        }
                )
                .onAppear { canvasSize = geometry.size }
                .onChange(of: geometry.size) { newValue in
                    canvasSize = newValue
                }
            }
            HStack {
                Button("Clear") {
                    strokes = []
                    activeStroke = []
                }
                Spacer()
                Button("Recognize handwriting") {
                    Task { await viewModel.recognizeDrawing(strokes, size: canvasSize) }
                }
                .buttonStyle(DefaultButtonStyle())
                .disabled(strokes.isEmpty || viewModel.isWorking)
            }
            Text("Use a stylus or mouse. Printed characters work better than cursive.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var allStrokes: [[CGPoint]] {
        activeStroke.isEmpty ? strokes : strokes + [activeStroke]
    }

    private func add(_ stroke: [CGPoint], to path: inout Path) {
        guard let first = stroke.first else { return }
        path.move(to: first)
        for point in stroke.dropFirst() {
            path.addLine(to: point)
        }
    }
}
