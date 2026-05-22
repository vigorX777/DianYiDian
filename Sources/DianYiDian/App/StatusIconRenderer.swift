import AppKit
import DianYiDianCore

final class StatusIconRenderer {
    func makeImage(progress: Double, style: IconStyle) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        let clampedProgress = min(1, max(0, progress))

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = 8.5
        let baseRing = NSBezierPath()
        baseRing.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        baseRing.lineWidth = 2
        NSColor.secondaryLabelColor.withAlphaComponent(0.35).setStroke()
        baseRing.stroke()

        if clampedProgress > 0 {
            let progressRing = NSBezierPath()
            progressRing.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90,
                endAngle: 90 - CGFloat(360 * clampedProgress),
                clockwise: true
            )
            progressRing.lineCapStyle = .round
            progressRing.lineWidth = 2.4
            progressColor(progress: clampedProgress).setStroke()
            progressRing.stroke()
        }

        drawGlyph(style: style, progress: clampedProgress, center: center)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawGlyph(style: IconStyle, progress: Double, center: NSPoint) {
        let color: NSColor = progress >= 1 ? .systemGreen : .labelColor
        color.setStroke()
        color.setFill()

        switch style {
        case .waterDrop:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x, y: center.y + 4.5))
            path.curve(
                to: NSPoint(x: center.x - 3.8, y: center.y - 1.2),
                controlPoint1: NSPoint(x: center.x - 2.5, y: center.y + 2),
                controlPoint2: NSPoint(x: center.x - 3.8, y: center.y + 0.4)
            )
            path.curve(
                to: NSPoint(x: center.x, y: center.y - 5),
                controlPoint1: NSPoint(x: center.x - 3.8, y: center.y - 3.4),
                controlPoint2: NSPoint(x: center.x - 2.2, y: center.y - 5)
            )
            path.curve(
                to: NSPoint(x: center.x + 3.8, y: center.y - 1.2),
                controlPoint1: NSPoint(x: center.x + 2.2, y: center.y - 5),
                controlPoint2: NSPoint(x: center.x + 3.8, y: center.y - 3.4)
            )
            path.curve(
                to: NSPoint(x: center.x, y: center.y + 4.5),
                controlPoint1: NSPoint(x: center.x + 3.8, y: center.y + 0.4),
                controlPoint2: NSPoint(x: center.x + 2.5, y: center.y + 2)
            )
            path.close()
            path.lineWidth = 1.1
            path.stroke()

        case .dot:
            NSBezierPath(ovalIn: NSRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)).fill()

        case .checkmark:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x - 4.5, y: center.y))
            path.line(to: NSPoint(x: center.x - 1.2, y: center.y - 3.2))
            path.line(to: NSPoint(x: center.x + 4.8, y: center.y + 3.8))
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    private func progressColor(progress: Double) -> NSColor {
        switch progress {
        case ..<0.25:
            .systemGray
        case ..<0.50:
            .systemBlue
        case ..<0.75:
            .systemTeal
        case ..<1:
            .systemOrange
        default:
            .systemGreen
        }
    }
}
