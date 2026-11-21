import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Vision

enum MathRecognitionError: LocalizedError {
    case unreadableImage
    case noText

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "I couldn't open that image."
        case .noText:
            return "I couldn't recognize math in this image. Try stronger lighting or type the problem."
        }
    }
}

struct MathImageRecognizer {
    func recognizeText(in url: URL) async throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0) else {
            throw MathRecognitionError.unreadableImage
        }
        return try await recognize(image)
    }

    func recognizeText(in strokes: [[CGPoint]], size: CGSize) async throws -> String {
        guard size.width > 0, size.height > 0 else { throw MathRecognitionError.noText }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw MathRecognitionError.unreadableImage
        }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(6)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes {
            guard let first = stroke.first else { continue }
            context.beginPath()
            context.move(to: first)
            for point in stroke.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }
        guard let image = context.makeImage() else { throw MathRecognitionError.unreadableImage }
        return try await recognize(image)
    }

    private func recognize(_ image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    continuation.resume(throwing: MathRecognitionError.noText)
                } else {
                    continuation.resume(returning: text)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.customWords = ["sin", "cos", "tan", "sqrt", "integral", "derivative", "mean", "median"]
            let handler = VNImageRequestHandler(cgImage: image)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
