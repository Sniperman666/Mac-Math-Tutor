import AppKit
import Foundation
import MathTutorCore
import UniformTypeIdentifiers

@MainActor
final class TutorViewModel: ObservableObject {
    @Published var problem = ""
    @Published var solution: MathSolution?
    @Published var history: [MathSolution] = []
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var recognitionNeedsReview = false
    @Published var selectedInputMode: InputMode = .type

    private let engine = MathTutorEngine()
    private let recognizer = MathImageRecognizer()

    func solve() async {
        errorMessage = nil
        isWorking = true
        solution = nil
        defer { isWorking = false }
        do {
            let newSolution = try engine.solve(problem)
            solution = newSolution
            history.insert(newSolution, at: 0)
            if history.count > 30 {
                history.removeLast()
            }
        } catch {
            solution = nil
            errorMessage = error.localizedDescription
        }
    }

    func loadExample(_ example: String) {
        problem = example
        selectedInputMode = .type
        recognitionNeedsReview = false
    }

    func reset() {
        problem = ""
        solution = nil
        errorMessage = nil
        recognitionNeedsReview = false
    }

    func pasteProblem() {
        guard let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            errorMessage = "The clipboard does not contain text."
            return
        }
        problem = value
        recognitionNeedsReview = false
    }

    func recognizeImage(at url: URL) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            problem = try await recognizer.recognizeText(in: url)
            recognitionNeedsReview = true
            selectedInputMode = .type
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recognizeDrawing(_ strokes: [[CGPoint]], size: CGSize) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            problem = try await recognizer.recognizeText(in: strokes, size: size)
            recognitionNeedsReview = true
            selectedInputMode = .type
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copySolution() {
        guard let solution else { return }
        let steps = solution.steps.enumerated().map { index, step in
            "\(index + 1). \(step.title)\n   \(step.explanation)\n   \(step.expression)"
        }
        let text = """
        \(solution.interpretation)

        \(steps.joined(separator: "\n\n"))

        Answer: \(solution.answer)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

enum InputMode: String, CaseIterable, Hashable, Identifiable {
    case type = "Type or paste"
    case draw = "Draw"

    var id: String { rawValue }
}
