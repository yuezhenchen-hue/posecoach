import Vision
import UIKit
import CoreImage

/// 通用主体检测器：不限于人物，可检测景物、物体等任意拍摄主体
@MainActor
class SubjectDetector: ObservableObject {
    @Published var subjectBox: CGRect = .zero
    @Published var subjectType: SubjectType = .none
    @Published var subjectDescription: String = ""
    @Published var saliencyHeatmap: [CGRect] = []
    @Published var hasManualFocus: Bool = false

    private var lastDetectionTime: Date = .distantPast
    private let detectionInterval: TimeInterval = 0.25
    private var manualFocusPoint: CGPoint?
    private var manualFocusExpiry: Date = .distantPast

    enum SubjectType: String {
        case none = "无主体"
        case person = "人物"
        case multiplePeople = "多人"
        case object = "物体"
        case scene = "景色"
        case manualFocus = "手动聚焦"

        var icon: String {
            switch self {
            case .none: return "viewfinder"
            case .person: return "person.fill"
            case .multiplePeople: return "person.3.fill"
            case .object: return "cube.fill"
            case .scene: return "photo.artframe"
            case .manualFocus: return "scope"
            }
        }
    }

    /// 用户点击画面手动指定主体区域
    func setManualFocus(normalizedPoint: CGPoint) {
        manualFocusPoint = normalizedPoint
        manualFocusExpiry = Date().addingTimeInterval(10)
        hasManualFocus = true

        let boxSize: CGFloat = 0.2
        subjectBox = CGRect(
            x: max(0, normalizedPoint.x - boxSize / 2),
            y: max(0, normalizedPoint.y - boxSize / 2),
            width: boxSize,
            height: boxSize
        )
        subjectType = .manualFocus
        subjectDescription = "已锁定聚焦区域"
    }

    func clearManualFocus() {
        manualFocusPoint = nil
        hasManualFocus = false
    }

    /// 从视频帧检测主体
    func detect(sampleBuffer: CMSampleBuffer, personBox: CGRect, personCount: Int) {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        lastDetectionTime = now

        if hasManualFocus && now < manualFocusExpiry {
            return
        } else if hasManualFocus && now >= manualFocusExpiry {
            hasManualFocus = false
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        performUniversalDetection(handler: handler, personBox: personBox, personCount: personCount)
    }

    /// 从静态图片检测主体
    func detect(image: UIImage, personBox: CGRect, personCount: Int) {
        guard let cgImage = image.cgImage else { return }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        performUniversalDetection(handler: handler, personBox: personBox, personCount: personCount)
    }

    private func performUniversalDetection(handler: VNImageRequestHandler, personBox: CGRect, personCount: Int) {
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? handler.perform([saliencyRequest, objectnessRequest])

        var attentionRegions: [CGRect] = []
        if let saliencyResults = saliencyRequest.results, let first = saliencyResults.first {
            attentionRegions = first.salientObjects?.map { $0.boundingBox } ?? []
        }
        saliencyHeatmap = attentionRegions

        var objectRegions: [CGRect] = []
        if let objectResults = objectnessRequest.results, let first = objectResults.first {
            objectRegions = first.salientObjects?.map { $0.boundingBox } ?? []
        }

        resolveSubject(
            personBox: personBox,
            personCount: personCount,
            attentionRegions: attentionRegions,
            objectRegions: objectRegions
        )
    }

    /// 综合多种信号确定主体类型和位置
    private func resolveSubject(
        personBox: CGRect,
        personCount: Int,
        attentionRegions: [CGRect],
        objectRegions: [CGRect]
    ) {
        let hasPerson = personBox != .zero
        let bestAttention = attentionRegions.max(by: { $0.width * $0.height < $1.width * $1.height })
        let bestObject = objectRegions.max(by: { $0.width * $0.height < $1.width * $1.height })

        if hasPerson && personCount >= 2 {
            subjectBox = personBox
            subjectType = .multiplePeople
            let pos = positionDescription(for: personBox)
            subjectDescription = "检测到 \(personCount) 人，主角在\(pos)"
            return
        }

        if hasPerson && personCount == 1 {
            subjectBox = personBox
            subjectType = .person
            let pos = positionDescription(for: personBox)
            subjectDescription = "检测到人物，在画面\(pos)"
            return
        }

        if let attn = bestAttention, let obj = bestObject {
            let overlapArea = attn.intersection(obj).width * attn.intersection(obj).height
            let combinedConfidence = overlapArea / max(attn.width * attn.height, 0.001)

            if combinedConfidence > 0.2 {
                let merged = attn.union(obj)
                subjectBox = merged
                subjectType = .object
                let pos = positionDescription(for: merged)
                let sizeDesc = sizeDescription(for: merged)
                subjectDescription = "检测到\(sizeDesc)主体，在画面\(pos)"
                return
            }
        }

        if let attn = bestAttention, attn.width * attn.height > 0.01 {
            subjectBox = attn
            if attn.width * attn.height > 0.5 {
                subjectType = .scene
                subjectDescription = "检测到大面积景色"
            } else {
                subjectType = .object
                let pos = positionDescription(for: attn)
                subjectDescription = "发现兴趣点，在画面\(pos)"
            }
            return
        }

        subjectBox = .zero
        subjectType = .none
        subjectDescription = "寻找主体中..."
    }

    private func positionDescription(for box: CGRect) -> String {
        let cx = box.midX
        let cy = box.midY
        var parts: [String] = []
        if cy < 0.35 { parts.append("上方") }
        else if cy > 0.65 { parts.append("下方") }
        if cx < 0.35 { parts.append("左侧") }
        else if cx > 0.65 { parts.append("右侧") }
        if parts.isEmpty { parts.append("中间") }
        return parts.joined()
    }

    private func sizeDescription(for box: CGRect) -> String {
        let area = box.width * box.height
        if area > 0.3 { return "大面积" }
        if area > 0.1 { return "中等" }
        return "小"
    }
}
