import Vision
import UIKit
import CoreImage

/// 场景分类器：识别当前拍摄场景（海边/城市/室内/自然等）
@MainActor
class SceneClassifier: ObservableObject {
    @Published var currentScene: SceneType = .unknown
    @Published var confidence: Float = 0.0
    @Published var isManualOverride = false

    private var classificationRequest: VNClassifyImageRequest?
    private var lastClassificationTime: Date = .distantPast
    private let classificationInterval: TimeInterval = 1.0

    init() {
        setupClassificationRequest()
    }

    /// 手动指定场景（锁定，不被自动识别覆盖）
    func setManualScene(_ scene: SceneType) {
        currentScene = scene
        confidence = 1.0
        isManualOverride = true
    }

    /// 切回自动识别
    func clearManualOverride() {
        isManualOverride = false
    }

    private func setupClassificationRequest() {
        classificationRequest = VNClassifyImageRequest { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else { return }

            Task { @MainActor in
                self?.currentScene = SceneType.from(classificationIdentifier: topResult.identifier)
                self?.confidence = topResult.confidence
            }
        }
    }

    /// 从实时视频帧分析场景
    func classify(sampleBuffer: CMSampleBuffer) {
        guard !isManualOverride else { return }

        let now = Date()
        guard now.timeIntervalSince(lastClassificationTime) >= classificationInterval else { return }
        lastClassificationTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = classificationRequest else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    /// 从静态图片分析场景（照着拍模式使用）
    func classify(image: UIImage) -> SceneType {
        guard let cgImage = image.cgImage,
              let request = classificationRequest else { return .unknown }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return currentScene
    }
}
