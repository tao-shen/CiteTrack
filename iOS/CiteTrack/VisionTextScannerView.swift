import SwiftUI
import AVFoundation
import Vision
import UIKit

public struct VisionTextScannerView: View {
    public var onDetected: (String) -> Void
    public var onCancel: (() -> Void)?
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var captureTick: Int = 0
    @State private var scanAtTop: Bool = true
    @State private var pulse: Bool = false

    public init(onDetected: @escaping (String) -> Void, onCancel: (() -> Void)? = nil) {
        self.onDetected = onDetected
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            if authorizationStatus == .authorized {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    let stripWidth = min(w * 0.9, 640)
                    let stripHeight = max(44, min(72, h * 0.12))
                    let boxRect = CGRect(
                        x: (w - stripWidth) / 2.0,
                        y: (h - stripHeight) / 2.0,
                        width: stripWidth,
                        height: stripHeight
                    )
                    // 传入标准化取景框，供拍照后裁剪
                    let normalizedRect = CGRect(x: boxRect.minX / w,
                                                y: boxRect.minY / h,
                                                width: boxRect.width / w,
                                                height: boxRect.height / h)
                    ZStack {
                        CameraPreview(onDetected: onDetected, captureTick: $captureTick, targetNormalizedRect: normalizedRect)
                            .ignoresSafeArea()
                        ViewfinderMaskView(boxRect: boxRect)
                            .ignoresSafeArea()
                        ViewfinderCornersView(boxRect: boxRect)
                            .opacity(pulse ? 1.0 : 0.85)
                            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                            .allowsHitTesting(false)
                        // Subtle scan line
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                            .frame(width: boxRect.width, height: 2)
                            .position(x: boxRect.midX,
                                      y: boxRect.minY + (scanAtTop ? 0 : (boxRect.height - 2)))
                            .blendMode(.screen)
                            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: scanAtTop)
                    }
                }
            } else if authorizationStatus == .notDetermined {
                Color.black.ignoresSafeArea().onAppear { requestPermission() }
            } else {
                VStack(spacing: 12) {
                    Text("camera_permission_required".localized).font(.headline)
                    Text("camera_permission_instructions".localized)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("camera_permission_granted".localized) {
                        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    }
                }
                .padding()
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { onCancel?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(radius: 3)
                    }
                    .padding(14)
                }
                Spacer()
                VStack(spacing: 14) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        captureTick &+= 1
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.95), lineWidth: 5)
                                .frame(width: 66, height: 66)
                                .shadow(radius: 6)
                            Circle()
                                .fill(Color.white.opacity(0.95))
                                .frame(width: 54, height: 54)
                        }
                    }
                    Text(localizationManager.localized("scan_instructions"))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.bottom, 12)
                }
                .padding(.bottom, 26)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                scanAtTop.toggle()
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
}

private struct ViewfinderMaskView: View {
    var boxRect: CGRect
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                var path = Path(CGRect(origin: .zero, size: size))
                let hole = Path(roundedRect: boxRect, cornerRadius: 8)
                path.addPath(hole)
                context.fill(path, with: .color(Color.black.opacity(0.62)), style: FillStyle(eoFill: true))
                // 更克制的边缘
                context.stroke(hole, with: .color(Color.white.opacity(0.85)), lineWidth: 0.6)
            }
        }
        .ignoresSafeArea()
    }
}

private struct ViewfinderCornersView: View {
    var boxRect: CGRect
    var cornerLength: CGFloat = 22
    var lineWidth: CGFloat = 2.5
    var bodyColor: Color = .white
    var body: some View {
        Canvas { context, size in
            let r = boxRect
            let c = bodyColor
            func drawCorner(_ start: CGPoint, _ p1: CGPoint, _ p2: CGPoint) {
                var path = Path()
                path.move(to: start)
                path.addLine(to: p1)
                context.stroke(path, with: .color(c), lineWidth: lineWidth)
                path = Path()
                path.move(to: start)
                path.addLine(to: p2)
                context.stroke(path, with: .color(c), lineWidth: lineWidth)
            }
            // 左上
            drawCorner(CGPoint(x: r.minX, y: r.minY),
                       CGPoint(x: r.minX + cornerLength, y: r.minY),
                       CGPoint(x: r.minX, y: r.minY + cornerLength))
            // 右上
            drawCorner(CGPoint(x: r.maxX, y: r.minY),
                       CGPoint(x: r.maxX - cornerLength, y: r.minY),
                       CGPoint(x: r.maxX, y: r.minY + cornerLength))
            // 左下
            drawCorner(CGPoint(x: r.minX, y: r.maxY),
                       CGPoint(x: r.minX + cornerLength, y: r.maxY),
                       CGPoint(x: r.minX, y: r.maxY - cornerLength))
            // 右下
            drawCorner(CGPoint(x: r.maxX, y: r.maxY),
                       CGPoint(x: r.maxX - cornerLength, y: r.maxY),
                       CGPoint(x: r.maxX, y: r.maxY - cornerLength))
        }
        .allowsHitTesting(false)
    }
}

private struct CameraPreview: UIViewControllerRepresentable {
    var onDetected: (String) -> Void
    @Binding var captureTick: Int
    var targetNormalizedRect: CGRect

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onDetected = onDetected
        vc.targetNormalizedRect = targetNormalizedRect
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.targetNormalizedRect = targetNormalizedRect
        if context.coordinator.lastCaptureTick != captureTick {
            context.coordinator.lastCaptureTick = captureTick
            uiViewController.capturePhotoForRecognition()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastCaptureTick: Int = 0
    }
}

final class ScannerViewController: UIViewController {
    var onDetected: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isProcessingFrame = false
    private var hasFoundResult = false
    var targetNormalizedRect: CGRect = CGRect(x: 0.05, y: 0.45, width: 0.9, height: 0.1)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        // 仅使用照片输出进行识别
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            // iOS 16+ 使用 maxPhotoDimensions，无需单独开启高分辨率
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    // MARK: - Tap to capture for recognition
    func capturePhotoForRecognition() {
        if isProcessingFrame || hasFoundResult { return }
        isProcessingFrame = true
        let settings = AVCapturePhotoSettings()
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private static func extractScholarToken(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 优先匹配URL中的 user 参数
        let urlPatterns = [
            #"https?:\/\/scholar\.google\.com\/citations\?user=([A-Za-z0-9_-]{8,40})"#,
            #"citations\?user=([A-Za-z0-9_-]{8,40})"#,
            #"user=([A-Za-z0-9_-]{8,40})"#
        ]
        for pattern in urlPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)),
               let range = Range(match.range(at: 1), in: trimmed) {
                return String(trimmed[range])
            }
        }

        // 再兜底匹配裸 ID
        if let range = trimmed.range(of: #"\b[A-Za-z0-9_-]{8,40}\b"#, options: .regularExpression) {
            return String(trimmed[range])
        }

        return nil
    }
}

extension ScannerViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            DispatchQueue.main.async { [weak self] in self?.isProcessingFrame = false }
            return
        }
        guard let cgImage = photo.cgImageRepresentation() else {
            DispatchQueue.main.async { [weak self] in self?.isProcessingFrame = false }
            return
        }
        // 计算需要裁剪的区域（基于预览层的normalizedRect映射到图像像素）
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // 将控制器视图中标准化rect映射为元数据rect，然后映射到图像像素
        let layerRect = CGRect(x: targetNormalizedRect.minX * view.bounds.width,
                               y: targetNormalizedRect.minY * view.bounds.height,
                               width: targetNormalizedRect.width * view.bounds.width,
                               height: targetNormalizedRect.height * view.bounds.height)
        let metadataRect = previewLayer?.metadataOutputRectConverted(fromLayerRect: layerRect) ?? targetNormalizedRect
        let cropRect = CGRect(x: metadataRect.minX * imageWidth,
                              y: metadataRect.minY * imageHeight,
                              width: metadataRect.width * imageWidth,
                              height: metadataRect.height * imageHeight).integral

        guard let cropped = cgImage.cropping(to: cropRect) else {
            DispatchQueue.main.async { [weak self] in self?.isProcessingFrame = false }
            return
        }

        // 使用Vision识别裁剪区域
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let candidates: [String] = observations.compactMap { $0.topCandidates(1).first?.string }
            let merged = candidates.joined(separator: " ")
            if let extracted = Self.extractScholarToken(from: merged) {
                self.hasFoundResult = true
                DispatchQueue.main.async { self.onDetected?(extracted) }
                return
            }
            for line in candidates {
                if let extracted = Self.extractScholarToken(from: line) {
                    self.hasFoundResult = true
                    DispatchQueue.main.async { self.onDetected?(extracted) }
                    return
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en", "zh-Hans", "zh-Hant"]

        let handler = VNImageRequestHandler(cgImage: cropped, orientation: .up, options: [:])
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do { try handler.perform([request]) } catch { /* ignore */ }
            DispatchQueue.main.async { self?.isProcessingFrame = false }
        }
    }
}


