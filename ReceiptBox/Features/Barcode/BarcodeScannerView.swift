//
//  BarcodeScannerView.swift
//  ReceiptBox
//
//  Real camera capture → continuous AVCaptureMetadataOutput barcode
//  detection → local Product lookup → result. Visually mirrors ScanView's
//  dark, calm scanning frame, but wide rather than tall — 1D barcodes read
//  better in a landscape-oriented target.

import AVFoundation
import SwiftUI

struct BarcodeScannerView: View {
    private enum SheetRoute: Identifiable, Equatable {
        case found(Product)
        case notFound(barcode: String)

        var id: String {
            switch self {
            case .found(let product): "found-\(product.id)"
            case .notFound(let barcode): "notFound-\(barcode)"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ProductStore.self) private var productStore

    @State private var viewModel = BarcodeScannerViewModel()
    @State private var camera = BarcodeScannerController()
    @State private var isScanLineDown = false
    @State private var sheetRoute: SheetRoute?
    @State private var didFinish = false
    #if targetEnvironment(simulator)
    @State private var isShowingDevBarcodeEntry = false
    @State private var devBarcodeText = ""
    #endif

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

            if isLookingUp {
                processingOverlay
            }

            if case .failed(let failure) = viewModel.state {
                failureOverlay(failure)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(trigger: isLookingUp) { old, new in
            new && !old ? .impact(weight: .light) : nil
        }
        .sensoryFeedback(.success, trigger: isFound)
        .sensoryFeedback(.warning, trigger: isNotFound)
        .task {
            camera.onDetect = { code in
                viewModel.handle(barcode: code, productStore: productStore)
            }
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
            switch newState {
            case .found(let product):
                sheetRoute = .found(product)
            case .notFound(let barcode):
                sheetRoute = .notFound(barcode: barcode)
            default:
                break
            }
        }
        .onChange(of: sheetRoute) { _, newRoute in
            guard newRoute == nil else { return }
            if didFinish {
                dismiss()
            } else {
                viewModel.reset()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.state)
        .sheet(item: $sheetRoute) { route in
            switch route {
            case .found(let product):
                BarcodeResultView(mode: .found(product), onFinished: { didFinish = true })
            case .notFound(let barcode):
                BarcodeResultView(mode: .notFound(barcode: barcode), onFinished: { didFinish = true })
            }
        }
        #if targetEnvironment(simulator)
        .alert("개발용 바코드 입력", isPresented: $isShowingDevBarcodeEntry) {
            TextField("바코드", text: $devBarcodeText)
                .keyboardType(.numberPad)
            Button("조회") {
                let code = devBarcodeText
                devBarcodeText = ""
                viewModel.handle(barcode: code, productStore: productStore)
            }
            Button("취소", role: .cancel) { devBarcodeText = "" }
        }
        #endif
    }

    // MARK: - Derived state

    private var isLookingUp: Bool {
        if case .lookingUp = viewModel.state { return true }
        return false
    }

    private var isFound: Bool {
        if case .found = viewModel.state { return true }
        return false
    }

    private var isNotFound: Bool {
        if case .notFound = viewModel.state { return true }
        return false
    }

    private var isFailed: Bool {
        if case .failed = viewModel.state { return true }
        return false
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
            .accessibilityLabel("바코드 스캔 취소")

            Spacer()

            Text("바코드 스캔")
                .font(RBFont.headline)
                .foregroundStyle(.white)

            Spacer()

            #if targetEnvironment(simulator)
            Button {
                isShowingDevBarcodeEntry = true
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("개발용 바코드 입력")
            #else
            Color.clear.frame(width: 36, height: 36)
            #endif
        }
        .padding(.horizontal, Spacing.l)
    }

    /// Wide rather than tall — 1D barcodes are landscape-shaped, unlike the
    /// receipt scanner's portrait frame.
    private var scanFrame: some View {
        GeometryReader { proxy in
            ZStack {
                frameContent
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))

                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)

                CornerBracketsShape(length: 22)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                if viewModel.state == .scanning, !reduceMotion {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.85), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 2)
                    .offset(y: isScanLineDown ? proxy.size.height / 2 - 8 : -proxy.size.height / 2 + 8)
                }
            }
        }
        .aspectRatio(2.2, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var frameContent: some View {
        if camera.isSessionRunning {
            CameraPreviewView(session: camera.session)
        } else {
            Color.black
        }
    }

    private var bottomControls: some View {
        Text(instructionText)
            .font(RBFont.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.l)
    }

    private var instructionText: String {
        switch viewModel.state {
        case .scanning: String(localized: "바코드를 화면에 맞춰주세요")
        case .lookingUp: String(localized: "바코드를 확인하고 있어요…")
        case .found, .notFound: ""
        case .failed: ""
        }
    }

    // MARK: - Overlays

    private var processingOverlay: some View {
        VStack(spacing: Spacing.s) {
            ProgressView()
                .tint(.white)
            Text("바코드 확인 중")
                .font(RBFont.headline)
                .foregroundStyle(.white)
        }
        .padding(Spacing.l)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .transition(.opacity)
    }

    private func failureOverlay(_ failure: BarcodeScannerViewModel.ScanFailure) -> some View {
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
                    if failure == .permissionDenied {
                        Button("설정으로 이동") {
                            openSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                        .controlSize(.large)
                        .clipShape(Capsule())
                    }

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

    private func icon(for failure: BarcodeScannerViewModel.ScanFailure) -> String {
        switch failure {
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
    BarcodeScannerView()
        .environment(ProductStore.preview())
}
