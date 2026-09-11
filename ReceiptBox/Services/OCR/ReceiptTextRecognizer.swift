//
//  ReceiptTextRecognizer.swift
//  ReceiptBox
//
//  Thin wrapper around Apple's on-device Vision text recognition. Nothing
//  here ever leaves the device — no network call, no third-party OCR
//  dependency. Runs off the main actor explicitly (via Task.detached)
//  since VNImageRequestHandler.perform(_:) is a blocking call and must
//  never run on the UI thread.

import Foundation
import Vision
import CoreGraphics

nonisolated enum ReceiptTextRecognizer {
    enum RecognitionError: Error, Equatable {
        case noTextFound
    }

    /// Recognized text lines, ordered top-to-bottom as they appear on the
    /// receipt.
    static func recognizeLines(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try performRecognition(on: cgImage, orientation: orientation)
        }.value
    }

    private static func performRecognition(
        on cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [String] {
        var recognizedLines: [String] = []
        var recognitionError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                recognitionError = error
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            recognizedLines = observations
                // Vision's coordinate origin is bottom-left, so a larger y
                // is higher up the receipt — sort descending for reading order.
                .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                .compactMap { $0.topCandidates(1).first?.string }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        if let recognitionError {
            throw recognitionError
        }
        guard !recognizedLines.isEmpty else {
            throw RecognitionError.noTextFound
        }
        return recognizedLines
    }
}
