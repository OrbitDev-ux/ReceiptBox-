//
//  BarcodeScannerViewModel.swift
//  ReceiptBox
//
//  Drives the barcode scan state machine, mirroring ScanViewModel. The
//  camera itself lives in BarcodeScannerView; this owns what happens to a
//  detected code — a local Product lookup — and de-duplicates so a code
//  sitting in frame for seconds doesn't trigger repeated lookups.

import Foundation
import Observation

@Observable
final class BarcodeScannerViewModel {
    enum State: Equatable {
        case scanning
        case lookingUp(barcode: String)
        case found(Product)
        case notFound(barcode: String)
        case failed(ScanFailure)
    }

    enum ScanFailure: Equatable {
        case cameraUnavailable
        case permissionDenied

        var title: String {
            switch self {
            case .cameraUnavailable: String(localized: "카메라를 사용할 수 없어요")
            case .permissionDenied: String(localized: "카메라 접근 권한 필요")
            }
        }

        var message: String {
            switch self {
            case .cameraUnavailable:
                #if targetEnvironment(simulator)
                String(localized: "시뮬레이터에서는 실제 카메라를 사용할 수 없어요. 개발 모드에서는 직접 입력으로 계속 진행할 수 있어요.")
                #else
                String(localized: "지금은 사용할 수 있는 카메라가 없어요.")
                #endif
            case .permissionDenied:
                String(localized: "설정에서 카메라 접근을 허용하면 바코드를 스캔할 수 있어요.")
            }
        }
    }

    private(set) var state: State = .scanning
    /// The last code this view model acted on — guards against the live
    /// metadata feed re-triggering a lookup dozens of times a second while
    /// the same barcode sits in frame.
    private var lastHandledBarcode: String?

    /// Begins a lookup for a freshly detected barcode. Safe to call
    /// repeatedly from the live camera feed — ignored unless still
    /// `.scanning` and the code differs from the last one handled.
    func handle(barcode: String, productStore: ProductStore) {
        guard state == .scanning else { return }
        let normalized = Product.normalizeBarcode(barcode)
        guard !normalized.isEmpty, normalized != lastHandledBarcode else { return }
        lastHandledBarcode = normalized
        state = .lookingUp(barcode: normalized)

        Task {
            if let product = productStore.product(forBarcode: normalized) {
                state = .found(product)
            } else {
                state = .notFound(barcode: normalized)
            }
        }
    }

    func fail(_ failure: ScanFailure) {
        state = .failed(failure)
    }

    /// Returns to `.scanning` and forgets the last-handled code, so the
    /// same barcode can be picked up again (e.g. after dismissing a result
    /// without saving).
    func reset() {
        state = .scanning
        lastHandledBarcode = nil
    }
}
