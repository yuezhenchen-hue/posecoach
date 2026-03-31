import Foundation

/// 拍摄方案：综合场景、参数、构图、Pose 的完整拍照计划
struct ShootingPlan: Identifiable {
    let id = UUID()
    let scene: SceneType
    let cameraParameters: CameraParameters
    let recommendedComposition: CompositionAnalyzer.CompositionGuide
    let recommendedPoses: [PoseTemplate]
    let creativeTips: [String]

    var summary: String {
        """
        场景：\(scene.displayName)
        构图：\(recommendedComposition.rawValue)
        推荐姿势：\(recommendedPoses.prefix(3).map(\.name).joined(separator: "、"))
        """
    }
}
