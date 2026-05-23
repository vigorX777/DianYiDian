import AppKit
import DianYiDianCore

final class StatusIconRenderer {
    func makeImage(
        progress: Double,
        style: IconStyle,
        themeColor: ThemeColor = .blue,
        isHighlighted: Bool = false,
        isCelebrating: Bool = false
    ) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        let clampedProgress = min(1, max(0, progress))

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        drawContrastPlate(center: center)
        if isHighlighted || isCelebrating {
            drawFeedbackGlow(center: center, themeColor: themeColor, isCelebrating: isCelebrating)
        }

        let radius: CGFloat = 8.5
        let baseRing = NSBezierPath()
        baseRing.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        baseRing.lineWidth = 2.2
        NSColor(calibratedWhite: 0.08, alpha: 0.28).setStroke()
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
            progressRing.lineWidth = isHighlighted || isCelebrating ? 3 : 2.4
            let ringColor = isHighlighted || isCelebrating
                ? nsColor(themeColor)
                : progressColor(progress: clampedProgress, themeColor: themeColor)
            ringColor.setStroke()
            progressRing.stroke()
        }

        drawGlyph(style: style, progress: clampedProgress, center: center, themeColor: themeColor)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawContrastPlate(center: NSPoint) {
        let plateRect = NSRect(x: center.x - 10.4, y: center.y - 10.4, width: 20.8, height: 20.8)
        let plate = NSBezierPath(ovalIn: plateRect)
        NSColor(calibratedWhite: 1, alpha: 0.92).setFill()
        plate.fill()

        let outline = NSBezierPath(ovalIn: plateRect.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = 0.9
        NSColor(calibratedWhite: 0, alpha: 0.24).setStroke()
        outline.stroke()
    }

    private func drawFeedbackGlow(center: NSPoint, themeColor: ThemeColor, isCelebrating: Bool) {
        let glowRect = NSRect(x: center.x - 10.9, y: center.y - 10.9, width: 21.8, height: 21.8)
        let glow = NSBezierPath(ovalIn: glowRect)
        let alpha: CGFloat = isCelebrating ? 0.38 : 0.24
        nsColor(themeColor).withAlphaComponent(alpha).setFill()
        glow.fill()

        let outline = NSBezierPath(ovalIn: glowRect.insetBy(dx: 1.2, dy: 1.2))
        outline.lineWidth = isCelebrating ? 1.8 : 1.4
        nsColor(themeColor).withAlphaComponent(isCelebrating ? 0.9 : 0.72).setStroke()
        outline.stroke()
    }

    private func drawGlyph(style: IconStyle, progress: Double, center: NSPoint, themeColor: ThemeColor) {
        let color: NSColor = progress >= 1
            ? nsColor(themeColor).blended(withFraction: 0.18, of: .black) ?? nsColor(themeColor)
            : NSColor(calibratedWhite: 0.08, alpha: 0.92)

        drawSymbol(style: style, color: color, center: center)
    }

    private func drawSymbol(style: IconStyle, color: NSColor, center: NSPoint) {
        guard let symbol = makeTintedSymbol(style: style, color: color) else {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 3.2, y: center.y - 3.2, width: 6.4, height: 6.4)).fill()
            return
        }

        let rect = NSRect(x: center.x - 5.4, y: center.y - 5.4, width: 10.8, height: 10.8)
        symbol.draw(in: rect)
    }

    private func makeTintedSymbol(style: IconStyle, color: NSColor) -> NSImage? {
        guard let baseSymbol = NSImage(
            systemSymbolName: style.symbolName,
            accessibilityDescription: style.displayName
        ) else {
            return nil
        }

        let symbolSize = NSSize(width: 14, height: 14)
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let symbol = baseSymbol.withSymbolConfiguration(configuration) ?? baseSymbol
        let mask = NSImage(size: symbolSize)
        mask.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: symbolSize).fill()
        NSColor.black.set()
        symbol.draw(
            in: NSRect(origin: .zero, size: symbolSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        mask.unlockFocus()

        let tinted = NSImage(size: symbolSize)
        tinted.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: symbolSize).fill()
        mask.draw(
            in: NSRect(origin: .zero, size: symbolSize),
            from: .zero,
            operation: .destinationIn,
            fraction: 1
        )
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }

    private func progressColor(progress: Double, themeColor: ThemeColor) -> NSColor {
        switch progress {
        case ..<0.25:
            .systemGray
        case ..<0.50:
            nsColor(themeColor).withAlphaComponent(0.75)
        case ..<0.75:
            nsColor(themeColor).withAlphaComponent(0.88)
        case ..<1:
            nsColor(themeColor)
        default:
            nsColor(themeColor).blended(withFraction: 0.14, of: .black) ?? nsColor(themeColor)
        }
    }

    private func nsColor(_ color: ThemeColor) -> NSColor {
        switch color {
        case .blue: .systemBlue
        case .teal: .systemTeal
        case .green: .systemGreen
        case .orange: .systemOrange
        case .purple: .systemPurple
        case .pink: .systemPink
        case .gray: .systemGray
        }
    }
}
