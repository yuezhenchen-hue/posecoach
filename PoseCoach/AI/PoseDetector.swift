import Vision
import UIKit

/// 人体姿态检测器：检测人体关键点，评估姿态质量，识别主体
@MainActor
class PoseDetector: ObservableObject {
    @Published var detectedPose: DetectedPose?
    @Published var personCount: Int = 0
    @Published var personBoundingBox: CGRect = .zero
    @Published var mainSubjectBox: CGRect = .zero
    @Published var saliencyRegions: [CGRect] = []
    @Published var mainSubjectDescription: String = ""

    private var lastDetectionTime: Date = .distantPast
    private let detectionInterval: TimeInterval = 0.2

    struct DetectedPose {
        let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
        let confidence: Float

        var isStanding: Bool {
            guard let leftAnkle = joints[.leftAnkle],
                  let rightAnkle = joints[.rightAnkle],
                  let nose = joints[.nose] else { return false }
            return nose.y < leftAnkle.y && nose.y < rightAnkle.y
        }

        var isFacingCamera: Bool {
            guard let leftShoulder = joints[.leftShoulder],
                  let rightShoulder = joints[.rightShoulder] else { return false }
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            return shoulderWidth > 0.1
        }

        var bodyOrientation: BodyOrientation {
            guard let leftShoulder = joints[.leftShoulder],
                  let rightShoulder = joints[.rightShoulder] else { return .unknown }
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            if shoulderWidth > 0.2 { return .frontal }
            if shoulderWidth > 0.1 { return .threeQuarter }
            return .side
        }
    }

    enum BodyOrientation: String {
        case frontal = "正面"
        case threeQuarter = "侧45度"
        case side = "侧面"
        case back = "背面"
        case unknown = "未知"
    }

    /// 从视频帧检测人体姿态
    func detect(sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        performDetection(on: .init(cvPixelBuffer: pixelBuffer, options: [:]))
    }

    /// 从静态图片检测人体姿态
    func detect(image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        performDetection(on: .init(cgImage: cgImage, options: [:]))
    }

    private func performDetection(on handler: VNImageRequestHandler) {
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let personRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()

        try? handler.perform([poseRequest, personRequest, saliencyRequest, faceRequest])

        // 人体矩形检测
        var allPersonBoxes: [CGRect] = []
        if let personResults = personRequest.results {
            personCount = personResults.count
            allPersonBoxes = personResults.map { $0.boundingBox }
            personBoundingBox = personResults.first?.boundingBox ?? .zero
        }

        // 注意力显著性检测 — 找到画面中最吸引注意的区域
        if let saliencyResults = saliencyRequest.results,
           let saliency = saliencyResults.first {
            let regions = saliency.salientObjects?.map { $0.boundingBox } ?? []
            saliencyRegions = regions
        }

        // 人脸检测 — 辅助确定主角
        let faceBoxes = faceRequest.results?.map { $0.boundingBox } ?? []

        // 综合判断主体：最大的人 + 人脸朝向镜头 + 显著性区域重叠
        identifyMainSubject(personBoxes: allPersonBoxes, faceBoxes: faceBoxes)

        // 姿态关键点
        guard let poseResults = poseRequest.results, let firstPose = poseResults.first else {
            detectedPose = nil
            return
        }

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for name in jointNames {
            if let point = try? firstPose.recognizedPoint(name), point.confidence > 0.3 {
                joints[name] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            }
        }

        let avgConfidence = Float(joints.count) / Float(jointNames.count)
        detectedPose = DetectedPose(joints: joints, confidence: avgConfidence)
    }

    /// 评估当前姿态的质量并给出建议
    func evaluatePose(for scene: SceneType) -> [PoseAdvice] {
        guard let pose = detectedPose else {
            return [PoseAdvice(type: .warning, message: "未检测到人物，请确保人物在画面中")]
        }

        var advices: [PoseAdvice] = []

        // 检查身体是否倾斜
        if let leftShoulder = pose.joints[.leftShoulder],
           let rightShoulder = pose.joints[.rightShoulder] {
            let tilt = abs(leftShoulder.y - rightShoulder.y)
            if tilt > 0.05 {
                advices.append(PoseAdvice(type: .correction, message: "身体有些倾斜，可以站直一些"))
            }
        }

        // 根据场景推荐特定姿态
        let recommendations = PoseTemplate.recommendations(for: scene)
        if let suggestion = recommendations.first {
            advices.append(PoseAdvice(type: .suggestion, message: "推荐姿势：\(suggestion.name) — \(suggestion.description)"))
        }

        if advices.isEmpty {
            advices.append(PoseAdvice(type: .good, message: "姿态很好，可以拍了！"))
        }

        return advices
    }

    /// 综合多种信号识别主体
    private func identifyMainSubject(personBoxes: [CGRect], faceBoxes: [CGRect]) {
        guard !personBoxes.isEmpty else {
            mainSubjectBox = .zero
            mainSubjectDescription = "未检测到人物"
            return
        }

        if personBoxes.count == 1 {
            mainSubjectBox = personBoxes[0]
            mainSubjectDescription = "检测到 1 人（主角）"
            return
        }

        // 多人场景：评分找出主角
        var bestScore: CGFloat = -1
        var bestBox: CGRect = .zero

        for box in personBoxes {
            var score: CGFloat = 0

            // 面积越大越可能是主角（越靠近镜头）
            score += box.width * box.height * 100

            // 越靠近画面中心越可能是主角
            let centerDist = abs(box.midX - 0.5) + abs(box.midY - 0.5)
            score += max(0, 1.0 - centerDist) * 30

            // 有人脸的更可能是主角
            for faceBox in faceBoxes {
                if box.intersects(faceBox) {
                    score += 50
                    // 人脸越大越可能是主角
                    score += faceBox.width * faceBox.height * 80
                }
            }

            // 与显著性区域重叠加分
            for region in saliencyRegions {
                if box.intersects(region) {
                    let overlap = box.intersection(region)
                    score += overlap.width * overlap.height * 60
                }
            }

            if score > bestScore {
                bestScore = score
                bestBox = box
            }
        }

        mainSubjectBox = bestBox
        let position = bestBox.midX < 0.4 ? "左侧" : (bestBox.midX > 0.6 ? "右侧" : "中间")
        mainSubjectDescription = "检测到 \(personBoxes.count) 人，主角在画面\(position)"
    }
}

struct PoseAdvice {
    enum AdviceType { case good, suggestion, correction, warning }

    let type: AdviceType
    let message: String

    var icon: String {
        switch type {
        case .good: return "checkmark.circle.fill"
        case .suggestion: return "lightbulb.fill"
        case .correction: return "arrow.triangle.2.circlepath"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}
