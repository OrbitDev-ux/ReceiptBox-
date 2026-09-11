//
//  CameraController.swift
//  ReceiptBox
//
//  A thin AVFoundation session coordinator: permission handling, session
//  lifecycle, and still-photo capture. `@Observable` state (authorization,
//  running) is main-actor-facing so SwiftUI can read it directly; the
//  actual AVCaptureSession work happens on its own serial queue, as
//  AVFoundation requires — this type takes on that manual synchronization
//  itself rather than the checked-concurrency model, since the session
//  and its inputs/outputs are only ever touched from that one queue.

import AVFoundation
import Observation
import UIKit
import Vision

enum CameraAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum CameraCaptureError: Error, Equatable {
    case sessionUnavailable
    case captureFailed
}

@MainActor
@Observable
final class CameraController: NSObject, @unchecked Sendable {
    private(set) var authorizationState: CameraAuthorizationState = .notDetermined
    private(set) var isSessionRunning = false

    /// Whether the live preview currently frames something receipt-shaped.
    /// Purely advisory — a lightweight nudge toward capture readiness, not
    /// a gate on whether capture is allowed.
    private(set) var isDocumentDetected = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.receiptbox.camera.session", qos: .userInitiated)
    private var isConfigured = false
    @ObservationIgnored private lazy var frameAnalyzer = FrameAnalyzer { [weak self] detected in
        Task { @MainActor in
            self?.isDocumentDetected = detected
        }
    }

    /// Checks/requests permission and, if granted, starts the session.
    /// Safe to call every time the scan screen appears.
    func prepare() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            authorizationState = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationState = granted ? .authorized : .denied
        case .denied:
            authorizationState = .denied
        case .restricted:
            authorizationState = .restricted
        @unknown default:
            authorizationState = .denied
        }

        guard authorizationState == .authorized else { return }
        await startSession()
    }

    private func startSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                if !self.isConfigured {
                    self.configureSession()
                }
                if self.isConfigured, !self.session.isRunning {
                    self.session.startRunning()
                }
                let running = self.session.isRunning
                Task { @MainActor in
                    self.isSessionRunning = running
                }
                continuation.resume()
            }
        }
    }

    func stopSession() {
        isDocumentDetected = false
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
        isSessionRunning = false
    }

    /// Must run on `sessionQueue`.
    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { return }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        if session.canAddOutput(videoDataOutput) {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(frameAnalyzer, queue: sessionQueue)
            session.addOutput(videoDataOutput)
            videoDataOutput.connection(with: .video)?.videoRotationAngle = 90
        }

        isConfigured = true
    }

    func capturePhoto() async throws -> UIImage {
        guard isSessionRunning else { throw CameraCaptureError.sessionUnavailable }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            let delegate = PhotoCaptureDelegate { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            sessionQueue.async { [photoOutput] in
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }
}

/// `AVCapturePhotoOutput` holds its delegate weakly, so the delegate needs
/// to keep itself alive until its one callback fires.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, Error>) -> Void
    private var retainedSelf: PhotoCaptureDelegate?

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
        super.init()
        retainedSelf = self
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { retainedSelf = nil }

        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(.failure(CameraCaptureError.captureFailed))
            return
        }
        completion(.success(image))
    }
}

/// Runs a lightweight `VNDetectRectanglesRequest` over the live preview
/// feed to drive the viewfinder's "receipt framed" hint. Deliberately
/// coarse — a boolean readiness signal, not a precise quad for cropping —
/// so it stays cheap enough to run continuously on `sessionQueue`.
/// Frames arrive off the main actor (AVFoundation requires a background
/// delivery queue), so this type opts out of the project's default
/// MainActor isolation and hops back explicitly via `onDetectionChange`.
nonisolated private final class FrameAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onDetectionChange: @Sendable (Bool) -> Void
    private let request: VNDetectRectanglesRequest
    private var isBusy = false

    init(onDetectionChange: @escaping @Sendable (Bool) -> Void) {
        self.onDetectionChange = onDetectionChange
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.75
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.3
        request.quadratureTolerance = 30
        request.maximumObservations = 1
        self.request = request
        super.init()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isBusy, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        isBusy = true
        defer { isBusy = false }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            let detected = (request.results?.first?.confidence ?? 0) >= request.minimumConfidence
            onDetectionChange(detected)
        } catch {
            onDetectionChange(false)
        }
    }
}
