import Foundation

/// 参数推荐引擎：根据场景+光线组合推荐最佳相机参数
@MainActor
struct ParameterRecommender {

    /// 根据场景和光线条件生成最佳参数组合
    static func recommend(scene: SceneType, lightAnalyzer: LightAnalyzer) -> CameraParameters {
        var params = lightAnalyzer.recommendParameters()

        // 场景特化参数调整
        switch scene {
        case .beach, .sunset:
            params.hdrEnabled = true
            if lightAnalyzer.isBacklit {
                params.exposureBias = (params.exposureBias ?? 0) + 0.3
                params.suggestion = "日落/海边逆光场景，已提高曝光保留人脸细节"
            }
            params.usePortraitMode = false

        case .cityStreet, .architecture:
            params.usePortraitMode = false
            params.suggestion = (params.suggestion ?? "") + "。街景建议关闭人像模式，保留环境细节"

        case .cafe, .indoor:
            params.usePortraitMode = true
            if lightAnalyzer.lightCondition.level == .dark || lightAnalyzer.lightCondition.level == .veryDark {
                params.flashMode = .auto
                params.suggestion = "室内光线不足，建议靠近窗户利用自然光"
            }

        case .nature, .garden:
            params.hdrEnabled = true
            params.usePortraitMode = true
            params.suggestion = (params.suggestion ?? "") + "。自然场景建议人像模式虚化背景"

        case .nightScene:
            params.exposureBias = 0.5
            params.hdrEnabled = true
            params.usePortraitMode = false
            params.suggestion = "夜景模式：保持手机稳定，可靠在固定物上"

        case .amusementPark:
            params.hdrEnabled = true
            params.suggestion = (params.suggestion ?? "") + "。游乐园场景色彩丰富，HDR可保留更多细节"

        default:
            break
        }

        return params
    }

    /// 对比两张图的参数差异，用于「照着拍」模式
    static func matchParameters(from referenceAnalysis: ReferencePhotoAnalysis) -> CameraParameters {
        var params = CameraParameters()

        params.exposureBias = referenceAnalysis.estimatedExposure
        params.hdrEnabled = referenceAnalysis.hasHighDynamicRange
        params.usePortraitMode = referenceAnalysis.hasShallowDepthOfField
        params.suggestion = "已根据参考图调整参数"

        if referenceAnalysis.isBacklit {
            params.exposureBias = (params.exposureBias ?? 0) + 0.5
            params.hdrEnabled = true
        }

        return params
    }
}

/// 参考图分析结果
struct ReferencePhotoAnalysis {
    var scene: SceneType = .unknown
    var estimatedExposure: Float?
    var hasHighDynamicRange: Bool = false
    var hasShallowDepthOfField: Bool = false
    var isBacklit: Bool = false
    var dominantColorTemperature: LightAnalyzer.ColorTemperature = .neutral
    var personBoundingBox: CGRect = .zero
    var poseDescription: String = ""
    var compositionType: CompositionAnalyzer.CompositionGuide = .ruleOfThirds
    var estimatedDistance: ShootingDistance = .medium

    enum ShootingDistance: String {
        case closeUp = "特写（1米内）"
        case medium = "中景（1-3米）"
        case full = "全身（3-5米）"
        case far = "远景（5米以上）"
    }
}
