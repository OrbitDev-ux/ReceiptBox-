//
//  ScanViewModel.swift
//  ReceiptBox
//
//  Drives the scan state machine. The camera itself lives in ScanView
//  (it's a UIKit/hardware concern); this owns what happens to a captured
//  photo — OCR via ReceiptTextRecognizer, then parsing via ReceiptParser —
//  and surfaces the result (or a specific failure) for Review.

import Foundation
import Observation
import UIKit

@Observable
final class ScanViewModel {
    enum State: Equatable {
        case scanning
        case capturing
        case processing
        case review(ReceiptDraft)
        case failed(ScanFailure)
    }

    enum ScanFailure: Equatable {
        case noTextFound
        case captureFailed
        case cameraUnavailable
        case permissionDenied

        var title: String {
            switch self {
            case .noTextFound: String(localized: "영수증을 읽지 못했어요")
            case .captureFailed: String(localized: "촬영에 실패했어요")
            case .cameraUnavailable: String(localized: "카메라를 사용할 수 없어요")
            case .permissionDenied: String(localized: "카메라 접근 권한 필요")
            }
        }

        var message: String {
            switch self {
            case .noTextFound:
                String(localized: "영수증에서 글자를 찾지 못했어요. 더 밝은 곳에서 평평하게 놓고 다시 시도하거나 직접 입력해주세요.")
            case .captureFailed:
                String(localized: "사진을 촬영하는 중 문제가 발생했어요. 다시 시도해주세요.")
            case .cameraUnavailable:
                #if targetEnvironment(simulator)
                String(localized: "시뮬레이터에서는 실제 카메라를 사용할 수 없어요. 개발 모드에서는 직접 입력으로 계속 진행할 수 있어요.")
                #else
                String(localized: "지금은 사용할 수 있는 카메라가 없어요.")
                #endif
            case .permissionDenied:
                String(localized: "설정에서 카메라 접근을 허용하면 영수증을 스캔할 수 있어요.")
            }
        }

        /// Whether "Try Again" makes sense for this failure — permission
        /// and hardware issues need a different fix than retrying.
        var isRetryable: Bool {
            switch self {
            case .noTextFound, .captureFailed: true
            case .cameraUnavailable, .permissionDenied: false
            }
        }
    }

    private(set) var state: State = .scanning

    /// Begins OCR on a freshly captured photo. Safe to call only from
    /// `.scanning` so a capture in flight can't be double-triggered.
    func process(image: UIImage) {
        guard state == .scanning else { return }
        state = .capturing

        Task {
            state = .processing
            do {
                guard let cgImage = image.cgImage else {
                    state = .failed(.captureFailed)
                    return
                }
                let orientation = CGImagePropertyOrientation(image.imageOrientation)
                let lines = try await ReceiptTextRecognizer.recognizeLines(in: cgImage, orientation: orientation)
                let draft = ReceiptParser.parse(lines: lines)
                state = .review(draft)
            } catch ReceiptTextRecognizer.RecognitionError.noTextFound {
                state = .failed(.noTextFound)
            } catch {
                state = .failed(.captureFailed)
            }
        }
    }

    func fail(_ failure: ScanFailure) {
        state = .failed(failure)
    }

    func reset() {
        state = .scanning
    }
}
