import AppKit
import DianYiDianCore

final class MonthCalendarMenuView: NSView {
    private let monthProgress: MonthProgress
    private let cellSize: CGFloat = 22
    private let gap: CGFloat = 4
    private let horizontalPadding: CGFloat = 12
    private let topPadding: CGFloat = 10
    private let titleHeight: CGFloat = 18
    private let weekdayHeight: CGFloat = 16
    private let bottomPadding: CGFloat = 10

    init(monthProgress: MonthProgress) {
        self.monthProgress = monthProgress
        super.init(frame: .zero)
        frame = NSRect(origin: .zero, size: preferredSize)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        preferredSize
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawTitle()
        drawWeekdays()
        drawDays()
    }

    private var rows: Int {
        Int(ceil(Double(monthProgress.leadingBlankCount + monthProgress.days.count) / 7.0))
    }

    private var preferredSize: NSSize {
        NSSize(
            width: horizontalPadding * 2 + cellSize * 7 + gap * 6,
            height: topPadding + titleHeight + 6 + weekdayHeight + 6 + CGFloat(rows) * cellSize + CGFloat(max(0, rows - 1)) * gap + bottomPadding
        )
    }

    private var gridTopY: CGFloat {
        bounds.height - topPadding - titleHeight - 6 - weekdayHeight - 6
    }

    private func drawTitle() {
        let rect = NSRect(
            x: horizontalPadding,
            y: bounds.height - topPadding - titleHeight,
            width: bounds.width - horizontalPadding * 2,
            height: titleHeight
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        monthProgress.monthTitle.drawCentered(in: rect, attributes: attributes)
    }

    private func drawWeekdays() {
        let y = bounds.height - topPadding - titleHeight - 6 - weekdayHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        for index in 0..<7 {
            let rect = NSRect(
                x: horizontalPadding + CGFloat(index) * (cellSize + gap),
                y: y,
                width: cellSize,
                height: weekdayHeight
            )
            monthProgress.weekdaySymbols[index].drawCentered(in: rect, attributes: attributes)
        }
    }

    private func drawDays() {
        let dayAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let futureAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        for (index, day) in monthProgress.days.enumerated() {
            let slot = monthProgress.leadingBlankCount + index
            let column = slot % 7
            let row = slot / 7
            let rect = NSRect(
                x: horizontalPadding + CGFloat(column) * (cellSize + gap),
                y: gridTopY - CGFloat(row + 1) * cellSize - CGFloat(row) * gap,
                width: cellSize,
                height: cellSize
            )
            drawDayCell(day, in: rect)

            let textRect = rect.insetBy(dx: 1, dy: 3)
            "\(day.dayNumber)".drawCentered(
                in: textRect,
                attributes: day.isFuture ? futureAttributes : dayAttributes
            )
        }
    }

    private func drawDayCell(_ day: DayProgress, in rect: NSRect) {
        let cellRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let path = NSBezierPath(roundedRect: cellRect, xRadius: 8, yRadius: 8)
        let backgroundColor: NSColor = day.isFuture
            ? NSColor.separatorColor.withAlphaComponent(0.18)
            : NSColor.separatorColor.withAlphaComponent(0.28)
        backgroundColor.setFill()
        path.fill()

        if !day.isFuture, day.completionRatio > 0 {
            NSGraphicsContext.saveGraphicsState()
            path.addClip()

            let fillHeight = cellRect.height * CGFloat(day.completionRatio)
            let waterRect = NSRect(
                x: cellRect.minX,
                y: cellRect.minY,
                width: cellRect.width,
                height: fillHeight
            )
            waterColor(for: day).setFill()
            waterRect.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        if day.isToday {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1.3
            path.stroke()
        } else if day.hasRecord && day.completionRatio >= 1 {
            NSColor.systemGreen.withAlphaComponent(0.75).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func waterColor(for day: DayProgress) -> NSColor {
        if day.completionRatio >= 1 {
            return NSColor.systemGreen.withAlphaComponent(0.78)
        }
        if day.completionRatio >= 0.75 {
            return NSColor.systemTeal.withAlphaComponent(0.72)
        }
        if day.completionRatio >= 0.5 {
            return NSColor.systemBlue.withAlphaComponent(0.66)
        }
        return NSColor.systemBlue.withAlphaComponent(0.42)
    }
}

private extension String {
    func drawCentered(in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
        let attributed = NSAttributedString(string: self, attributes: attributes)
        let size = attributed.size()
        let drawRect = NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        attributed.draw(in: drawRect)
    }
}
