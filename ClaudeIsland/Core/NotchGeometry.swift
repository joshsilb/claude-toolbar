//
//  NotchGeometry.swift
//  ClaudeIsland
//
//  Geometry calculations for panel positioning relative to the status item
//

import CoreGraphics
import Foundation

struct NotchGeometry: Sendable {
    let statusItemRect: CGRect
    let screenRect: CGRect

    func panelFrame(for size: CGSize) -> CGRect {
        let x = statusItemRect.maxX - size.width
        let y = statusItemRect.minY - size.height

        let clampedX = max(screenRect.minX + 8, x)

        return CGRect(x: clampedX, y: y, width: size.width, height: size.height)
    }

    func isPointInPanel(_ point: CGPoint, size: CGSize) -> Bool {
        panelFrame(for: size).contains(point)
    }

    func isPointInStatusItem(_ point: CGPoint) -> Bool {
        statusItemRect.insetBy(dx: -4, dy: -2).contains(point)
    }

    func isPointOutsidePanel(_ point: CGPoint, size: CGSize) -> Bool {
        !isPointInPanel(point, size: size) && !isPointInStatusItem(point)
    }
}
