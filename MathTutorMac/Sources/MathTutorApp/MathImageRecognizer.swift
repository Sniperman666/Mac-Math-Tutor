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
    func recognizeText(in url: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MathRecognitionError.unreadableImage
        }
        return try recognize(image)
    }

    func recognizeText(in strokes: [[CGPoint]], size: CGSize) throws -> String {
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
        return try recognize(image)
    }

    private func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.customWords = ["sin", "cos", "tan", "sqrt", "integral", "derivative", "mean", "median"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw MathRecognitionError.noText }
        return text
    }
}
