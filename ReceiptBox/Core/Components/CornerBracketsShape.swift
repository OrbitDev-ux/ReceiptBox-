//
//  CornerBracketsShape.swift
//  ReceiptBox
//
//  Four corner brackets used to frame a scanning viewfinder, drawn as a
//  single lightweight shape rather than four separate views. Shared between
//  the receipt scanner and the barcode scanner.

import SwiftUI

struct CornerBracketsShape: Shape {
    var length: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners = [
            (rect.minX, rect.minY, CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1)),
            (rect.maxX, rect.minY, CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: 1)),
            (rect.minX, rect.maxY, CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: -1)),
            (rect.maxX, rect.maxY, CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: -1))
        ]

        for (x, y, dx, dy) in corners {
            let start = CGPoint(x: x, y: y)
            path.move(to: CGPoint(x: start.x + dx.dx * length, y: start.y + dx.dy * length))
            path.addLine(to: start)
            path.addLine(to: CGPoint(x: start.x + dy.dx * length, y: start.y + dy.dy * length))
        }

        return path
    }
}
