import SwiftUI
import PDFKit

struct CropPreviewView: View {
    let image: UIImage
    let fileType: String
    @Environment(\.presentationMode) var presentationMode
    let onConfirm: () -> Void

    private var layout: PageLayout {
        guard let cgImage = image.cgImage else {
            return PDFProcessor.calculateLayout(cgSize: CGSize(width: image.size.width, height: image.size.height))
        }
        return PDFProcessor.calculateLayout(cgSize: CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }

    private var orientationText: String {
        layout.isLandscape ? "横向 A3" : "纵向 A3"
    }

    private var splitDescription: String {
        layout.isLandscape ? "左右拆分为 2 页纵向 A4" : "上下拆分为 2 页横向 A4"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(orientationText)
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text(splitDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geometry in
                    let availableWidth = geometry.size.width - 32
                    let availableHeight = geometry.size.height

                    let imageAspectRatio = image.size.width / image.size.height
                    let containerAspectRatio = layout.isLandscape ? PDFProcessor.a3Landscape.width / PDFProcessor.a3Landscape.height : PDFProcessor.a3Portrait.width / PDFProcessor.a3Portrait.height

                    let displayWidth: CGFloat
                    let displayHeight: CGFloat

                    if imageAspectRatio > containerAspectRatio {
                        displayWidth = availableWidth
                        displayHeight = availableWidth / imageAspectRatio
                    } else {
                        displayHeight = availableHeight
                        displayWidth = availableHeight * imageAspectRatio
                    }

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: displayWidth, height: displayHeight)

                        CropOverlayView(
                            layout: layout,
                            imageSize: CGSize(width: displayWidth, height: displayHeight)
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }

                VStack(spacing: 8) {
                    Text("预览拆分效果")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        PageIndicator(label: "第 1 页", isFirst: true, layout: layout)
                        PageIndicator(label: "第 2 页", isFirst: false, layout: layout)
                    }
                }
            }
            .navigationTitle("裁切预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认拆分") {
                        onConfirm()
                    }
                    .foregroundColor(.blue)
                }
            })
        }
    }
}

struct CropOverlayView: View {
    let layout: PageLayout
    let imageSize: CGSize

    var body: some View {
        ZStack {
            if layout.isLandscape {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        pageOverlay(index: 0)
                        dividerLine(vertical: true)
                        pageOverlay(index: 1)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    pageOverlay(index: 0)
                    dividerLine(vertical: false)
                    pageOverlay(index: 1)
                }
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }

    private func pageOverlay(index: Int) -> some View {
        let width = layout.isLandscape ? imageSize.width / 2 : imageSize.width
        let height = layout.isLandscape ? imageSize.height : imageSize.height / 2

        return ZStack {
            Rectangle()
                .fill(Color.blue.opacity(0.05))
                .frame(width: width, height: height)

            Text("\(index + 1)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.blue.opacity(0.3))
        }
    }

    private func dividerLine(vertical: Bool) -> some View {
        let length = vertical ? imageSize.height : imageSize.width
        let thickness: CGFloat = 2

        return Rectangle()
            .fill(Color.red)
            .frame(width: vertical ? thickness : length, height: vertical ? length : thickness)
            .opacity(0.5)
            .overlay(
                Rectangle()
                    .fill(Color.white)
                    .frame(width: vertical ? thickness : length, height: vertical ? length : thickness)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white, location: 0),
                                .init(color: .clear, location: 0.1),
                                .init(color: .clear, location: 0.9),
                                .init(color: .white, location: 1)
                            ]),
                            startPoint: vertical ? .top : .leading,
                            endPoint: vertical ? .bottom : .trailing
                        )
                    )
            )
    }
}

struct PageIndicator: View {
    let label: String
    let isFirst: Bool
    let layout: PageLayout

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.blue, lineWidth: 1)
                .frame(
                    width: layout.isLandscape ? 60 : 40,
                    height: layout.isLandscape ? 40 : 60
                )

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CropPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let testImage = UIImage(systemName: "doc.on.doc")!
        CropPreviewView(image: testImage, fileType: "image") {}
    }
}
