import CoreGraphics
import Foundation

final class MouseJiggler {
    func jiggle(distance: CGFloat = 2) -> Bool {
        guard let currentEvent = CGEvent(source: nil),
              let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        let originalPoint = currentEvent.location
        let movedPoint = CGPoint(x: originalPoint.x + distance, y: originalPoint.y)

        guard postMouseMove(with: source, to: movedPoint) else {
            return false
        }

        return postMouseMove(with: source, to: originalPoint)
    }

    private func postMouseMove(with source: CGEventSource, to point: CGPoint) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return false
        }

        event.post(tap: .cghidEventTap)
        return true
    }
}
