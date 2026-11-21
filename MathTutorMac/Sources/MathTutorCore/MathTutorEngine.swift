import Foundation

public struct MathTutorEngine: Sendable {
    public init() {}

    public func solve(_ rawProblem: String) throws -> MathSolution {
        let problem = rawProblem
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "π", with: "pi")
        guard !problem.isEmpty else { throw MathTutorError.emptyInput }

        let lower = problem.lowercased()
        if lower.contains("="), !lower.contains("mean") {
            return try solveEquation(problem)
        }
        if lower.hasPrefix("differentiate") || lower.contains("derivative of") {
            return try differentiate(problem)
        }
        if lower.hasPrefix("integrate") || lower.contains("integral of") {
            return try integrate(problem)
        }
        if containsAny(lower, ["mean", "median", "mode", "variance", "standard deviation", "average"]) {
            return try solveStatistics(problem)
        }
        if containsAny(lower, ["area", "perimeter", "circumference", "hypotenuse", "right triangle", "volume"]) {
            return try solveGeometry(problem)
        }

        let expressionText = extractExpression(from: lower, labels: ["simplify", "evaluate", "calculate"])
        let expression = try ExpressionParser.parse(expressionText)
        let variables = expression.variables
        if variables.isEmpty {
            let angleUnit: AngleUnit = lower.contains("degrees") || lower.contains("degree") ? .degrees : .radians
            let result = try expression.evaluate([:], angleUnit: angleUnit)
            let subject = containsAny(lower, ["sin", "cos", "tan"]) ? "Trigonometry" : "Arithmetic"
            let unitNote = subject == "Trigonometry" && angleUnit == .degrees ? "Angles are interpreted in degrees." : "No special assumptions are needed."
            return MathSolution(
                originalProblem: problem,
                subject: subject,
                interpretation: "Evaluate \(expression.rendered). \(unitNote)",
                steps: [
                    .init(title: "Read the expression", explanation: "Translate the problem into mathematical notation.", expression: expression.rendered),
                    .init(title: "Apply the operations", explanation: "Follow parentheses, exponents, multiplication/division, and addition/subtraction.", expression: "\(expression.rendered) = \(MathFormatting.number(result))")
                ],
                answer: MathFormatting.number(result)
            )
        }
        let names = variables.sorted().joined(separator: ", ")
        throw MathTutorError.ambiguousInput("The expression contains \(names). Ask me to solve an equation, differentiate, or substitute values.")
    }

    private func solveEquation(_ problem: String) throws -> MathSolution {
        let sides = problem.components(separatedBy: "=")
        guard sides.count == 2 else {
            throw MathTutorError.ambiguousInput("Use one equals sign, for example 2x + 4 = 10.")
        }
        let leftText = expandImplicitMultiplication(sides[0])
        let rightText = expandImplicitMultiplication(sides[1])
        let left = try ExpressionParser.parse(leftText)
        let right = try ExpressionParser.parse(rightText)
        let variables = left.variables.union(right.variables)
        guard variables.isEmpty || (variables.count == 1 && variables.contains("x")) else {
            throw MathTutorError.unsupported("Equations in this version support one variable named x.")
        }
        let f: (Double) throws -> Double = { x in
            try left.evaluate(["x": x]) - right.evaluate(["x": x])
        }
        let atMinusOne = try f(-1)
        let atZero = try f(0)
        let atOne = try f(1)
        let a = (atMinusOne + atOne - 2 * atZero) / 2
        let b = (atOne - atMinusOne) / 2
        let c = atZero
        let thirdCheck = try f(2)
        let quadraticPrediction = 4 * a + 2 * b + c
        if abs(a) > 1e-9 && abs(thirdCheck - quadraticPrediction) < 1e-6 {
            let discriminant = b * b - 4 * a * c
            guard discriminant >= -1e-10 else {
                return MathSolution(
                    originalProblem: problem,
                    subject: "Algebra",
                    interpretation: "The quadratic has no real solutions because its discriminant is negative.",
                    steps: [
                        .init(title: "Move everything to one side", explanation: "Write the equation in standard form.", expression: "\(MathFormatting.number(a))x² + \(MathFormatting.number(b))x + \(MathFormatting.number(c)) = 0"),
                        .init(title: "Compute the discriminant", explanation: "The discriminant is b² - 4ac.", expression: "Δ = \(MathFormatting.number(b))² - 4(\(MathFormatting.number(a)))(\(MathFormatting.number(c))) = \(MathFormatting.number(discriminant))")
                    ],
                    answer: "No real solution",
                    confidence: 0.95
                )
            }
            let rootA = (-b - sqrt(max(0, discriminant))) / (2 * a)
            let rootB = (-b + sqrt(max(0, discriminant))) / (2 * a)
            let roots = abs(rootA - rootB) < 1e-9 ? [rootA] : [rootA, rootB]
            return MathSolution(
                originalProblem: problem,
                subject: "Algebra",
                interpretation: "Solve the quadratic in standard form.",
                steps: [
                    .init(title: "Move everything to one side", explanation: "Subtract the right side from the left side.", expression: "\(MathFormatting.number(a))x² + \(MathFormatting.number(b))x + \(MathFormatting.number(c)) = 0"),
                    .init(title: "Find the discriminant", explanation: "Use Δ = b² - 4ac.", expression: "Δ = \(MathFormatting.number(discriminant))"),
                    .init(title: "Use the quadratic formula", explanation: "Substitute a, b, and the discriminant into x = (-b ± √Δ) / 2a.", expression: roots.map(MathFormatting.number).joined(separator: " or "))
                ],
                answer: roots.map(MathFormatting.number).joined(separator: ", ")
            )
        }
        let slope = atOne - atZero
        guard abs(slope) > 1e-10 else {
            return MathSolution(
                originalProblem: problem,
                subject: "Algebra",
                interpretation: "The variable cancels out.",
                steps: [.init(title: "Compare constants", explanation: "Both sides have no x-dependent difference.", expression: "\(left.rendered) = \(right.rendered)")],
                answer: abs(atZero) < 1e-10 ? "All real numbers" : "No solution"
            )
        }
        let linearPredictionAtTwo = 2 * slope + atZero
        guard abs(thirdCheck - linearPredictionAtTwo) < 1e-6,
              abs(try f(-2) - (-2 * slope + atZero)) < 1e-6 else {
            throw MathTutorError.unsupported("This expression is not linear or quadratic. The local solver supports linear and quadratic equations in x.")
        }
        let result = -atZero / slope
        return MathSolution(
            originalProblem: problem,
            subject: "Algebra",
            interpretation: "Solve a linear equation in x.",
            steps: [
                .init(title: "Combine like terms", explanation: "Subtract the right side from the left.", expression: "\(MathFormatting.number(slope))x + \(MathFormatting.number(atZero)) = 0"),
                .init(title: "Isolate the variable term", explanation: "Subtract the constant from both sides.", expression: "\(MathFormatting.number(slope))x = \(MathFormatting.number(-atZero))"),
                .init(title: "Divide both sides", explanation: "Divide by the coefficient of x.", expression: "x = \(MathFormatting.number(-atZero)) / \(MathFormatting.number(slope))")
            ],
            answer: "x = \(MathFormatting.number(result))"
        )
    }

    private func differentiate(_ problem: String) throws -> MathSolution {
        let expressionText = extractExpression(from: problem.lowercased(), labels: ["differentiate", "derivative of"])
        let expression = try ExpressionParser.parse(expandImplicitMultiplication(expressionText))
        let derivative = try expression.differentiated(withRespectTo: "x").simplified()
        return MathSolution(
            originalProblem: problem,
            subject: "Calculus",
            interpretation: "Differentiate \(expression.rendered) with respect to x.",
            steps: [
                .init(title: "Identify the rule", explanation: "Use sum, product, quotient, power, or chain rules for each part.", expression: expression.rendered),
                .init(title: "Differentiate each term", explanation: "Differentiate with respect to x, multiplying by inner derivatives where needed.", expression: derivative.rendered),
                .init(title: "Simplify", explanation: "Remove zero terms and combine simple factors.", expression: "f′(x) = \(derivative.rendered)")
            ],
            answer: "f′(x) = \(derivative.rendered)"
        )
    }

    private func integrate(_ problem: String) throws -> MathSolution {
        let expressionText = expandImplicitMultiplication(extractExpression(from: problem.lowercased(), labels: ["integrate", "integral of"]))
            .replacingOccurrences(of: " dx", with: "")
        if let match = firstRegexMatch(#"^\s*([+-]?\d*\.?\d*)?\s*\*?\s*x(?:\^([+-]?\d+\.?\d*))?\s*$"#, in: expressionText) {
            let coefficient = match[1].isEmpty || match[1] == "+" ? 1 : match[1] == "-" ? -1 : Double(match[1]) ?? 1
            let exponent = match[2].isEmpty ? 1 : Double(match[2]) ?? 1
            guard abs(exponent + 1) > 1e-10 else {
                throw MathTutorError.unsupported("The integral of 1/x is ln|x| + C and should be handled symbolically.")
            }
            let newExponent = exponent + 1
            let newCoefficient = coefficient / newExponent
            return MathSolution(
                originalProblem: problem,
                subject: "Calculus",
                interpretation: "Integrate one power of x with the reverse power rule.",
                steps: [
                    .init(title: "Read coefficient and exponent", explanation: "The term has coefficient \(MathFormatting.number(coefficient)) and exponent \(MathFormatting.number(exponent)).", expression: expressionText),
                    .init(title: "Increase the exponent", explanation: "Add 1 to the exponent.", expression: "x^\(MathFormatting.number(newExponent))"),
                    .init(title: "Divide by the new exponent", explanation: "For xⁿ, the antiderivative is xⁿ⁺¹/(n + 1), plus C.", expression: "\(MathFormatting.number(newCoefficient))x^\(MathFormatting.number(newExponent)) + C")
                ],
                answer: "\(MathFormatting.number(newCoefficient))x^\(MathFormatting.number(newExponent)) + C"
            )
        }
        throw MathTutorError.unsupported("This local calculus engine currently integrates one power term, such as 3x^2. Differentiate supports broader expressions.")
    }

    private func solveStatistics(_ problem: String) throws -> MathSolution {
        let values = problem
            .components(separatedBy: CharacterSet(charactersIn: ",; "))
            .compactMap(Double.init)
        guard values.count >= 2 else {
            throw MathTutorError.missingValue("at least two comma- or space-separated numbers")
        }
        let sorted = values.sorted()
        let lower = problem.lowercased()
        if lower.contains("median") {
            let middle = sorted.count / 2
            let median = sorted.count.isMultiple(of: 2)
                ? (sorted[middle - 1] + sorted[middle]) / 2
                : sorted[middle]
            return MathSolution(
                originalProblem: problem,
                subject: "Statistics",
                interpretation: "Find the middle value or average of the two middle values.",
                steps: [
                    .init(title: "Sort the data", explanation: "Put the values in ascending order.", expression: sorted.map(MathFormatting.number).joined(separator: ", ")),
                    .init(title: "Locate the middle", explanation: sorted.count.isMultiple(of: 2) ? "There are two middle values, so average them." : "Choose the single middle value.", expression: MathFormatting.number(median))
                ],
                answer: "Median = \(MathFormatting.number(median))"
            )
        }
        let mean = values.reduce(0, +) / Double(values.count)
        if lower.contains("variance") || lower.contains("standard deviation") {
            let squaredDifferences = values.map { pow($0 - mean, 2) }
            let variance = squaredDifferences.reduce(0, +) / Double(values.count)
            let answer = lower.contains("standard deviation") ? sqrt(variance) : variance
            return MathSolution(
                originalProblem: problem,
                subject: "Statistics",
                interpretation: "Treat the given values as the entire population.",
                steps: [
                    .init(title: "Find the mean", explanation: "Add the values and divide by the number of values.", expression: "μ = \(MathFormatting.number(mean))"),
                    .init(title: "Square the differences", explanation: "For each value, calculate (value - mean)².", expression: squaredDifferences.map(MathFormatting.number).joined(separator: ", ")),
                    .init(title: lower.contains("standard deviation") ? "Take the square root" : "Average the squared differences", explanation: "Population variance averages the squared differences. Standard deviation is its square root.", expression: MathFormatting.number(answer))
                ],
                answer: "\(lower.contains("standard deviation") ? "Standard deviation" : "Variance") = \(MathFormatting.number(answer))"
            )
        }
        if lower.contains("mode") {
            let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
            let largest = counts.values.max() ?? 0
            let modes = counts.filter { $0.value == largest }.keys.sorted()
            let answer = largest == 1 ? "No mode" : modes.map(MathFormatting.number).joined(separator: ", ")
            return MathSolution(
                originalProblem: problem,
                subject: "Statistics",
                interpretation: "Find values occurring more often than the others.",
                steps: [.init(title: "Count occurrences", explanation: "Group equal values and compare their counts.", expression: answer)],
                answer: answer
            )
        }
        return MathSolution(
            originalProblem: problem,
            subject: "Statistics",
            interpretation: "Find the arithmetic mean of the values.",
            steps: [
                .init(title: "Add the values", explanation: "Add every listed value.", expression: "\(values.map(MathFormatting.number).joined(separator: " + ")) = \(MathFormatting.number(values.reduce(0, +)))"),
                .init(title: "Divide by the count", explanation: "There are \(values.count) values.", expression: "\(MathFormatting.number(values.reduce(0, +))) ÷ \(values.count) = \(MathFormatting.number(mean))")
            ],
            answer: "Mean = \(MathFormatting.number(mean))"
        )
    }

    private func solveGeometry(_ problem: String) throws -> MathSolution {
        let lower = problem.lowercased()
        let numbers = numberValues(in: problem)
        if lower.contains("circumference"), let radius = numbers.first {
            let answer = 2 * .pi * radius
            return MathSolution(
                originalProblem: problem,
                subject: "Geometry",
                interpretation: "The first measurement is interpreted as the circle's radius.",
                steps: [
                    .init(title: "Choose the formula", explanation: "Circumference is twice pi times the radius.", expression: "C = 2πr"),
                    .init(title: "Substitute", explanation: "Replace r with the given radius.", expression: "C = 2π(\(MathFormatting.number(radius)))"),
                    .init(title: "Calculate", explanation: "Multiply 2, pi, and the radius.", expression: "C = \(MathFormatting.number(answer))")
                ],
                answer: MathFormatting.number(answer)
            )
        }
        if lower.contains("area"), lower.contains("circle"), let radius = numbers.first {
            let answer = .pi * radius * radius
            return MathSolution(
                originalProblem: problem,
                subject: "Geometry",
                interpretation: "The first measurement is interpreted as the circle's radius.",
                steps: [
                    .init(title: "Choose the formula", explanation: "The area of a circle is pi times radius squared.", expression: "A = πr²"),
                    .init(title: "Substitute", explanation: "Replace r with the given radius.", expression: "A = π(\(MathFormatting.number(radius)))²"),
                    .init(title: "Calculate", explanation: "Square the radius, then multiply by pi.", expression: "A = \(MathFormatting.number(answer))")
                ],
                answer: MathFormatting.number(answer)
            )
        }
        if lower.contains("area"), lower.contains("triangle"), numbers.count >= 2 {
            let base = numbers[0], height = numbers[1], answer = base * height / 2
            return MathSolution(
                originalProblem: problem,
                subject: "Geometry",
                interpretation: "The first two values are interpreted as base and perpendicular height.",
                steps: [
                    .init(title: "Choose the formula", explanation: "Triangle area is one-half base times height.", expression: "A = ½bh"),
                    .init(title: "Substitute", explanation: "Use base \(MathFormatting.number(base)) and height \(MathFormatting.number(height)).", expression: "A = ½(\(MathFormatting.number(base)))(\(MathFormatting.number(height)))"),
                    .init(title: "Calculate", explanation: "Multiply base by height, then divide by 2.", expression: "A = \(MathFormatting.number(answer))")
                ],
                answer: MathFormatting.number(answer)
            )
        }
        if lower.contains("area") && numbers.count >= 2 {
            let width = numbers[0], height = numbers[1], answer = width * height
            return MathSolution(
                originalProblem: problem,
                subject: "Geometry",
                interpretation: "The first two measurements are interpreted as rectangle length and width.",
                steps: [
                    .init(title: "Choose the formula", explanation: "Rectangle area is length times width.", expression: "A = lw"),
                    .init(title: "Substitute", explanation: "Insert the two side lengths.", expression: "A = \(MathFormatting.number(width)) · \(MathFormatting.number(height))"),
                    .init(title: "Multiply", explanation: "Multiply the side lengths.", expression: "A = \(MathFormatting.number(answer))")
                ],
                answer: MathFormatting.number(answer)
            )
        }
        if lower.contains("hypotenuse"), numbers.count >= 2 {
            let answer = hypot(numbers[0], numbers[1])
            return MathSolution(
                originalProblem: problem,
                subject: "Geometry",
                interpretation: "The two values are the perpendicular legs of a right triangle.",
                steps: [
                    .init(title: "Use Pythagoras", explanation: "The sum of the squared legs equals the hypotenuse squared.", expression: "c² = a² + b²"),
                    .init(title: "Substitute", explanation: "Use the given leg lengths.", expression: "c² = \(MathFormatting.number(numbers[0]))² + \(MathFormatting.number(numbers[1]))²"),
                    .init(title: "Take the square root", explanation: "Length is nonnegative, so use the positive root.", expression: "c = \(MathFormatting.number(answer))")
                ],
                answer: MathFormatting.number(answer)
            )
        }
        throw MathTutorError.ambiguousInput("For geometry, try a request such as “area of a circle with radius 4”, “area of a triangle with base 6 height 3”, or “hypotenuse with legs 3 and 4”.")
    }

    private func extractExpression(from problem: String, labels: [String]) -> String {
        var result = problem
        for label in labels {
            if let range = result.range(of: label) {
                result = String(result[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        result = result
            .replacingOccurrences(of: "degrees", with: "")
            .replacingOccurrences(of: "degree", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .?:"))
        return result
    }

    private func expandImplicitMultiplication(_ input: String) -> String {
        let pattern = #"(?<=\d)(?=[a-z(])|(?<=[a-z)])(?=\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        return regex.stringByReplacingMatches(in: input, range: NSRange(input.startIndex..., in: input), withTemplate: "*")
    }

    private func firstRegexMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).map { rangeIndex in
            let range = match.range(at: rangeIndex)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return "" }
            return String(text[swiftRange])
        }
    }

    private func numberValues(in problem: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"-?\d+(?:\.\d+)?"#) else { return [] }
        return regex.matches(in: problem, range: NSRange(problem.startIndex..., in: problem)).compactMap {
            guard let range = Range($0.range, in: problem) else { return nil }
            return Double(problem[range])
        }
    }

    private func containsAny(_ value: String, _ candidates: [String]) -> Bool {
        candidates.contains { value.contains($0) }
    }
}
