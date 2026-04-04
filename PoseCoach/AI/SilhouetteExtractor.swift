import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 人物轮廓提取器：从图片中提取人物蒙版，生成半透明轮廓
class SilhouetteExtractor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// 从图片中提取人物轮廓蒙版（白色人物，透明背景）
    static func extractSilhouette(from image: UIImage, style: SilhouetteStyle = .outline) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let result = request.results?.first else { return nil }
        let maskBuffer = result.pixelBuffer

        let maskCI = CIImage(cvPixelBuffer: maskBuffer)
        let originalCI = CIImage(cgImage: cgImage)

        let scaleX = originalCI.extent.width / maskCI.extent.width
        let scaleY = originalCI.extent.height / maskCI.extent.height
        let scaledMask = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        switch style {
        case .filled:
            return renderFilledSilhouette(mask: scaledMask, size: originalCI.extent)
        case .outline:
            return renderOutlineSilhouette(mask: scaledMask, size: originalCI.extent)
        case .semiTransparent:
            return renderSemiTransparentSilhouette(original: originalCI, mask: scaledMask)
        }
    }

    /// 从图片提取人体关键点（用于姿态对比）
    static func extractPoseJoints(from image: UIImage) -> [VNHumanBodyPoseObservation.JointName: CGPoint]? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let pose = request.results?.first else { return nil }

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        let names: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for name in names {
            if let point = try? pose.recognizedPoint(name), point.confidence > 0.3 {
                joints[name] = CGPoint(x: point.location.x, y: point.location.y)
            }
        }

        return joints.isEmpty ? nil : joints
    }

    /// 对比两组关键点的相似度（0~100）
    static func comparePoses(
        templateJoints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        liveJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    ) -> PoseComparisonResult {
        let compareNames: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        var matchedCount = 0
        var totalDeviation: CGFloat = 0
        var mismatchedJoints: [String] = []

        let templateNorm = normalizeJoints(templateJoints)
        let liveNorm = normalizeJoints(liveJoints)

        for name in compareNames {
            guard let tp = templateNorm[name], let lp = liveNorm[name] else { continue }
            let dist = hypot(tp.x - lp.x, tp.y - lp.y)
            totalDeviation += dist

            if dist < 0.12 {
                matchedCount += 1
            } else {
                mismatchedJoints.append(jointDisplayName(name))
            }
        }

        let checked = min(compareNames.count, max(templateNorm.count, liveNorm.count))
        guard checked > 0 else { return PoseComparisonResult(score: 0, feedback: "无法检测姿态", mismatchedParts: []) }

        let avgDev = totalDeviation / CGFloat(checked)
        let score = max(0, min(100, Int(100 * (1.0 - avgDev * 3.0))))

        let feedback: String
        switch score {
        case 90...: feedback = "姿态非常标准！"
        case 70..<90: feedback = "姿态不错，微调即可"
        case 50..<70: feedback = "接近了，继续调整"
        default: feedback = "还需要调整姿势"
        }

        return PoseComparisonResult(score: score, feedback: feedback, mismatchedParts: mismatchedJoints)
    }

    // MARK: - Render Styles

    /// 纯色填充轮廓
    private static func renderFilledSilhouette(mask: CIImage, size: CGRect) -> UIImage? {
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 0.6))
            .cropped(to: size)

        let composite = CIFilter.blendWithMask()
        composite.inputImage = white
        composite.backgroundImage = CIImage.empty().cropped(to: size)
        composite.maskImage = mask

        guard let output = composite.outputImage,
              let cg = ciContext.createCGImage(output, from: size) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 轮廓线条描边
    private static func renderOutlineSilhouette(mask: CIImage, size: CGRect) -> UIImage? {
        let edgeFilter = CIFilter.edges()
        edgeFilter.inputImage = mask
        edgeFilter.intensity = 5.0

        guard let edgeOutput = edgeFilter.outputImage else { return nil }

        let colorFilter = CIFilter.colorMatrix()
        colorFilter.inputImage = edgeOutput
        colorFilter.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        colorFilter.gVector = CIVector(x: 0, y: 0.8, z: 0, w: 0)
        colorFilter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)

        guard let colored = colorFilter.outputImage,
              let cg = ciContext.createCGImage(colored, from: size) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// 半透明（原图 + 降低透明度）
    private static func renderSemiTransparentSilhouette(original: CIImage, mask: CIImage) -> UIImage? {
        let alphaFilter = CIFilter.colorMatrix()
        alphaFilter.inputImage = original
        alphaFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 0.35)

        guard let semiOriginal = alphaFilter.outputImage else { return nil }

        let composite = CIFilter.blendWithMask()
        composite.inputImage = semiOriginal
        composite.backgroundImage = CIImage.empty().cropped(to: original.extent)
        composite.maskImage = mask

        guard let output = composite.outputImage,
              let cg = ciContext.createCGImage(output, from: original.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Helpers

    /// 将关键点归一化到 [0,1] 范围（相对于人体包围盒）
    private static func normalizeJoints(_ joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        guard !joints.isEmpty else { return [:] }
        let xs = joints.values.map(\.x)
        let ys = joints.values.map(\.y)
        let minX = xs.min()!; let maxX = xs.max()!
        let minY = ys.min()!; let maxY = ys.max()!
        let rangeX = max(maxX - minX, 0.001)
        let rangeY = max(maxY - minY, 0.001)

        var normalized: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (name, point) in joints {
            normalized[name] = CGPoint(x: (point.x - minX) / rangeX, y: (point.y - minY) / rangeY)
        }
        return normalized
    }

    private static func jointDisplayName(_ name: VNHumanBodyPoseObservation.JointName) -> String {
        switch name {
        case .leftShoulder: return "左肩"
        case .rightShoulder: return "右肩"
        case .leftElbow: return "左肘"
        case .rightElbow: return "右肘"
        case .leftWrist: return "左手"
        case .rightWrist: return "右手"
        case .leftHip: return "左胯"
        case .rightHip: return "右胯"
        case .leftKnee: return "左膝"
        case .rightKnee: return "右膝"
        case .leftAnkle: return "左脚"
        case .rightAnkle: return "右脚"
        default: return "未知"
        }
    }

    enum SilhouetteStyle {
        case filled
        case outline
        case semiTransparent
    }
}

struct PoseComparisonResult {
    let score: Int
    let feedback: String
    let mismatchedParts: [String]

    var level: MatchLevel {
        switch score {
        case 90...: return .perfect
        case 70..<90: return .good
        case 50..<70: return .fair
        default: return .needsWork
        }
    }

    enum MatchLevel: String {
        case perfect = "完美匹配"
        case good = "不错"
        case fair = "接近"
        case needsWork = "继续调整"

        var color: String {
            switch self {
            case .perfect: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .needsWork: return "red"
            }
        }
    }
}
