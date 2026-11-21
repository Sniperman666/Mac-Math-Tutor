import Foundation

public enum MathTutorError: LocalizedError, Equatable {
    case emptyInput
    case unsupported(String)
    case invalidExpression(String)
    case ambiguousInput(String)
    case missingValue(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Enter a problem first."
        case let .unsupported(message):
            return message
        case let .invalidExpression(expression):
            return "I couldn't read “\(expression)”. Check the operators and parentheses."
        case let .ambiguousInput(message):
            return message
        case let .missingValue(value):
            return "The problem needs \(value) before I can solve it."
        }
    }
}
