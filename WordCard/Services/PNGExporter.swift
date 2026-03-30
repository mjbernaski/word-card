import Foundation
import CoreGraphics
import CoreText
#if os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif

class PNGExporter {

    func export(card: WordCard, resolution: ExportResolution = .medium, includeNotes: Bool = false) -> CGImage? {
        let dpi = CGFloat(resolution.dpi)
        let width = Int(3 * dpi)
        let height = Int(1.5 * dpi)
        let scaledRadius = CGFloat(card.cornerRadius) * dpi / 150

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        let bgColor = parseColor(card.backgroundColor)
        let path = createRoundedRectPath(rect: rect, radius: scaledRadius)
        context.addPath(path)
        context.setFillColor(bgColor)
        context.fillPath()

        let notes = (includeNotes && !card.notes.isEmpty) ? card.notes : ""
        let padding = rect.width * 0.10
        let maxWidth = rect.width - (2 * padding)
        let maxHeight = rect.height - (2 * padding)
        let textColor = parseColor(card.textColor)

        // Measure main text (same sizing logic as drawCenteredText)
        var fontSize = rect.height * 0.5
        let minFontSize: CGFloat = 9 * (dpi / 150)
        var mainFont: CTFont
        var mainAttrString: NSAttributedString
        var mainTextSize: CGSize

        let availableMainHeight = notes.isEmpty ? maxHeight : maxHeight * 0.75

        repeat {
            mainFont = createFont(style: card.fontStyle, size: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [.font: mainFont, .foregroundColor: textColor]
            mainAttrString = NSAttributedString(string: card.text, attributes: attrs)
            mainTextSize = measureText(mainAttrString, maxWidth: maxWidth)
            if mainTextSize.width <= maxWidth && mainTextSize.height <= availableMainHeight { break }
            fontSize -= 2
        } while fontSize >= minFontSize

        // Measure notes if present
        let notesFontSize = rect.height * 0.06
        let spacerHeight = notes.isEmpty ? CGFloat(0) : rect.height * 0.08
        var notesAttrString: NSAttributedString?
        var notesTextSize: CGSize = .zero

        if !notes.isEmpty {
            let notesFont = CTFontCreateWithName("HelveticaNeue-Light" as CFString, notesFontSize, nil)
            let notesAttrs: [NSAttributedString.Key: Any] = [
                .font: notesFont,
                .foregroundColor: parseColor(card.textColor, alpha: 0.45)
            ]
            notesAttrString = NSAttributedString(string: notes, attributes: notesAttrs)
            notesTextSize = measureText(notesAttrString!, maxWidth: maxWidth)
            let maxNotesHeight = rect.height * 0.15
            notesTextSize.height = min(notesTextSize.height, maxNotesHeight)
        }

        // Center the entire block (main text + spacer + notes) vertically
        let totalContentHeight = mainTextSize.height + spacerHeight + notesTextSize.height
        let blockTopY = (rect.height - totalContentHeight) / 2

        // CG Y axis: larger values = higher on screen
        // Main text at top of block (higher Y), notes below (lower Y)
        let mainTextTopY = blockTopY + notesTextSize.height + spacerHeight
        drawTextBlock(
            context: context,
            attributedString: mainAttrString,
            textSize: mainTextSize,
            rect: rect,
            topY: mainTextTopY,
            maxWidth: maxWidth
        )

        if let notesAS = notesAttrString {
            drawTextBlock(
                context: context,
                attributedString: notesAS,
                textSize: notesTextSize,
                rect: rect,
                topY: blockTopY,
                maxWidth: maxWidth,
                maxLines: 2
            )
        }

        if let borderHex = card.borderColor, card.borderWidth > 0 {
            let borderColor = parseColor(borderHex, alpha: 0.4)
            context.addPath(path)
            context.setStrokeColor(borderColor)
            context.setLineWidth(CGFloat(card.borderWidth))
            context.strokePath()
        }

        return context.makeImage()
    }

    private func createRoundedRectPath(rect: CGRect, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY

        path.move(to: CGPoint(x: minX + radius, y: minY))
        path.addLine(to: CGPoint(x: maxX - radius, y: minY))
        path.addArc(center: CGPoint(x: maxX - radius, y: minY + radius), radius: radius, startAngle: -.pi / 2, endAngle: 0, clockwise: false)
        path.addLine(to: CGPoint(x: maxX, y: maxY - radius))
        path.addArc(center: CGPoint(x: maxX - radius, y: maxY - radius), radius: radius, startAngle: 0, endAngle: .pi / 2, clockwise: false)
        path.addLine(to: CGPoint(x: minX + radius, y: maxY))
        path.addArc(center: CGPoint(x: minX + radius, y: maxY - radius), radius: radius, startAngle: .pi / 2, endAngle: .pi, clockwise: false)
        path.addLine(to: CGPoint(x: minX, y: minY + radius))
        path.addArc(center: CGPoint(x: minX + radius, y: minY + radius), radius: radius, startAngle: .pi, endAngle: -.pi / 2, clockwise: false)
        path.closeSubpath()

        return path
    }

    private func drawTextBlock(
        context: CGContext,
        attributedString: NSAttributedString,
        textSize: CGSize,
        rect: CGRect,
        topY: CGFloat,
        maxWidth: CGFloat,
        maxLines: Int? = nil
    ) {
        let x = (rect.width - textSize.width) / 2

        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let framePath = CGPath(
            rect: CGRect(x: x, y: topY, width: textSize.width, height: textSize.height),
            transform: nil
        )
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), framePath, nil)

        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: 1, y: -1)

        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

        let lineCount = maxLines.map { min(lines.count, $0) } ?? lines.count
        for index in 0..<lineCount {
            let line = lines[index]
            let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            let lineX = x + (textSize.width - lineWidth) / 2
            context.textPosition = CGPoint(x: lineX, y: rect.height - topY - origins[index].y)
            CTLineDraw(line, context)
        }

        context.restoreGState()
    }

    private func createFont(style: FontStyle, size: CGFloat) -> CTFont {
        let fontName: String
        switch style {
        case .elegant:
            fontName = "Georgia"
        case .book:
            fontName = "Times New Roman"
        case .apple:
            #if os(iOS)
            fontName = "HelveticaNeue-Light"
            #else
            fontName = "HelveticaNeue-Light"
            #endif
        }

        if let font = CTFontCreateWithName(fontName as CFString, size, nil) as CTFont? {
            return font
        }
        return CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    private func measureText(_ attributedString: NSAttributedString, maxWidth: CGFloat) -> CGSize {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let constraints = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil, constraints, nil)
        return size
    }

    private func parseColor(_ hex: String, alpha: CGFloat = 1.0) -> CGColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        return CGColor(red: r, green: g, blue: b, alpha: alpha)
    }

    func saveToPNG(image: CGImage, url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw ExportError.cannotCreateDestination
        }

        CGImageDestinationAddImage(destination, image, nil)

        if !CGImageDestinationFinalize(destination) {
            throw ExportError.cannotFinalize
        }
    }

    enum ExportError: Error {
        case cannotCreateDestination
        case cannotFinalize
    }
}
