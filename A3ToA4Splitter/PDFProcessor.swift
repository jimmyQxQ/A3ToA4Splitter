import UIKit
import PDFKit
import CoreGraphics

enum SplitError: Error, LocalizedError {
    case invalidInput
    case renderFailed
    case saveFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidInput: return "无效的文件或图片"
        case .renderFailed: return "渲染PDF失败"
        case .saveFailed: return "保存文件失败"
        case .unknown: return "未知错误"
        }
    }
}

struct PageLayout {
    let isLandscape: Bool
    let columns: Int
    let rows: Int
    let a4Size: CGSize
    let a3Size: CGSize
}

class PDFProcessor {

    static let a4Portrait = CGSize(width: 595, height: 842)
    static let a4Landscape = CGSize(width: 842, height: 595)

    static let a3Portrait = CGSize(width: 842, height: 1191)
    static let a3Landscape = CGSize(width: 1191, height: 842)

    static func detectOrientation(size: CGSize) -> Bool {
        return size.width > size.height
    }

    static func calculateLayout(sourceSize: CGSize) -> PageLayout {
        let isLandscape = detectOrientation(size: sourceSize)
        let a4Size = a4Portrait
        let a3Size = isLandscape ? a3Landscape : a3Portrait

        let columns = isLandscape ? 2 : 1
        let rows = isLandscape ? 1 : 2

        return PageLayout(
            isLandscape: isLandscape,
            columns: columns,
            rows: rows,
            a4Size: a4Size,
            a3Size: a3Size
        )
    }

    static func splitImageToA4(image: UIImage) throws -> URL {
        let size = image.size
        let layout = calculateLayout(sourceSize: size)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw SplitError.renderFailed
        }

        var mediaBox = CGRect(origin: .zero, size: layout.a4Size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw SplitError.renderFailed
        }

        guard let cgImage = image.cgImage else {
            throw SplitError.invalidInput
        }

        let imageAspectRatio = size.width / size.height
        let a3AspectRatio = layout.a3Size.width / layout.a3Size.height

        var scale: CGFloat
        if imageAspectRatio > a3AspectRatio {
            scale = layout.a3Size.width / size.width
        } else {
            scale = layout.a3Size.height / size.height
        }

        let scaledWidth = size.width * scale
        let scaledHeight = size.height * scale

        let offsetX = (layout.a3Size.width - scaledWidth) / 2
        let offsetY = (layout.a3Size.height - scaledHeight) / 2

        for row in 0..<layout.rows {
            for col in 0..<layout.columns {
                context.beginPDFPage(nil)

                let pageX = CGFloat(col) * layout.a4Size.width
                let pageY = CGFloat(row) * layout.a4Size.height

                context.saveGState()

                context.translateBy(x: -pageX, y: -(layout.a3Size.height - pageY - layout.a4Size.height))

                context.translateBy(x: offsetX, y: offsetY)

                let drawRect = CGRect(origin: .zero, size: CGSize(width: scaledWidth, height: scaledHeight))
                context.draw(cgImage, in: drawRect)

                context.restoreGState()

                drawCropMarks(context: context, pageSize: layout.a4Size)

                context.endPDFPage()
            }
        }

        context.closePDF()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("A3_Split_A4_\(UUID().uuidString).pdf")
        try pdfData.write(to: url)
        return url
    }

    static func splitPDFToA4(sourceURL: URL) throws -> URL {
        guard let pdfDocument = PDFDocument(url: sourceURL) else {
            throw SplitError.invalidInput
        }

        let outputDocument = PDFDocument()

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            let layout = calculateLayout(sourceSize: pageBounds.size)

            for row in 0..<layout.rows {
                for col in 0..<layout.columns {
                    let x = CGFloat(col) * layout.a4Size.width
                    let y = CGFloat(row) * layout.a4Size.height

                    let cropRect = CGRect(
                        x: x,
                        y: layout.a3Size.height - y - layout.a4Size.height,
                        width: layout.a4Size.width,
                        height: layout.a4Size.height
                    )

                    let newPage = createA4Page(
                        from: page,
                        cropRect: cropRect,
                        pageSize: layout.a4Size,
                        pageBounds: CGRect(origin: .zero, size: layout.a3Size)
                    )
                    outputDocument.insert(newPage, at: outputDocument.pageCount)
                }
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("A3_Split_A4_\(UUID().uuidString).pdf")
        guard outputDocument.write(to: url) else {
            throw SplitError.saveFailed
        }
        return url
    }

    private static func createA4Page(
        from sourcePage: PDFPage,
        cropRect: CGRect,
        pageSize: CGSize,
        pageBounds: CGRect
    ) -> PDFPage {
        let newPage = PDFPage()

        let renderer = UIGraphicsImageRenderer(size: pageSize)
        let image = renderer.image { ctx in
            let cgContext = ctx.cgContext

            UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: pageSize))

            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: pageSize.height)
            cgContext.scaleBy(x: 1, y: -1)

            if let pageRef = sourcePage.pageRef {
                let sourceBounds = sourcePage.bounds(for: .mediaBox)
                let scaleX = pageBounds.width / sourceBounds.width
                let scaleY = pageBounds.height / sourceBounds.height
                let scale = min(scaleX, scaleY)

                let scaledWidth = sourceBounds.width * scale
                let scaledHeight = sourceBounds.height * scale
                let offsetX = (pageBounds.width - scaledWidth) / 2
                let offsetY = (pageBounds.height - scaledHeight) / 2

                cgContext.translateBy(x: offsetX - cropRect.origin.x, y: offsetY - cropRect.origin.y)
                cgContext.scaleBy(x: scale, y: scale)
                cgContext.drawPDFPage(pageRef)
            }

            cgContext.restoreGState()

            drawCropMarks(context: cgContext, pageSize: pageSize)
        }

        if let cgImage = image.cgImage,
           let imagePage = PDFPage(image: UIImage(cgImage: cgImage)) {
            return imagePage
        }

        return newPage
    }

    private static func drawCropMarks(context: CGContext, pageSize: CGSize) {
        let markLength: CGFloat = 20
        let markOffset: CGFloat = 5
        let lineWidth: CGFloat = 0.5

        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(lineWidth)

        context.move(to: CGPoint(x: markOffset, y: markOffset + markLength))
        context.addLine(to: CGPoint(x: markOffset, y: markOffset))
        context.addLine(to: CGPoint(x: markOffset + markLength, y: markOffset))

        context.move(to: CGPoint(x: pageSize.width - markOffset - markLength, y: markOffset))
        context.addLine(to: CGPoint(x: pageSize.width - markOffset, y: markOffset))
        context.addLine(to: CGPoint(x: pageSize.width - markOffset, y: markOffset + markLength))

        context.move(to: CGPoint(x: markOffset, y: pageSize.height - markOffset - markLength))
        context.addLine(to: CGPoint(x: markOffset, y: pageSize.height - markOffset))
        context.addLine(to: CGPoint(x: markOffset + markLength, y: pageSize.height - markOffset))

        context.move(to: CGPoint(x: pageSize.width - markOffset - markLength, y: pageSize.height - markOffset))
        context.addLine(to: CGPoint(x: pageSize.width - markOffset, y: pageSize.height - markOffset))
        context.addLine(to: CGPoint(x: pageSize.width - markOffset, y: pageSize.height - markOffset - markLength))

        context.strokePath()
    }

    static func saveToDocuments(sourceURL: URL) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destination = documents.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }
}
