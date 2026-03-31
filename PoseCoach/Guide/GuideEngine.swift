import Foundation
import Combine
import AVFoundation

/// 引导引擎：协调所有 AI 模块，生成综合拍摄建议
@MainActor
class GuideEngine: ObservableObject {
    @Published var shootingPlan: ShootingPlan?
    @Published var currentAdvices: [GuideAdvice] = []
    @Published var overallReadiness: ReadinessLevel = .notReady

    let sceneClassifier = SceneClassifier()
    let lightAnalyzer = LightAnalyzer()
    let poseDetector = PoseDetector()
    let compositionAnalyzer = CompositionAnalyzer()
    let voiceCoach = VoiceCoach()

    enum ReadinessLevel: String {
        case notReady = "准备中..."
        case almostReady = "快好了"
        case ready = "可以拍了！"
        case perfect = "完美！快按快门！"

        var color: String {
            switch self {
            case .notReady: return "red"
            case .almostReady: return "yellow"
            case .ready: return "green"
            case .perfect: return "blue"
            }
        }
    }

    struct GuideAdvice: Identifiable {
        let id = UUID()
        let category: Category
        let message: String
        let priority: Int

        enum Category: String {
            case scene = "场景"
            case light = "光线"
            case composition = "构图"
            case pose = "姿态"
            case parameter = "参数"
            case creative = "创意"
        }
    }

    /// 处理每一帧视频数据，更新所有分析结果
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        sceneClassifier.classify(sampleBuffer: sampleBuffer)
        lightAnalyzer.analyze(sampleBuffer: sampleBuffer)
        poseDetector.detect(sampleBuffer: sampleBuffer)

        if poseDetector.personBoundingBox != .zero {
            compositionAnalyzer.analyze(
                personBoundingBox: poseDetector.personBoundingBox,
                imageSize: CGSize(width: 1, height: 1)
            )
        }

        updateAdvices()
    }

    /// 综合所有分析结果，生成排序后的建议列表
    private func updateAdvices() {
        var advices: [GuideAdvice] = []
        var readyCount = 0
        let _ = 4 // totalChecks

        // 1. 场景建议
        let scene = sceneClassifier.currentScene
        if scene != .unknown {
            readyCount += 1
            advices.append(GuideAdvice(
                category: .scene,
                message: "场景：\(scene.displayName)",
                priority: 0
            ))
        }

        // 2. 光线建议
        let lightParams = lightAnalyzer.recommendParameters()
        if let suggestion = lightParams.suggestion {
            advices.append(GuideAdvice(category: .light, message: suggestion, priority: 1))
        }
        if lightAnalyzer.lightCondition == .normal || lightAnalyzer.lightCondition == .bright {
            readyCount += 1
        }

        // 3. 构图建议
        if let composition = compositionAnalyzer.currentComposition {
            advices.append(GuideAdvice(
                category: .composition,
                message: composition.suggestion,
                priority: 2
            ))
            if composition.score > 70 { readyCount += 1 }

            if let hint = composition.movementHint {
                advices.append(GuideAdvice(
                    category: .composition,
                    message: hint.description,
                    priority: 3
                ))
            }
        }

        // 4. 姿态建议
        let poseAdvices = poseDetector.evaluatePose(for: scene)
        for advice in poseAdvices {
            let priority = advice.type == .good ? 0 : 4
            advices.append(GuideAdvice(category: .pose, message: advice.message, priority: priority))
            if advice.type == .good { readyCount += 1 }
        }

        // 排序：priority 低的更重要
        currentAdvices = advices.sorted { $0.priority < $1.priority }

        // 就绪度
        switch readyCount {
        case 0...1: overallReadiness = .notReady
        case 2: overallReadiness = .almostReady
        case 3: overallReadiness = .ready
        default: overallReadiness = .perfect
        }

        // 语音播报最重要的建议
        if let topAdvice = currentAdvices.first(where: { $0.priority > 0 }) {
            voiceCoach.speak(topAdvice.message)
        }
    }

    /// 根据场景生成完整拍摄方案
    func generateShootingPlan() -> ShootingPlan {
        let scene = sceneClassifier.currentScene
        let lightParams = lightAnalyzer.recommendParameters()
        let poses = PoseTemplate.recommendations(for: scene)

        let plan = ShootingPlan(
            scene: scene,
            cameraParameters: lightParams,
            recommendedComposition: compositionAnalyzer.selectedGuide,
            recommendedPoses: poses,
            creativeTips: scene.creativeTips
        )

        shootingPlan = plan
        return plan
    }
}
