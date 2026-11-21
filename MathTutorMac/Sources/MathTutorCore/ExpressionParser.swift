import Foundation

public struct ExpressionParser {
    private let source: [Character]
    private var index = 0

    public init(_ text: String) {
        source = Array(text.lowercased().replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/"))
    }

    public static func parse(_ text: String) throws -> MathExpression {
        var parser = ExpressionParser(text)
        let result = try parser.parseExpression()
        parser.skipWhitespace()
        guard parser.index == parser.source.count else {
            throw MathTutorError.invalidExpression(text)
        }
        return result
    }

    private mutating func parseExpression(minPrecedence: Int = 0) throws -> MathExpression {
        skipWhitespace()
        var left = try parsePrefix()
        while true {
            skipWhitespace()
            guard index < source.count else { break }
            let character = source[index]
            let precedence: Int
            let operatorName: String
            if character == "+" || character == "-" {
                precedence = 1
                operatorName = String(character)
            } else if character == "*" || character == "/" {
                precedence = 2
                operatorName = String(character)
            } else if character == "^" {
                precedence = 3
                operatorName = String(character)
            } else {
                break
            }
            guard precedence >= minPrecedence else { break }
            index += 1
            let nextPrecedence = operatorName == "^" ? precedence : precedence + 1
            let right = try parseExpression(minPrecedence: nextPrecedence)
            left = .binary(operatorName, left, right)
        }
        return left
    }

    private mutating func parsePrefix() throws -> MathExpression {
        skipWhitespace()
        guard index < source.count else { throw MathTutorError.invalidExpression(String(source)) }
        let character = source[index]
        if character == "+" || character == "-" {
            index += 1
            return .unary(String(character), try parsePrefix())
        }
        if character == "(" {
            index += 1
            let expression = try parseExpression()
            skipWhitespace()
            guard index < source.count, source[index] == ")" else {
                throw MathTutorError.invalidExpression(String(source))
            }
            index += 1
            return expression
        }
        if character.isNumber || character == "." {
            return parseNumber()
        }
        if character.isLetter {
            let name = parseIdentifier()
            skipWhitespace()
            if index < source.count, source[index] == "(" {
                index += 1
                let argument = try parseExpression()
                skipWhitespace()
                guard index < source.count, source[index] == ")" else {
                    throw MathTutorError.invalidExpression(String(source))
                }
                index += 1
                return .function(name, argument)
            }
            return .variable(name)
        }
        throw MathTutorError.invalidExpression(String(source))
    }

    private mutating func parseNumber() -> MathExpression {
        let start = index
        var hasDecimal = false
        while index < source.count, source[index].isNumber || (source[index] == "." && !hasDecimal) {
            if source[index] == "." { hasDecimal = true }
            index += 1
        }
        let value = Double(String(source[start..<index])) ?? 0
        return .number(value)
    }

    private mutating func parseIdentifier() -> String {
        let start = index
        while index < source.count, source[index].isLetter {
            index += 1
        }
        return String(source[start..<index])
    }

    private mutating func skipWhitespace() {
        while index < source.count, source[index].isWhitespace {
            index += 1
        }
    }
}
