import Foundation
import Combine
import AVFoundation
import UIKit

/// 引导引擎：协调所有 AI 模块，生成综合拍摄建议
@MainActor
class GuideEngine: ObservableObject {
    @Published var shootingPlan: ShootingPlan?
    @Published var currentAdvices: [GuideAdvice] = []
    @Published var overallReadiness: ReadinessLevel = .notReady
    @Published var phoneMovement: PhoneMovementGuide?

    let sceneClassifier = SceneClassifier()
    let lightAnalyzer = LightAnalyzer()
    let poseDetector = PoseDetector()
    let compositionAnalyzer = CompositionAnalyzer()
    let subjectDetector = SubjectDetector()
    let voiceCoach = VoiceCoach()

    private var frameCount: Int = 0
    private var isProcessing = false

    enum ReadinessLevel: String {
        case notReady = "准备中..."
        case almostReady = "快好了"
        case ready = "可以拍了！"
        case perfect = "完美！快按快门！"
    }

    struct GuideAdvice: Identifiable {
        let id = UUID()
        let category: Category
        let message: String
        let priority: Int
        let direction: Direction?
        let icon: String

        init(category: Category, message: String, priority: Int, direction: Direction? = nil, icon: String? = nil) {
            self.category = category
            self.message = message
            self.priority = priority
            self.direction = direction
            self.icon = icon ?? category.defaultIcon
        }

        enum Category: String {
            case scene = "场景"
            case light = "光线"
            case composition = "构图"
            case pose = "姿态"
            case parameter = "参数"
            case creative = "创意"
            case phonePosition = "手机"
            case subjectPosition = "主体"
            case harmony = "协调"

            var defaultIcon: String {
                switch self {
                case .scene: return "map.fill"
                case .light: return "sun.max.fill"
                case .composition: return "squareshape.split.3x3"
                case .pose: return "figure.stand"
                case .parameter: return "camera.aperture"
                case .creative: return "sparkles"
                case .phonePosition: return "iphone.gen3"
                case .subjectPosition: return "viewfinder"
                case .harmony: return "dial.medium.fill"
                }
            }
        }

        enum Direction: String {
            case left = "←"
            case right = "→"
            case up = "↑"
            case down = "↓"
            case forward = "↗"
            case backward = "↙"
            case rotateLeft = "↺"
            case rotateRight = "↻"
            case stay = "✓"
        }
    }

    struct PhoneMovementGuide {
        let horizontal: HorizontalMove
        let vertical: VerticalMove
        let distance: DistanceMove
        let rotation: String?

        enum HorizontalMove: String {
            case moveLeft = "向左移动"
            case moveRight = "向右移动"
            case good = "左右位置OK"
        }
        enum VerticalMove: String {
            case moveUp = "抬高手机"
            case moveDown = "放低手机"
            case good = "高低位置OK"
        }
        enum DistanceMove: String {
            case closer = "靠近一点"
            case farther = "后退一步"
            case good = "距离OK"
        }
    }

    /// 用户点击画面手动指定主体
    func setManualSubject(normalizedPoint: CGPoint) {
        subjectDetector.setManualFocus(normalizedPoint: normalizedPoint)
        let box = subjectDetector.subjectBox
        if box != .zero {
            compositionAnalyzer.analyze(
                subjectBox: box,
                subjectType: subjectDetector.subjectType,
                saliencyRegions: subjectDetector.saliencyHeatmap
            )
            updateAdvices()
        }
    }

    func clearManualSubject() {
        subjectDetector.clearManualFocus()
    }

    /// 处理每一帧视频数据
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        guard !isProcessing else { return }
        guard frameCount % 2 == 0 else { return }
        isProcessing = true
        defer { isProcessing = false }

        sceneClassifier.classify(sampleBuffer: sampleBuffer)
        lightAnalyzer.analyze(sampleBuffer: sampleBuffer)
        poseDetector.detect(sampleBuffer: sampleBuffer)

        let personBox = poseDetector.mainSubjectBox != .zero
            ? poseDetector.mainSubjectBox
            : poseDetector.personBoundingBox

        subjectDetector.detect(
            sampleBuffer: sampleBuffer,
            personBox: personBox,
            personCount: poseDetector.personCount
        )

        let finalBox = subjectDetector.subjectBox
        if finalBox != .zero {
            compositionAnalyzer.analyze(
                subjectBox: finalBox,
                subjectType: subjectDetector.subjectType,
                saliencyRegions: subjectDetector.saliencyHeatmap
            )
        }

        updateAdvices()
    }

    /// Demo 模式：处理静态图片
    func processImage(_ image: UIImage, simulatedPersonBox: CGRect) {
        _ = sceneClassifier.classify(image: image)
        lightAnalyzer.analyze(image: image)
        poseDetector.detect(image: image)

        let personBox = poseDetector.mainSubjectBox != .zero
            ? poseDetector.mainSubjectBox
            : poseDetector.personBoundingBox

        subjectDetector.detect(image: image, personBox: personBox, personCount: poseDetector.personCount)

        let finalBox = subjectDetector.subjectBox != .zero
            ? subjectDetector.subjectBox
            : simulatedPersonBox

        if finalBox != .zero {
            compositionAnalyzer.analyze(
                subjectBox: finalBox,
                subjectType: subjectDetector.subjectType,
                saliencyRegions: subjectDetector.saliencyHeatmap
            )
        }

        updateAdvices()
    }

    // MARK: - Advice Generation

    private func updateAdvices() {
        var advices: [GuideAdvice] = []
        var readyCount = 0
        let scene = sceneClassifier.currentScene

        let subjectBox = subjectDetector.subjectBox
        let subjectType = subjectDetector.subjectType
        let hasSubject = subjectBox != .zero && subjectType != .none

        // === 1. 主体状态 ===
        if hasSubject {
            readyCount += 1
            let desc = subjectDetector.subjectDescription
            if !desc.isEmpty {
                advices.append(GuideAdvice(
                    category: .subjectPosition,
                    message: desc,
                    priority: 0,
                    direction: .stay,
                    icon: subjectType.icon
                ))
            }

            // === 2. 主体位置引导 ===
            let positionAdvices = generateSubjectPositionAdvices(
                subjectBox: subjectBox, subjectType: subjectType
            )
            advices.append(contentsOf: positionAdvices)

            // === 3. 手机移动引导 ===
            let phoneAdvices = generatePhoneMovementAdvices(
                subjectBox: subjectBox, subjectType: subjectType
            )
            advices.append(contentsOf: phoneAdvices)
            updatePhoneMovementGuide(subjectBox: subjectBox)
        } else {
            advices.append(GuideAdvice(
                category: .subjectPosition,
                message: "点击画面选择主体，或对准拍摄对象",
                priority: 1,
                icon: "hand.tap.fill"
            ))
        }

        // === 4. 协调性评分 ===
        if let harmony = compositionAnalyzer.harmonyScore {
            readyCount += harmony.level == .excellent || harmony.level == .good ? 1 : 0

            for detail in harmony.details {
                if let suggestion = detail.suggestion {
                    advices.append(GuideAdvice(
                        category: .harmony,
                        message: suggestion,
                        priority: 3,
                        icon: detail.icon
                    ))
                }
            }
        }

        // === 5. 场景 ===
        if scene != .unknown {
            readyCount += 1
        }

        // === 6. 光线建议 ===
        let lightParams = lightAnalyzer.recommendParameters()
        if let suggestion = lightParams.suggestion {
            advices.append(GuideAdvice(category: .light, message: suggestion, priority: 5))
        }
        if lightAnalyzer.lightCondition == .normal || lightAnalyzer.lightCondition == .bright {
            readyCount += 1
        }

        // === 7. 构图建议 ===
        if let composition = compositionAnalyzer.currentComposition {
            if composition.score > 70 { readyCount += 1 }
        }

        // === 8. 姿态建议（仅当主体是人物时）===
        if subjectType == .person || subjectType == .multiplePeople {
            let poseAdvices = poseDetector.evaluatePose(for: scene)
            for advice in poseAdvices {
                if advice.type == .good {
                    readyCount += 1
                } else {
                    advices.append(GuideAdvice(
                        category: .pose,
                        message: advice.message,
                        priority: 6,
                        icon: advice.icon
                    ))
                }
            }
        }

        // === 9. 创意提示 ===
        if hasSubject && readyCount >= 3 {
            if let tip = scene.creativeTips.first {
                advices.append(GuideAdvice(category: .creative, message: tip, priority: 10))
            }
        }

        currentAdvices = advices.sorted { $0.priority < $1.priority }

        switch readyCount {
        case 0...1: overallReadiness = .notReady
        case 2: overallReadiness = .almostReady
        case 3: overallReadiness = .ready
        default: overallReadiness = .perfect
        }

        if let topAdvice = currentAdvices.first(where: { $0.priority >= 1 && $0.priority <= 4 }) {
            voiceCoach.speak(topAdvice.message)
        }
    }

    // MARK: - Subject Position Advices

    private func generateSubjectPositionAdvices(
        subjectBox: CGRect,
        subjectType: SubjectDetector.SubjectType
    ) -> [GuideAdvice] {
        var advices: [GuideAdvice] = []
        let cx = subjectBox.midX
        let cy = subjectBox.midY
        let isPerson = subjectType == .person || subjectType == .multiplePeople
        let subjectName = isPerson ? "被拍的人" : "主体"

        let guide = compositionAnalyzer.selectedGuide
        switch guide {
        case .ruleOfThirds:
            let leftThird: CGFloat = 1.0 / 3.0
            let rightThird: CGFloat = 2.0 / 3.0
            let distLeft = abs(cx - leftThird)
            let distRight = abs(cx - rightThird)
            let distCenter = abs(cx - 0.5)

            if distLeft > 0.08 && distRight > 0.08 && distCenter > 0.08 {
                if cx < 0.3 {
                    let msg = isPerson ? "让\(subjectName)往右走一步" : "手机向左移，让\(subjectName)到三分线"
                    advices.append(GuideAdvice(
                        category: .subjectPosition, message: msg, priority: 2,
                        direction: isPerson ? .right : .left, icon: "arrow.right.circle.fill"
                    ))
                } else if cx > 0.7 {
                    let msg = isPerson ? "让\(subjectName)往左走一步" : "手机向右移，让\(subjectName)到三分线"
                    advices.append(GuideAdvice(
                        category: .subjectPosition, message: msg, priority: 2,
                        direction: isPerson ? .left : .right, icon: "arrow.left.circle.fill"
                    ))
                }
            }
        case .center:
            if abs(cx - 0.5) > 0.1 {
                let dir: GuideAdvice.Direction = cx < 0.5 ? .right : .left
                let dirText = cx < 0.5 ? "右" : "左"
                let msg = isPerson ? "让\(subjectName)往\(dirText)走到中心" : "手机往\(dirText)移，让\(subjectName)居中"
                advices.append(GuideAdvice(
                    category: .subjectPosition, message: msg, priority: 2,
                    direction: dir, icon: dir == .left ? "arrow.left.circle.fill" : "arrow.right.circle.fill"
                ))
            }
        default:
            break
        }

        // 边缘检查
        if cy < 0.05 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "\(subjectName)快出画面顶部了，手机往上抬",
                priority: 2, direction: .up, icon: "arrow.up.circle.fill"
            ))
        }
        if subjectBox.maxY > 0.97 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "\(subjectName)快出画面底部了，手机往下移",
                priority: 2, direction: .down, icon: "arrow.down.circle.fill"
            ))
        }

        return advices
    }

    // MARK: - Phone Movement Advices

    private func generatePhoneMovementAdvices(
        subjectBox: CGRect,
        subjectType: SubjectDetector.SubjectType
    ) -> [GuideAdvice] {
        var advices: [GuideAdvice] = []
        let area = subjectBox.width * subjectBox.height
        let isPerson = subjectType == .person || subjectType == .multiplePeople

        let idealMin: CGFloat = isPerson ? 0.08 : 0.04
        let idealMax: CGFloat = isPerson ? 0.55 : 0.50

        if area < idealMin {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "主体太小，往前靠近一些",
                priority: 2, direction: .forward, icon: "figure.walk.arrival"
            ))
        } else if area > idealMax {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "主体太大太近了，后退一步",
                priority: 2, direction: .backward, icon: "figure.walk.departure"
            ))
        }

        // 人物特有：角度和倾斜检测
        if isPerson {
            if let pose = poseDetector.detectedPose {
                if let nose = pose.joints[.nose], let leftAnkle = pose.joints[.leftAnkle] {
                    let ratio = nose.y / max(leftAnkle.y, 0.01)
                    if ratio < 0.25 {
                        advices.append(GuideAdvice(
                            category: .phonePosition,
                            message: "手机角度太低，抬高到平视",
                            priority: 3, direction: .up, icon: "iphone.gen3.radiowaves.left.and.right"
                        ))
                    } else if ratio > 0.6 {
                        advices.append(GuideAdvice(
                            category: .phonePosition,
                            message: "手机太高了，稍微放低",
                            priority: 3, direction: .down, icon: "iphone.gen3.radiowaves.left.and.right"
                        ))
                    }
                }

                if let ls = pose.joints[.leftShoulder], let rs = pose.joints[.rightShoulder] {
                    if abs(ls.y - rs.y) > 0.04 {
                        let dir: GuideAdvice.Direction = ls.y > rs.y ? .rotateRight : .rotateLeft
                        advices.append(GuideAdvice(
                            category: .phonePosition,
                            message: "手机有点歪，保持水平",
                            priority: 2, direction: dir, icon: "level.fill"
                        ))
                    }
                }
            }
        }

        return advices
    }

    private func updatePhoneMovementGuide(subjectBox: CGRect) {
        let cx = subjectBox.midX
        let cy = subjectBox.midY
        let area = subjectBox.width * subjectBox.height

        let horizontal: PhoneMovementGuide.HorizontalMove
        if cx < 0.3 { horizontal = .moveRight }
        else if cx > 0.7 { horizontal = .moveLeft }
        else { horizontal = .good }

        let vertical: PhoneMovementGuide.VerticalMove
        if cy < 0.05 { vertical = .moveUp }
        else if subjectBox.maxY > 0.95 { vertical = .moveDown }
        else { vertical = .good }

        let distance: PhoneMovementGuide.DistanceMove
        if area < 0.04 { distance = .closer }
        else if area > 0.55 { distance = .farther }
        else { distance = .good }

        var rotation: String?
        if let pose = poseDetector.detectedPose,
           let ls = pose.joints[.leftShoulder], let rs = pose.joints[.rightShoulder] {
            if abs(ls.y - rs.y) > 0.04 { rotation = "手机有点歪" }
        }

        phoneMovement = PhoneMovementGuide(
            horizontal: horizontal, vertical: vertical,
            distance: distance, rotation: rotation
        )
    }

    /// 生成拍摄方案
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
