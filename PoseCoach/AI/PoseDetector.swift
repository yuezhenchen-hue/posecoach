import Vision
import UIKit

/// 人体姿态检测器：检测人体关键点，评估姿态质量，推荐 Pose
@MainActor
class PoseDetector: ObservableObject {
    @Published var detectedPose: DetectedPose?
    @Published var personCount: Int = 0
    @Published var personBoundingBox: CGRect = .zero

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

        try? handler.perform([poseRequest, personRequest])

        // 人体矩形检测
        if let personResults = personRequest.results {
            personCount = personResults.count
            personBoundingBox = personResults.first?.boundingBox ?? .zero
        }

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
