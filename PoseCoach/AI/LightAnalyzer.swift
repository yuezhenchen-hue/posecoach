import UIKit
import CoreImage
import AVFoundation

/// 光线分析器：检测光线方向、强度、色温，生成参数建议
@MainActor
class LightAnalyzer: ObservableObject {
    @Published var lightCondition: LightCondition = .normal
    @Published var brightness: Float = 0.5
    @Published var isBacklit = false
    @Published var colorTemperature: ColorTemperature = .neutral

    private var lastAnalysisTime: Date = .distantPast
    private let analysisInterval: TimeInterval = 0.5
    private let ciContext = CIContext()

    struct LightCondition: Equatable {
        let level: Level
        let description: String

        enum Level { case veryDark, dark, normal, bright, veryBright }

        static let veryDark = LightCondition(level: .veryDark, description: "光线非常暗")
        static let dark = LightCondition(level: .dark, description: "光线偏暗")
        static let normal = LightCondition(level: .normal, description: "光线良好")
        static let bright = LightCondition(level: .bright, description: "光线充足")
        static let veryBright = LightCondition(level: .veryBright, description: "光线过强")

        static func == (lhs: LightCondition, rhs: LightCondition) -> Bool {
            lhs.level == rhs.level
        }
    }

    enum ColorTemperature: String {
        case warm = "暖色调"
        case neutral = "中性"
        case cool = "冷色调"
    }

    /// 分析视频帧的光线条件
    func analyze(sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysisTime) >= analysisInterval else { return }
        lastAnalysisTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        analyzeImage(ciImage)
    }

    /// 分析静态图片的光线条件
    func analyze(image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        analyzeImage(ciImage)
    }

    private func analyzeImage(_ ciImage: CIImage) {
        let extent = ciImage.extent

        // 亮度分析：取整体平均亮度
        let overallBrightness = averageBrightness(of: ciImage, in: extent)
        brightness = overallBrightness

        // 逆光检测：比较上半部分和下半部分亮度差异
        let topHalf = CGRect(x: 0, y: extent.height / 2, width: extent.width, height: extent.height / 2)
        let bottomHalf = CGRect(x: 0, y: 0, width: extent.width, height: extent.height / 2)
        let topBrightness = averageBrightness(of: ciImage, in: topHalf)
        let bottomBrightness = averageBrightness(of: ciImage, in: bottomHalf)
        isBacklit = topBrightness > bottomBrightness * 1.8

        // 色温分析
        colorTemperature = analyzeColorTemperature(ciImage, in: extent)

        // 光线等级
        lightCondition = classifyBrightness(overallBrightness)
    }

    private func averageBrightness(of image: CIImage, in rect: CGRect) -> Float {
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image.cropped(to: rect),
            kCIInputExtentKey: CIVector(cgRect: rect)
        ])

        guard let output = filter?.outputImage else { return 0.5 }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        let r = Float(pixel[0]) / 255.0
        let g = Float(pixel[1]) / 255.0
        let b = Float(pixel[2]) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    private func analyzeColorTemperature(_ image: CIImage, in rect: CGRect) -> ColorTemperature {
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: rect)
        ])
        guard let output = filter?.outputImage else { return .neutral }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        let r = Float(pixel[0])
        let b = Float(pixel[2])
        let ratio = r / max(b, 1)

        if ratio > 1.3 { return .warm }
        if ratio < 0.8 { return .cool }
        return .neutral
    }

    private func classifyBrightness(_ value: Float) -> LightCondition {
        switch value {
        case ..<0.15: return .veryDark
        case 0.15..<0.35: return .dark
        case 0.35..<0.65: return .normal
        case 0.65..<0.85: return .bright
        default: return .veryBright
        }
    }

    /// 根据当前光线生成相机参数建议
    func recommendParameters() -> CameraParameters {
        var params = CameraParameters()

        switch lightCondition.level {
        case .veryDark:
            params.exposureBias = 1.0
            params.flashMode = .auto
            params.hdrEnabled = true
            params.suggestion = "光线很暗，建议开启闪光灯或找更亮的位置"
        case .dark:
            params.exposureBias = 0.5
            params.hdrEnabled = true
            params.suggestion = "光线偏暗，已提高曝光补偿"
        case .normal:
            params.suggestion = "光线良好，适合拍照"
        case .bright:
            params.exposureBias = -0.3
            params.suggestion = "光线充足，注意避免脸部阴影"
        case .veryBright:
            params.exposureBias = -0.7
            params.hdrEnabled = true
            params.suggestion = "光线过强，建议开启 HDR 或找阴影处"
        }

        if isBacklit {
            params.exposureBias = (params.exposureBias ?? 0) + 0.5
            params.hdrEnabled = true
            params.suggestion = "检测到逆光！建议转向或开启 HDR 补光"
        }

        return params
    }
}
