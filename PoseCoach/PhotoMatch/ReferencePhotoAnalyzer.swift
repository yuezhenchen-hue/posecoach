import UIKit
import Vision
import CoreImage

/// 参考图分析器：全方位分析一张参考照片，提取拍摄方案
@MainActor
class ReferencePhotoAnalyzer: ObservableObject {
    @Published var analysis: ReferencePhotoAnalysis?
    @Published var isAnalyzing = false
    @Published var referencePose: PoseDetector.DetectedPose?

    private let sceneClassifier = SceneClassifier()
    private let lightAnalyzer = LightAnalyzer()
    private let poseDetector = PoseDetector()
    private let ciContext = CIContext()

    /// 全面分析参考图
    func analyze(image: UIImage) async -> ReferencePhotoAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        var result = ReferencePhotoAnalysis()

        // 1. 场景识别
        result.scene = sceneClassifier.classify(image: image)

        // 2. 光线分析
        lightAnalyzer.analyze(image: image)
        result.isBacklit = lightAnalyzer.isBacklit
        result.dominantColorTemperature = lightAnalyzer.colorTemperature
        result.estimatedExposure = estimateExposure(from: image)
        result.hasHighDynamicRange = estimateHDR(from: image)

        // 3. 人体检测和姿态分析
        poseDetector.detect(image: image)
        if let pose = poseDetector.detectedPose {
            referencePose = pose
            result.poseDescription = describePose(pose)
            result.personBoundingBox = poseDetector.personBoundingBox
        }

        // 4. 构图分析
        result.compositionType = analyzeCompositionType(personBox: result.personBoundingBox)

        // 5. 景深估计（浅景深=人像模式）
        result.hasShallowDepthOfField = estimateShallowDOF(from: image)

        // 6. 拍摄距离估计
        result.estimatedDistance = estimateDistance(personBox: result.personBoundingBox)

        analysis = result
        return result
    }

    /// 将分析结果转为用户可读的拍摄指南
    func generateGuide() -> [PhotoMatchGuide] {
        guard let analysis else { return [] }
        var guides: [PhotoMatchGuide] = []

        // 场景
        guides.append(PhotoMatchGuide(
            icon: "map.fill",
            title: "场景",
            description: analysis.scene.displayName,
            detail: "找一个类似的\(analysis.scene.displayName)场景"
        ))

        // 光线
        let lightDesc = analysis.isBacklit ? "逆光拍摄" : "顺光/侧光"
        guides.append(PhotoMatchGuide(
            icon: "sun.max.fill",
            title: "光线",
            description: "\(lightDesc) · \(analysis.dominantColorTemperature.rawValue)",
            detail: analysis.isBacklit ? "需要面朝光源，人物背对光" : "光线从侧面或正面照射"
        ))

        // 参数
        var paramDetails: [String] = []
        if analysis.hasShallowDepthOfField { paramDetails.append("人像模式（背景虚化）") }
        if analysis.hasHighDynamicRange { paramDetails.append("HDR 开启") }
        if let exp = analysis.estimatedExposure { paramDetails.append("曝光补偿 \(String(format: "%+.1f", exp))") }
        guides.append(PhotoMatchGuide(
            icon: "camera.aperture",
            title: "相机参数",
            description: paramDetails.joined(separator: " · "),
            detail: "点击「一键应用」自动设置参数"
        ))

        // 构图
        guides.append(PhotoMatchGuide(
            icon: "squareshape.split.3x3",
            title: "构图",
            description: analysis.compositionType.rawValue,
            detail: "人物在画面\(describePosition(analysis.personBoundingBox))的位置"
        ))

        // 姿态
        if !analysis.poseDescription.isEmpty {
            guides.append(PhotoMatchGuide(
                icon: "figure.stand",
                title: "姿势",
                description: analysis.poseDescription,
                detail: "打开相机后会实时对比姿势匹配度"
            ))
        }

        // 距离
        guides.append(PhotoMatchGuide(
            icon: "ruler",
            title: "拍摄距离",
            description: analysis.estimatedDistance.rawValue,
            detail: "手机距离被拍者约\(analysis.estimatedDistance.rawValue)"
        ))

        return guides
    }

    // MARK: - Private Analysis Helpers

    private func estimateExposure(from image: UIImage) -> Float? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        let brightness = (Float(pixel[0]) + Float(pixel[1]) + Float(pixel[2])) / (3 * 255)
        if brightness < 0.35 { return 0.5 }
        if brightness > 0.7 { return -0.5 }
        return 0
    }

    private func estimateHDR(from image: UIImage) -> Bool {
        guard let ciImage = CIImage(image: image) else { return false }
        let extent = ciImage.extent

        let topRect = CGRect(x: 0, y: extent.height * 0.7, width: extent.width, height: extent.height * 0.3)
        let bottomRect = CGRect(x: 0, y: 0, width: extent.width, height: extent.height * 0.3)

        let topBright = areaBrightness(ciImage, rect: topRect)
        let bottomBright = areaBrightness(ciImage, rect: bottomRect)

        return abs(topBright - bottomBright) > 0.3
    }

    private func areaBrightness(_ image: CIImage, rect: CGRect) -> Float {
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image.cropped(to: rect),
            kCIInputExtentKey: CIVector(cgRect: rect)
        ])
        guard let output = filter?.outputImage else { return 0.5 }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        return (Float(pixel[0]) + Float(pixel[1]) + Float(pixel[2])) / (3 * 255)
    }

    private func estimateShallowDOF(from image: UIImage) -> Bool {
        guard let ciImage = CIImage(image: image) else { return false }
        let extent = ciImage.extent

        let centerRect = CGRect(
            x: extent.width * 0.3, y: extent.height * 0.3,
            width: extent.width * 0.4, height: extent.height * 0.4
        )
        let edgeRect = CGRect(x: 0, y: 0, width: extent.width * 0.2, height: extent.height * 0.2)

        let centerSharpness = areaSharpness(ciImage, rect: centerRect)
        let edgeSharpness = areaSharpness(ciImage, rect: edgeRect)

        return centerSharpness > edgeSharpness * 1.5
    }

    private func areaSharpness(_ image: CIImage, rect: CGRect) -> Float {
        let cropped = image.cropped(to: rect)
        guard let edgeFilter = CIFilter(name: "CIEdges", parameters: [kCIInputImageKey: cropped]),
              let edgeImage = edgeFilter.outputImage,
              let avgFilter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: edgeImage,
                  kCIInputExtentKey: CIVector(cgRect: edgeImage.extent)
              ]),
              let output = avgFilter.outputImage else { return 0 }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        return Float(pixel[0]) / 255.0
    }

    private func describePose(_ pose: PoseDetector.DetectedPose) -> String {
        var descriptions: [String] = []
        descriptions.append(pose.bodyOrientation.rawValue)
        if pose.isStanding { descriptions.append("站姿") }

        if let leftWrist = pose.joints[.leftWrist], let leftShoulder = pose.joints[.leftShoulder] {
            if leftWrist.y < leftShoulder.y { descriptions.append("左手抬起") }
        }
        if let rightWrist = pose.joints[.rightWrist], let rightShoulder = pose.joints[.rightShoulder] {
            if rightWrist.y < rightShoulder.y { descriptions.append("右手抬起") }
        }

        return descriptions.joined(separator: " · ")
    }

    private func analyzeCompositionType(personBox: CGRect) -> CompositionAnalyzer.CompositionGuide {
        guard personBox != .zero else { return .ruleOfThirds }
        let centerX = personBox.midX

        if abs(centerX - 0.5) < 0.1 { return .center }
        if abs(centerX - 1.0/3.0) < 0.1 || abs(centerX - 2.0/3.0) < 0.1 { return .ruleOfThirds }
        return .goldenRatio
    }

    private func describePosition(_ box: CGRect) -> String {
        let x = box.midX
        if x < 0.35 { return "偏左" }
        if x > 0.65 { return "偏右" }
        return "居中"
    }

    private func estimateDistance(personBox: CGRect) -> ReferencePhotoAnalysis.ShootingDistance {
        let personHeight = personBox.height
        if personHeight > 0.8 { return .closeUp }
        if personHeight > 0.5 { return .medium }
        if personHeight > 0.25 { return .full }
        return .far
    }
}

struct PhotoMatchGuide: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let detail: String
}
