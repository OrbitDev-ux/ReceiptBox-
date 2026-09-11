//
//  BarcodeScannerController.swift
//  ReceiptBox
//
//  A separate AVFoundation session coordinator from CameraController: same
//  permission/lifecycle idioms (and the same `CameraAuthorizationState`),
//  but a genuinely different pipeline — `AVCaptureMetadataOutput` for
//  continuous barcode detection rather than `AVCapturePhotoOutput` for a
//  single still. Keeping them separate avoids one class juggling two
//  unrelated session configurations behind mode flags.
//
//  `session`/`metadataOutput`/`isConfigured` are `nonisolated(unsafe)` and
//  `configureSession()` is `nonisolated`: all four are, by construction,
//  only ever touched from `sessionQueue`, which is the actual
//  synchronization mechanism (AVCaptureSession's own documented threading
//  contract — configure and start/stop from one serial queue). Declaring
//  that explicitly, rather than leaving it implicitly MainActor-isolated,
//  is what lets the session-queue closures below compile without the
//  swarm of cross-actor Sendable warnings that same shape produces
//  otherwise.

@preconcurrency import AVFoundation
import Observation

@MainActor
@Observable
final class BarcodeScannerController: NSObject, @unchecked Sendable {
    private(set) var authorizationState: CameraAuthorizationState = .notDetermined
    private(set) var isSessionRunning = false

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "com.receiptbox.barcode.session", qos: .userInitiated)
    @ObservationIgnored nonisolated(unsafe) private var isConfigured = false

    /// Invoked on the main actor with the recognized barcode string
    /// whenever a supported symbology is detected. The scan view model owns
    /// de-duplication — this just reports every detection it sees.
    var onDetect: ((String) -> Void)?

    /// Checks/requests permission and, if granted, starts the session.
    /// Safe to call every time the barcode screen appears.
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
        let running = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            sessionQueue.async { [self] in
                if !isConfigured {
                    configureSession()
                }
                if isConfigured, !session.isRunning {
                    session.startRunning()
                }
                continuation.resume(returning: session.isRunning)
            }
        }
        isSessionRunning = running
    }

    func stopSession() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
        isSessionRunning = false
    }

    /// Must run on `sessionQueue`.
    nonisolated private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)

        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)

        // `availableMetadataObjectTypes` is only populated once the output
        // is attached to a session, and only the types it lists can be
        // requested — filtering avoids asking for one the device doesn't
        // actually support.
        let wanted: [AVMetadataObject.ObjectType] = [
            .ean13, .ean8, .upce, .code128, .code39, .code93, .itf14
        ]
        metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes.filter(wanted.contains)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

        isConfigured = true
    }
}

extension BarcodeScannerController: AVCaptureMetadataOutputObjectsDelegate {
    // The delegate queue was set to `.main` above, so this reliably runs on
    // the main thread even though the protocol requirement itself isn't
    // actor-isolated — `assumeIsolated` documents and checks that.
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = object.stringValue,
            !value.isEmpty
        else { return }

        MainActor.assumeIsolated {
            onDetect?(value)
        }
    }
}
