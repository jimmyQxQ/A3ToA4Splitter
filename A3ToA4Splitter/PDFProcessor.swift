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
    let sourceSize: CGSize
}

class PDFProcessor {

    // A4 尺寸 72dpi: 595 x 842 pts
    static let a4Portrait = CGSize(width: 595, height: 842)
    static let a4Landscape = CGSize(width: 842, height: 595)

    // A3 尺寸 72dpi: 842 x 1191 pts
    static let a3Portrait = CGSize(width: 842, height: 1191)
    static let a3Landscape = CGSize(width: 1191, height: 842)

    static func detectOrientation(size: CGSize) -> Bool {
        return size.width > size.height
    }

    static func calculateLayout(sourceSize: CGSize) -> PageLayout {
        let isLandscape = detectOrientation(size: sourceSize)
        // 输出始终为纵向 A4，方便打印
        let a4Size = a4Portrait

        let cols = Int(ceil(sourceSize.width / a4Size.width))
        let rows = Int(ceil(sourceSize.height / a4Size.height))

        return PageLayout(
            isLandscape: isLandscape,
            columns: max(cols, 1),
            rows: max(rows, 1),
            a4Size: a4Size,
            sourceSize: sourceSize
        )
    }

    static func splitImageToA4(image: UIImage) throws -> URL {
        let size = image.size
        let layout = calculateLayout(sourceSize: size)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw SplitError.renderFailed
        }

        let a4PortraitSize = a4Portrait
        var mediaBox = CGRect(origin: .zero, size: a4PortraitSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw SplitError.renderFailed
        }

        guard let cgImage = image.cgImage else {
            throw SplitError.invalidInput
        }

        let scaleX = CGFloat(cgImage.width) / size.width
        let scaleY = CGFloat(cgImage.height) / size.height

        for row in 0..<layout.rows {
            for col in 0..<layout.columns {
                context.beginPDFPage(nil)

                let x = CGFloat(col) * layout.a4Size.width
                let y = CGFloat(row) * layout.a4Size.height

                // 计算裁剪区域（CoreGraphics坐标系，原点在左下角）
                let cropRect = CGRect(
                    x: x,
                    y: size.height - y - layout.a4Size.height,
                    width: layout.a4Size.width,
                    height: layout.a4Size.height
                )

                // 转换为CGImage坐标（原点在左上角）
                let imageCropRect = CGRect(
                    x: cropRect.origin.x * scaleX,
                    y: cropRect.origin.y * scaleY,
                    width: cropRect.width * scaleX,
                    height: cropRect.height * scaleY
                )

                // 裁剪子图像
                if let croppedCGImage = cgImage.cropping(to: imageCropRect) {
                    // 在A4页面上绘制，保持比例填充
                    let drawRect = CGRect(origin: .zero, size: a4PortraitSize)
                    context.draw(croppedCGImage, in: drawRect)
                }

                // 添加裁切线
                drawCropMarks(context: context, pageSize: a4PortraitSize)

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
                        y: pageBounds.size.height - y - layout.a4Size.height,
                        width: layout.a4Size.width,
                        height: layout.a4Size.height
                    )

                    let newPage = createA4Page(
                        from: page,
                        cropRect: cropRect,
                        pageSize: layout.a4Size,
                        pageBounds: pageBounds
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

        // 使用 UIGraphicsImageRenderer 创建带裁切线的页面图像
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        let image = renderer.image { ctx in
            let cgContext = ctx.cgContext

            // 白色背景
            UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: pageSize))

            // 翻转坐标系
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: pageSize.height)
            cgContext.scaleBy(x: 1, y: -1)

            // 渲染原始页面内容到当前裁剪区域
            if let pageRef = sourcePage.pageRef {
                cgContext.translateBy(x: -cropRect.origin.x, y: -cropRect.origin.y)
                cgContext.drawPDFPage(pageRef)
            }

            cgContext.restoreGState()

            // 绘制裁切线
            drawCropMarks(context: cgContext, pageSize: pageSize)
        }

        // 将图像设置为新页面内容
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

        // 左上角
        context.move(to: CGPoint(x: markOffset, y: markOffset + markLength))
        context.addLine(to: CGPoint(x: markOffset, y: markOffset))
        context.addLine(to: CGPoint(x: markOffset + markLength, y: markOffset))

        // 右上角
        context.move(to: CGPoint(x: pageSize.width - markOffset - markLength, y: markOffset))
        context.addLine(to: CGPoint(x: pageSize.width - markOffset, y: markOffset))
        context.addLine(to: CGPoint(x: pageSize.width - markOffset, y: markOffset + markLength))

        // 左下角
        context.move(to: CGPoint(x: markOffset, y: pageSize.height - markOffset - markLength))
        context.addLine(to: CGPoint(x: markOffset, y: pageSize.height - markOffset))
        context.addLine(to: CGPoint(x: markOffset + markLength, y: pageSize.height - markOffset))

        // 右下角
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
