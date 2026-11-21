import AppKit
import Foundation
import MathTutorCore
import UniformTypeIdentifiers

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

    func solve() {
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

    func recognizeImage(at url: URL) {
        guard !isWorking else { return }
        let hasAccess = url.startAccessingSecurityScopedResource()
        let recognizer = self.recognizer
        startRecognition {
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            return try recognizer.recognizeText(in: url)
        }
    }

    func recognizeDrawing(_ strokes: [[CGPoint]], size: CGSize) {
        guard !isWorking else { return }
        let recognizer = self.recognizer
        startRecognition {
            try recognizer.recognizeText(in: strokes, size: size)
        }
    }

    private func startRecognition(_ work: @escaping () throws -> String) {
        isWorking = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try work() }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let text):
                    self.problem = text
                    self.recognitionNeedsReview = true
                    self.selectedInputMode = .type
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func copySolution() {
        guard let solution = solution else { return }
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
