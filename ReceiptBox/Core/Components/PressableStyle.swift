//
//  PressableStyle.swift
//  ReceiptBox
//

import SwiftUI

/// A restrained press effect used on cards and buttons so interaction feels
/// tactile without being flashy.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
