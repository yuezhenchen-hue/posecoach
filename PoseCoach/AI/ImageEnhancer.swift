import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// AI 图像增强器：低光增强、细节放大、降噪
struct ImageEnhancer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// 低光场景增强：亮度提升+降噪+锐化
    static func enhanceLowLight(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        var enhanced = ciImage

        // 曝光自动提升
        let exposureFilter = CIFilter.exposureAdjust()
        exposureFilter.inputImage = enhanced
        exposureFilter.ev = 0.8
        if let output = exposureFilter.outputImage { enhanced = output }

        // 降噪
        let noiseFilter = CIFilter.noiseReduction()
        noiseFilter.inputImage = enhanced
        noiseFilter.noiseLevel = 0.02
        noiseFilter.sharpness = 0.6
        if let output = noiseFilter.outputImage { enhanced = output }

        // 对比度微调
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = enhanced
        colorFilter.contrast = 1.08
        colorFilter.saturation = 1.05
        colorFilter.brightness = 0.02
        if let output = colorFilter.outputImage { enhanced = output }

        // 锐化
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = enhanced
        sharpenFilter.sharpness = 0.5
        sharpenFilter.radius = 1.5
        if let output = sharpenFilter.outputImage { enhanced = output }

        return renderToUIImage(enhanced, originalSize: image.size) ?? image
    }

    /// AI 超分辨率：细节增强（基于 Lanczos 缩放 + 锐化）
    static func superResolution(_ image: UIImage, scale: CGFloat = 2.0) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = ciImage
        scaleFilter.scale = Float(scale)
        scaleFilter.aspectRatio = 1.0

        guard var scaled = scaleFilter.outputImage else { return image }

        // 锐化增强放大后的细节
        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = scaled
        sharpen.radius = 2.0
        sharpen.intensity = 0.8
        if let output = sharpen.outputImage { scaled = output }

        // 局部对比度增强
        let highlight = CIFilter.highlightShadowAdjust()
        highlight.inputImage = scaled
        highlight.shadowAmount = 0.3
        highlight.highlightAmount = 0.9
        if let output = highlight.outputImage { scaled = output }

        return renderToUIImage(scaled, originalSize: targetSize) ?? image
    }

    /// 自动优化：根据图片特征自动选择增强策略
    static func autoEnhance(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let adjustments = ciImage.autoAdjustmentFilters()
        var result = ciImage
        for filter in adjustments {
            filter.setValue(result, forKey: kCIInputImageKey)
            if let output = filter.outputImage { result = output }
        }

        return renderToUIImage(result, originalSize: image.size) ?? image
    }

    private static func renderToUIImage(_ ciImage: CIImage, originalSize: CGSize) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
