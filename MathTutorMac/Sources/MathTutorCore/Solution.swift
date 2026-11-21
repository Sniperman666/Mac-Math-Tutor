import Foundation

public struct SolutionStep: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let explanation: String
    public let expression: String

    public init(title: String, explanation: String, expression: String) {
        self.id = UUID()
        self.title = title
        self.explanation = explanation
        self.expression = expression
    }
}

public struct MathSolution: Identifiable, Equatable {
    public let id: UUID
    public let originalProblem: String
    public let subject: String
    public let interpretation: String
    public let steps: [SolutionStep]
    public let answer: String
    public let confidence: Double

    public init(
        originalProblem: String,
        subject: String,
        interpretation: String,
        steps: [SolutionStep],
        answer: String,
        confidence: Double = 1
    ) {
        self.id = UUID()
        self.originalProblem = originalProblem
        self.subject = subject
        self.interpretation = interpretation
        self.steps = steps
        self.answer = answer
        self.confidence = confidence
    }
}
