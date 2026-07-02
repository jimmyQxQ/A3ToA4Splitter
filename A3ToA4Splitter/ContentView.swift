import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var sourceURL: URL?
    @State private var sourceImage: UIImage?
    @State private var outputURL: URL?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showShareSheet = false
    @State private var showSuccess = false
    @State private var previewDocument: PDFDocument?
    @State private var showPreview = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 顶部标题区
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("A3 拆分 A4")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("上传 A3 图片或 PDF，自动拆分为多页 A4")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // 上传区域
                VStack(spacing: 16) {
                    Button(action: { showImagePicker = true }) {
                        UploadButton(
                            icon: "photo",
                            title: "从相册选择图片",
                            subtitle: "支持 JPG、PNG 等图片格式"
                        )
                    }

                    Button(action: { showDocumentPicker = true }) {
                        UploadButton(
                            icon: "doc.text",
                            title: "选择 PDF 文件",
                            subtitle: "从文件 App 中选择 PDF"
                        )
                    }
                }
                .padding(.horizontal)

                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在处理...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                }

                if let outputURL = outputURL {
                    VStack(spacing: 12) {
                        Text("处理完成！")
                            .font(.headline)
                            .foregroundColor(.green)

                        Button(action: { showPreview = true }) {
                            HStack {
                                Image(systemName: "eye")
                                Text("预览 PDF")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }

                        Button(action: { showShareSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("分享到微信或其他应用")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                        }

                        Button(action: saveToDocuments) {
                            HStack {
                                Image(systemName: "folder")
                                Text("保存到文件")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                        }

                        Button(action: reset) {
                            Text("处理新文件")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }

                Spacer()

                // 说明文字
                VStack(spacing: 4) {
                    Text("功能说明")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text("自动识别横竖向 · 自动添加裁切线 · 纵向排列")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(types: [.pdf]) { url in
                    handleSelectedFile(url: url)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    handleSelectedImage(image: image)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = outputURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showPreview) {
                if let url = outputURL {
                    PDFPreviewView(url: url)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("保存成功", isPresented: $showSuccess) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("PDF 已保存到文件 App 的文档目录中")
            }
        }
    }

    private func handleSelectedFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showError(message: "无法访问文件")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let resultURL = try PDFProcessor.splitPDFToA4(sourceURL: url)
                DispatchQueue.main.async {
                    self.outputURL = resultURL
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(message: error.localizedDescription)
                    self.isProcessing = false
                }
            }
        }
    }

    private func handleSelectedImage(image: UIImage) {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let resultURL = try PDFProcessor.splitImageToA4(image: image)
                DispatchQueue.main.async {
                    self.outputURL = resultURL
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(message: error.localizedDescription)
                    self.isProcessing = false
                }
            }
        }
    }

    private func saveToDocuments() {
        guard let url = outputURL else { return }
        do {
            let savedURL = try PDFProcessor.saveToDocuments(sourceURL: url)
            showSuccess = true
            print("已保存到: \(savedURL.path)")
        } catch {
            showError(message: "保存失败: \(error.localizedDescription)")
        }
    }

    private func showError(message: String) {
        self.errorMessage = message
        self.showError = true
    }

    private func reset() {
        sourceURL = nil
        sourceImage = nil
        outputURL = nil
        previewDocument = nil
    }
}

// MARK: - 上传按钮组件
struct UploadButton: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage) -> Void

        init(onPick: @escaping (UIImage) -> Void) {
            self.onPick = onPick
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onPick(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - 分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDF 预览
struct PDFPreviewView: View {
    let url: URL
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            PDFKitView(url: url)
                .navigationTitle("PDF 预览")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - 预览
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
