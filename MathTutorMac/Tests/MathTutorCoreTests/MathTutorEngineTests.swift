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
}
