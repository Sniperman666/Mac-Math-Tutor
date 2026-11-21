import Foundation

public indirect enum MathExpression: Equatable {
    case number(Double)
    case variable(String)
    case unary(String, MathExpression)
    case binary(String, MathExpression, MathExpression)
    case function(String, MathExpression)

    public func evaluate(_ variables: [String: Double] = [:], angleUnit: AngleUnit = .radians) throws -> Double {
        switch self {
        case let .number(value):
            return value
        case let .variable(name):
            if name == "pi" {
                return .pi
            }
            if name == "e" {
                return exp(1)
            }
            guard let value = variables[name] else {
                throw MathTutorError.missingValue(name)
            }
            return value
        case let .unary(operatorName, operand):
            let value = try operand.evaluate(variables, angleUnit: angleUnit)
            return operatorName == "-" ? -value : value
        case let .binary(operatorName, left, right):
            let leftValue = try left.evaluate(variables, angleUnit: angleUnit)
            let rightValue = try right.evaluate(variables, angleUnit: angleUnit)
            switch operatorName {
            case "+": return leftValue + rightValue
            case "-": return leftValue - rightValue
            case "*": return leftValue * rightValue
            case "/":
                guard rightValue != 0 else {
                    throw MathTutorError.unsupported("Division by zero is undefined.")
                }
                return leftValue / rightValue
            case "^":
                let result = pow(leftValue, rightValue)
                guard result.isFinite else {
                    throw MathTutorError.unsupported("This power does not have a finite real value.")
                }
                return result
            default: throw MathTutorError.unsupported("The operator \(operatorName) is not supported.")
            }
        case let .function(name, argument):
            let value = try argument.evaluate(variables, angleUnit: angleUnit)
            let radians = angleUnit == .degrees ? value * .pi / 180 : value
            switch name.lowercased() {
            case "sin": return sin(radians)
            case "cos": return cos(radians)
            case "tan":
                guard abs(cos(radians)) > 1e-15 else {
                    throw MathTutorError.unsupported("The tangent is undefined at this angle.")
                }
                return tan(radians)
            case "sqrt":
                guard value >= 0 else { throw MathTutorError.unsupported("The square root needs a nonnegative value.") }
                return sqrt(value)
            case "ln":
                guard value > 0 else { throw MathTutorError.unsupported("The natural logarithm needs a positive value.") }
                return log(value)
            case "abs": return abs(value)
            default: throw MathTutorError.unsupported("The function \(name) is not supported.")
            }
        }
    }

    public var rendered: String {
        switch self {
        case let .number(value):
            return MathFormatting.number(value)
        case let .variable(name):
            return name
        case let .unary(operatorName, operand):
            return "\(operatorName)(\(operand.rendered))"
        case let .binary(operatorName, left, right):
            return "(\(left.rendered) \(operatorName) \(right.rendered))"
        case let .function(name, argument):
            return "\(name)(\(argument.rendered))"
        }
    }

    public func differentiated(withRespectTo variable: String, angleUnit: AngleUnit = .radians) throws -> MathExpression {
        switch self {
        case .number:
            return .number(0)
        case let .variable(name):
            return name == variable ? .number(1) : .number(0)
        case let .unary(operatorName, operand):
            return .unary(operatorName, try operand.differentiated(withRespectTo: variable, angleUnit: angleUnit))
        case let .binary("+", left, right):
            return .binary("+", try left.differentiated(withRespectTo: variable, angleUnit: angleUnit), try right.differentiated(withRespectTo: variable, angleUnit: angleUnit))
        case let .binary("-", left, right):
            return .binary("-", try left.differentiated(withRespectTo: variable, angleUnit: angleUnit), try right.differentiated(withRespectTo: variable, angleUnit: angleUnit))
        case let .binary("*", left, right):
            return .binary(
                "+",
                .binary("*", try left.differentiated(withRespectTo: variable, angleUnit: angleUnit), right),
                .binary("*", left, try right.differentiated(withRespectTo: variable, angleUnit: angleUnit))
            )
        case let .binary("/", left, right):
            return .binary(
                "/",
                .binary(
                    "-",
                    .binary("*", try left.differentiated(withRespectTo: variable, angleUnit: angleUnit), right),
                    .binary("*", left, try right.differentiated(withRespectTo: variable, angleUnit: angleUnit))
                ),
                .binary("^", right, .number(2))
            )
        case let .binary("^", base, exponent) where exponent.variables.isEmpty:
            guard base.variables.contains(variable) else { return .number(0) }
            let exponentValue = try exponent.evaluate([:], angleUnit: angleUnit)
            return .binary(
                "*",
                .binary("*", exponent, .binary("^", base, .number(exponentValue - 1))),
                try base.differentiated(withRespectTo: variable, angleUnit: angleUnit)
            )
        case .binary("^", _, _):
            throw MathTutorError.unsupported("The local derivative engine does not support a variable exponent.")
        case let .binary(operatorName, _, _):
            throw MathTutorError.unsupported("The local derivative engine cannot apply the \(operatorName) operator.")
        case let .function(name, argument):
            let inner = try argument.differentiated(withRespectTo: variable, angleUnit: angleUnit)
            let outer: MathExpression
            switch name.lowercased() {
            case "sin": outer = .function("cos", argument)
            case "cos": outer = .unary("-", .function("sin", argument))
            case "tan": outer = .binary("+", .number(1), .binary("^", .function("tan", argument), .number(2)))
            case "sqrt": outer = .binary("/", .number(1), .binary("*", .number(2), .function("sqrt", argument)))
            case "ln": outer = .binary("/", .number(1), argument)
            default:
                throw MathTutorError.unsupported("The function \(name) is not supported for differentiation.")
            }
            let scaledOuter: MathExpression
            if angleUnit == .degrees && ["sin", "cos", "tan"].contains(name.lowercased()) {
                scaledOuter = .binary("*", .binary("/", .variable("pi"), .number(180)), outer)
            } else {
                scaledOuter = outer
            }
            return .binary("*", scaledOuter, inner)
        }
    }

    public var variables: Set<String> {
        switch self {
        case .number:
            return []
        case let .variable(name):
            return ["pi", "e"].contains(name) ? [] : [name]
        case let .unary(_, operand):
            return operand.variables
        case let .binary(_, left, right):
            return left.variables.union(right.variables)
        case let .function(_, argument):
            return argument.variables
        }
    }

    public func simplified(angleUnit: AngleUnit = .radians) -> MathExpression {
        let simplifyOperand: (MathExpression) -> MathExpression = { $0.simplified(angleUnit: angleUnit) }
        switch self {
        case .number, .variable:
            return self
        case let .unary(operatorName, operand):
            let value = simplifyOperand(operand)
            if case let .number(number) = value {
                return .number(operatorName == "-" ? -number : number)
            }
            return .unary(operatorName, value)
        case let .binary(operatorName, rawLeft, rawRight):
            let left = simplifyOperand(rawLeft)
            let right = simplifyOperand(rawRight)
            if case .number = left, case .number = right,
               let value = try? MathExpression.binary(operatorName, left, right).evaluate([:], angleUnit: angleUnit) {
                return .number(value)
            }
            switch operatorName {
            case "+":
                if left == .number(0) { return right }
                if right == .number(0) { return left }
            case "-":
                if right == .number(0) { return left }
                if left == right && left.isDefinedForAllRealVariables { return .number(0) }
            case "*":
                if left == .number(0) && right.isDefinedForAllRealVariables { return .number(0) }
                if right == .number(0) && left.isDefinedForAllRealVariables { return .number(0) }
                if left == .number(1) { return right }
                if right == .number(1) { return left }
            case "^":
                if right == .number(0) && left.isDefinedForAllRealVariables { return .number(1) }
                if right == .number(1) { return left }
            default:
                break
            }
            return .binary(operatorName, left, right)
        case let .function(name, rawArgument):
            let argument = simplifyOperand(rawArgument)
            if case .number = argument,
               let value = try? MathExpression.function(name, argument).evaluate([:], angleUnit: angleUnit) {
                return .number(value)
            }
            return .function(name, argument)
        }
    }

    private var isDefinedForAllRealVariables: Bool {
        switch self {
        case .number, .variable:
            return true
        case let .unary(_, operand):
            return operand.isDefinedForAllRealVariables
        case let .binary(operatorName, left, right):
            return ["+", "-", "*"].contains(operatorName)
                && left.isDefinedForAllRealVariables && right.isDefinedForAllRealVariables
        case .function:
            return false
        }
    }
}

public enum AngleUnit {
    case radians
    case degrees
}

public enum MathFormatting {
    public static func number(_ value: Double) -> String {
        let normalized = abs(value) < 1e-12 ? 0 : value
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: normalized)) ?? String(normalized)
    }
}
