//
//  ScanView.swift
//  ReceiptBox
//
//  Real camera capture → on-device Vision OCR → parsed draft → Review.
//  The corner-bracket viewfinder and dark, calm visual language carry
//  over unchanged from the earlier simulated version; only what happens
//  after the shutter tap is now real.

import AVFoundation
import SwiftUI

struct ScanView: View {
    private enum SheetRoute: Identifiable, Equatable {
        case reviewDraft(ReceiptDraft)
        case manualFallback

        var id: String {
            switch self {
            case .reviewDraft: "review"
            case .manualFallback: "manual"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = ScanViewModel()
    @State private var camera = CameraController()
    @State private var isScanLineDown = false
    @State private var capturedImage: UIImage?
    @State private var sheetRoute: SheetRoute?
    @State private var didSaveDraft = false

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar
                Spacer()
                scanFrame
                    .padding(.horizontal, Spacing.xl)
                Spacer()
                bottomControls
            }
            .padding(.vertical, Spacing.l)

            if isProcessing {
                processingOverlay
            }

            if case .failed(let failure) = viewModel.state {
                failureOverlay(failure)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard viewModel.state == .scanning else { return }
                    if value.translation.height > 100 { dismiss() }
                }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isCapturing)
        .sensoryFeedback(.success, trigger: isReviewing)
        .sensoryFeedback(.error, trigger: isFailed)
        .sensoryFeedback(trigger: isDocumentDetected) { old, new in
            // Only the moment a receipt becomes framed is worth a bump —
            // not every flicker back to "searching".
            new && !old ? .impact(weight: .light) : nil
        }
        .task {
            await camera.prepare()
            if camera.authorizationState != .authorized {
                viewModel.fail(.permissionDenied)
            } else if !camera.isSessionRunning {
                viewModel.fail(.cameraUnavailable)
            }
        }
        .onDisappear {
            camera.stopSession()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isScanLineDown = true
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .review(let draft) = newState {
                sheetRoute = .reviewDraft(draft)
            }
        }
        .onChange(of: sheetRoute) { _, newRoute in
            guard newRoute == nil else { return }
            if didSaveDraft {
                dismiss()
            } else {
                capturedImage = nil
                viewModel.reset()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.state)
        .sheet(item: $sheetRoute) { route in
            switch route {
            case .reviewDraft(let draft):
                ManualReceiptEntryView(reviewingDraft: draft, onSaved: { didSaveDraft = true })
            case .manualFallback:
                ManualReceiptEntryView(onSaved: { didSaveDraft = true })
            }
        }
    }

    // MARK: - Derived state

    private var isCapturing: Bool {
        if case .capturing = viewModel.state { return true }
        return false
    }

    private var isProcessing: Bool {
        switch viewModel.state {
        case .capturing, .processing: true
        default: false
        }
    }

    private var isReviewing: Bool {
        if case .review = viewModel.state { return true }
        return false
    }

    private var isFailed: Bool {
        if case .failed = viewModel.state { return true }
        return false
    }

    /// Whether a receipt-shaped rectangle is currently framed steadily —
    /// drives the subtle "ready to capture" feedback on the viewfinder.
    private var isDocumentDetected: Bool {
        viewModel.state == .scanning && camera.isDocumentDetected
    }

    private var frameAccentColor: Color {
        isDocumentDetected ? Color.accentColor : .white
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("스캔 취소")

            Spacer()

            Text("영수증 스캔")
                .font(RBFont.headline)
                .foregroundStyle(.white)

            Spacer()

            // Reserved for symmetry with the close button — a natural
            // future home for a flash/torch toggle.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Spacing.l)
    }

    private var scanFrame: some View {
        GeometryReader { proxy in
            ZStack {
                frameContent
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))

                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(frameAccentColor.opacity(0.5), lineWidth: 1.5)

                CornerBracketsShape()
                    .stroke(frameAccentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .animation(.easeInOut(duration: 0.25), value: isDocumentDetected)

                if viewModel.state == .scanning, !reduceMotion, !isDocumentDetected {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.85), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 2)
                    .offset(y: isScanLineDown ? proxy.size.height / 2 - 8 : -proxy.size.height / 2 + 8)
                }

                if isCapturing {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .aspectRatio(0.72, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// The live camera feed while scanning; the just-captured photo (held
    /// in place) once a capture starts, so the transition into processing
    /// feels like one continuous scene rather than a hard cut.
    @ViewBuilder
    private var frameContent: some View {
        if let capturedImage, viewModel.state != .scanning {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFill()
        } else if camera.isSessionRunning {
            CameraPreviewView(session: camera.session)
        } else {
            Color.black
        }
    }

    private var bottomControls: some View {
        VStack(spacing: Spacing.m) {
            Text(instructionText)
                .font(RBFont.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                capture()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 74, height: 74)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(viewModel.state != .scanning)
            .opacity(viewModel.state == .scanning ? 1 : 0.4)
            .accessibilityLabel("영수증 촬영")
            .accessibilityValue(isDocumentDetected ? "영수증 인식됨" : "")
        }
        .padding(.top, Spacing.l)
    }

    private var instructionText: String {
        switch viewModel.state {
        case .scanning:
            isDocumentDetected
                ? String(localized: "영수증을 인식했어요 — 캡처를 눌러주세요")
                : String(localized: "영수증을 화면에 맞춰주세요")
        case .capturing: String(localized: "촬영 중…")
        case .processing: String(localized: "분석 중…")
        case .review: String(localized: "내용을 확인해주세요")
        case .failed: ""
        }
    }

    private func capture() {
        guard viewModel.state == .scanning else { return }
        Task {
            do {
                let image = try await camera.capturePhoto()
                capturedImage = image
                viewModel.process(image: image)
            } catch {
                viewModel.fail(.captureFailed)
            }
        }
    }

    // MARK: - Overlays

    private var processingOverlay: some View {
        VStack(spacing: Spacing.s) {
            ProgressView()
                .tint(.white)
            Text("분석 중")
                .font(RBFont.headline)
                .foregroundStyle(.white)
            Text("세부 정보를 추출하고 있어요…")
                .font(RBFont.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(Spacing.l)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .transition(.opacity)
    }

    private func failureOverlay(_ failure: ScanViewModel.ScanFailure) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                Image(systemName: icon(for: failure))
                    .font(.system(size: 48))
                    .foregroundStyle(.white)

                VStack(spacing: Spacing.xs) {
                    Text(failure.title)
                        .font(RBFont.sectionTitle)
                        .foregroundStyle(.white)
                    Text(failure.message)
                        .font(RBFont.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }

                VStack(spacing: Spacing.s) {
                    if failure.isRetryable {
                        Button("다시 촬영") {
                            capturedImage = nil
                            viewModel.reset()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                        .controlSize(.large)
                        .clipShape(Capsule())
                    } else if failure == .permissionDenied {
                        Button("설정으로 이동") {
                            openSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                        .controlSize(.large)
                        .clipShape(Capsule())
                    }

                    Button("직접 입력하기") {
                        sheetRoute = .manualFallback
                    }
                    .font(RBFont.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                    Button("취소") {
                        dismiss()
                    }
                    .font(RBFont.caption)
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(Spacing.xl)
        }
        .transition(.opacity)
    }

    private func icon(for failure: ScanViewModel.ScanFailure) -> String {
        switch failure {
        case .noTextFound: "text.viewfinder"
        case .captureFailed: "exclamationmark.triangle.fill"
        case .cameraUnavailable: "camera.fill"
        case .permissionDenied: "lock.fill"
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ScanView()
        .environment(ReceiptStore.preview())
}
