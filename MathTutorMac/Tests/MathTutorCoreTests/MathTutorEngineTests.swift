import XCTest
@testable import MathTutorCore

final class MathTutorEngineTests: XCTestCase {
    private let engine = MathTutorEngine()

    func testParsesOperationPrecedence() throws {
        let expression = try ExpressionParser.parse("2 + 3 * (4 - 1)")
        XCTAssertEqual(try expression.evaluate(), 11)
    }

    func testSolvesArithmetic() throws {
        let solution = try engine.solve("2 + 3 * (4 - 1)")
        XCTAssertEqual(solution.answer, "11")
        XCTAssertGreaterThanOrEqual(solution.steps.count, 2)
    }

    func testSolvesLinearEquationWithImplicitMultiplication() throws {
        let solution = try engine.solve("2x + 4 = 10")
        XCTAssertEqual(solution.answer, "x = 3")
        XCTAssertEqual(solution.steps.count, 3)
    }

    func testSolvesQuadraticEquation() throws {
        let solution = try engine.solve("x^2 - 5x + 6 = 0")
        XCTAssertEqual(solution.answer, "2, 3")
    }

    func testDifferentiatesPowerExpressions() throws {
        let solution = try engine.solve("differentiate x^3 + 2x")
        XCTAssertTrue(solution.answer.contains("3"))
        XCTAssertTrue(solution.answer.contains("x"))
    }

    func testCalculatesPopulationStandardDeviation() throws {
        let solution = try engine.solve("standard deviation 2, 4, 6")
        XCTAssertEqual(solution.answer, "Standard deviation = 1.63299316")
    }

    func testUsesCircleAreaFormula() throws {
        let solution = try engine.solve("area of a circle with radius 4")
        XCTAssertEqual(solution.answer, "50.26548246")
        XCTAssertEqual(solution.subject, "Geometry")
    }

    func testEvaluatesTrigInDegrees() throws {
        let solution = try engine.solve("sin(30) degrees")
        XCTAssertEqual(solution.answer, "0.5")
    }

    func testRejectsUnknownVariableWithoutInventingAValue() {
        XCTAssertThrowsError(try engine.solve("x + 1"))
    }

    func testArithmeticShowsIntermediateCalculations() throws {
        let solution = try engine.solve("2 + 3 * (4 - 1)")
        XCTAssertEqual(solution.answer, "11")
        XCTAssertEqual(solution.steps.map(\.expression), [
            "(2 + (3 * (4 - 1)))", "4 - 1 = 3", "3 * 3 = 9", "2 + 9 = 11"
        ])
    }

    func testUnaryMinusAndExponentPrecedence() throws {
        XCTAssertEqual(try engine.solve("-2^2").answer, "-4")
        XCTAssertEqual(try engine.solve("2^-2").answer, "0.25")
    }

    func testSolvePrefixAndQuadraticExplanation() throws {
        let solution = try engine.solve("solve x^2 - 5x + 6 = 0")
        XCTAssertEqual(solution.answer, "2, 3")
        XCTAssertTrue(solution.steps.contains { $0.expression.contains("±") })
    }

    func testDerivativeExplanationShowsAppliedRules() throws {
        let solution = try engine.solve("differentiate x^2 + 3")
        XCTAssertTrue(solution.steps.contains { $0.explanation.contains("power rule") && $0.expression.contains("d/dx") })
        XCTAssertTrue(solution.steps.contains { $0.explanation.contains("each term") })
        XCTAssertEqual(solution.answer, "f′(x) = (2 * x)")
    }

    func testRejectsNonPolynomialInsteadOfGuessing() {
        XCTAssertThrowsError(try engine.solve("x^4 - x^2 = 0"))
        XCTAssertThrowsError(try engine.solve("sin(x) = 0"))
        XCTAssertThrowsError(try engine.solve("1 / x = 1"))
    }

    func testRejectsUndefinedArithmetic() {
        XCTAssertThrowsError(try engine.solve("1 / 0"))
        XCTAssertThrowsError(try engine.solve("tan(90) degrees"))
        XCTAssertThrowsError(try engine.solve("(-1)^0.5"))
    }

    func testTrigonometricDerivativesRespectAngleUnits() throws {
        for source in ["sin(x)", "cos(x)", "tan(x)", "sin(cos(x))", "x^sin(30)"] {
            let expression = try ExpressionParser.parse(source)
            for unit in [AngleUnit.radians, .degrees] {
                let derivative = try expression.differentiated(withRespectTo: "x", angleUnit: unit)
                    .simplified(angleUnit: unit)
                let x = 2.0
                let h = 1e-5
                let numerical = try (expression.evaluate(["x": x + h], angleUnit: unit)
                    - expression.evaluate(["x": x - h], angleUnit: unit)) / (2 * h)
                XCTAssertEqual(try derivative.evaluate(["x": x], angleUnit: unit), numerical, accuracy: 1e-7, "\(source)")
            }
        }
    }

    func testDegreeDifferentiationIsShownInSolver() throws {
        let solution = try engine.solve("differentiate sin(x) degrees")
        XCTAssertTrue(solution.answer.contains("pi / 180"))
        XCTAssertTrue(solution.steps.contains { $0.explanation.contains("degrees") })
        XCTAssertTrue(solution.steps.contains { $0.explanation.contains("π/180") })
    }

    func testSimplificationPreservesUndefinedSubexpressions() throws {
        for (source, x) in [("0 * (1 / x)", 0.0), ("(1 / x) - (1 / x)", 0.0),
                            ("sqrt(x)^0", -1.0), ("0 * ln(x)", 0.0)] {
            let expression = try ExpressionParser.parse(source)
            let simplified = expression.simplified()
            XCTAssertThrowsError(try expression.evaluate(["x": x]), "\(source)")
            XCTAssertThrowsError(try simplified.evaluate(["x": x]), "\(source)")
        }
        XCTAssertEqual(try ExpressionParser.parse("0 * x").simplified(), .number(0))
    }

    func testConstantFunctionSimplificationUsesAngleUnit() throws {
        let expression = try ExpressionParser.parse("sin(30)")
        XCTAssertEqual(try expression.simplified(angleUnit: .degrees).evaluate(), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try expression.simplified().evaluate(), sin(30), accuracy: 1e-12)
    }
}
