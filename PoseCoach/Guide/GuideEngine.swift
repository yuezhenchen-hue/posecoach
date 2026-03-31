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
    let voiceCoach = VoiceCoach()

    private var frameCount: Int = 0

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

            var defaultIcon: String {
                switch self {
                case .scene: return "map.fill"
                case .light: return "sun.max.fill"
                case .composition: return "squareshape.split.3x3"
                case .pose: return "figure.stand"
                case .parameter: return "camera.aperture"
                case .creative: return "sparkles"
                case .phonePosition: return "iphone.gen3"
                case .subjectPosition: return "person.fill.viewfinder"
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

    /// 手机移动引导
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

    /// 处理每一帧视频数据
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1

        sceneClassifier.classify(sampleBuffer: sampleBuffer)
        lightAnalyzer.analyze(sampleBuffer: sampleBuffer)
        poseDetector.detect(sampleBuffer: sampleBuffer)

        let personBox = poseDetector.mainSubjectBox != .zero
            ? poseDetector.mainSubjectBox
            : poseDetector.personBoundingBox

        if personBox != .zero {
            compositionAnalyzer.analyze(
                personBoundingBox: personBox,
                imageSize: CGSize(width: 1, height: 1)
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

        if personBox != .zero {
            compositionAnalyzer.analyze(
                personBoundingBox: personBox,
                imageSize: CGSize(width: image.size.width, height: image.size.height)
            )
        } else if simulatedPersonBox != .zero {
            compositionAnalyzer.analyze(
                personBoundingBox: simulatedPersonBox,
                imageSize: CGSize(width: 1, height: 1)
            )
        }

        updateAdvices()
    }

    /// 综合所有分析结果，生成排序后的建议列表
    private func updateAdvices() {
        var advices: [GuideAdvice] = []
        var readyCount = 0
        let scene = sceneClassifier.currentScene

        // === 1. 主体检测状态 ===
        let personBox = poseDetector.mainSubjectBox != .zero
            ? poseDetector.mainSubjectBox
            : poseDetector.personBoundingBox
        let hasSubject = personBox != .zero

        if hasSubject {
            readyCount += 1
            let desc = poseDetector.mainSubjectDescription
            if !desc.isEmpty && desc != "未检测到人物" {
                advices.append(GuideAdvice(
                    category: .subjectPosition,
                    message: desc,
                    priority: 0,
                    direction: .stay,
                    icon: "person.fill.checkmark"
                ))
            }

            // === 2. 主体位置引导 ===
            let subjectAdvices = generateSubjectPositionAdvices(personBox: personBox)
            advices.append(contentsOf: subjectAdvices)

            // === 3. 手机移动引导 ===
            let phoneAdvices = generatePhoneMovementAdvices(personBox: personBox)
            advices.append(contentsOf: phoneAdvices)
            updatePhoneMovementGuide(personBox: personBox)

        } else {
            advices.append(GuideAdvice(
                category: .subjectPosition,
                message: "请将人物放入画面中",
                priority: 1,
                icon: "person.fill.questionmark"
            ))
        }

        // === 4. 场景 ===
        if scene != .unknown {
            readyCount += 1
        }

        // === 5. 光线建议 ===
        let lightParams = lightAnalyzer.recommendParameters()
        if let suggestion = lightParams.suggestion {
            advices.append(GuideAdvice(category: .light, message: suggestion, priority: 5))
        }
        if lightAnalyzer.lightCondition == .normal || lightAnalyzer.lightCondition == .bright {
            readyCount += 1
        }

        // === 6. 构图建议 ===
        if let composition = compositionAnalyzer.currentComposition {
            if composition.score > 70 {
                readyCount += 1
            }
        }

        // === 7. 姿态建议 ===
        if hasSubject {
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

        // === 8. 创意提示（低优先级）===
        if hasSubject && readyCount >= 3 {
            let tips = scene.creativeTips
            if let tip = tips.first {
                advices.append(GuideAdvice(
                    category: .creative,
                    message: tip,
                    priority: 10
                ))
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

    private func generateSubjectPositionAdvices(personBox: CGRect) -> [GuideAdvice] {
        var advices: [GuideAdvice] = []
        let cx = personBox.midX
        let cy = personBox.midY
        let personHeight = personBox.height

        // 人物在画面中的水平位置
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
                    advices.append(GuideAdvice(
                        category: .subjectPosition,
                        message: "让被拍的人往右走一步",
                        priority: 2,
                        direction: .right,
                        icon: "arrow.right.circle.fill"
                    ))
                } else if cx > 0.7 {
                    advices.append(GuideAdvice(
                        category: .subjectPosition,
                        message: "让被拍的人往左走一步",
                        priority: 2,
                        direction: .left,
                        icon: "arrow.left.circle.fill"
                    ))
                }
            }
        case .center:
            if abs(cx - 0.5) > 0.1 {
                let dir: GuideAdvice.Direction = cx < 0.5 ? .right : .left
                let dirText = cx < 0.5 ? "右" : "左"
                advices.append(GuideAdvice(
                    category: .subjectPosition,
                    message: "让被拍的人往\(dirText)走，到画面中心",
                    priority: 2,
                    direction: dir,
                    icon: dir == .left ? "arrow.left.circle.fill" : "arrow.right.circle.fill"
                ))
            }
        default:
            break
        }

        // 头顶留空检查
        if cy < 0.08 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "头顶快出画面了，手机往上抬一点",
                priority: 2,
                direction: .up,
                icon: "arrow.up.circle.fill"
            ))
        } else if cy > 0.15 && personHeight < 0.5 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "头顶空间太多，手机稍微往下一点",
                priority: 3,
                direction: .down,
                icon: "arrow.down.circle.fill"
            ))
        }

        // 脚底检查（站姿时）
        let bottom = personBox.maxY
        if bottom > 0.97 && personHeight > 0.5 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "脚快被截掉了，手机往下移或后退一步",
                priority: 2,
                direction: .down,
                icon: "arrow.down.circle.fill"
            ))
        }

        return advices
    }

    // MARK: - Phone Movement Advices

    private func generatePhoneMovementAdvices(personBox: CGRect) -> [GuideAdvice] {
        var advices: [GuideAdvice] = []
        let personHeight = personBox.height

        // 距离引导
        if personHeight < 0.2 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "人太小了，往前走近两步",
                priority: 2,
                direction: .forward,
                icon: "figure.walk.arrival"
            ))
        } else if personHeight > 0.85 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "人太近了，后退一步拍全身",
                priority: 2,
                direction: .backward,
                icon: "figure.walk.departure"
            ))
        } else if personHeight > 0.6 && personHeight <= 0.85 {
            advices.append(GuideAdvice(
                category: .phonePosition,
                message: "半身照距离，再退一步可拍全身",
                priority: 4,
                direction: .backward,
                icon: "arrow.down.backward.circle"
            ))
        }

        // 角度引导（基于人物上半身和下半身比例）
        if let pose = poseDetector.detectedPose {
            if let nose = pose.joints[.nose], let leftAnkle = pose.joints[.leftAnkle] {
                let headToFeetRatio = nose.y / max(leftAnkle.y, 0.01)
                if headToFeetRatio < 0.25 {
                    advices.append(GuideAdvice(
                        category: .phonePosition,
                        message: "手机角度太低，抬高到平视位置",
                        priority: 3,
                        direction: .up,
                        icon: "iphone.gen3.radiowaves.left.and.right"
                    ))
                } else if headToFeetRatio > 0.6 {
                    advices.append(GuideAdvice(
                        category: .phonePosition,
                        message: "手机太高了，稍微放低一些",
                        priority: 3,
                        direction: .down,
                        icon: "iphone.gen3.radiowaves.left.and.right"
                    ))
                }
            }
        }

        // 水平倾斜检测
        if let pose = poseDetector.detectedPose,
           let leftShoulder = pose.joints[.leftShoulder],
           let rightShoulder = pose.joints[.rightShoulder] {
            let tiltAngle = abs(leftShoulder.y - rightShoulder.y)
            if tiltAngle > 0.04 {
                let direction: GuideAdvice.Direction = leftShoulder.y > rightShoulder.y ? .rotateRight : .rotateLeft
                advices.append(GuideAdvice(
                    category: .phonePosition,
                    message: "手机有点歪，保持水平",
                    priority: 2,
                    direction: direction,
                    icon: "level.fill"
                ))
            }
        }

        return advices
    }

    private func updatePhoneMovementGuide(personBox: CGRect) {
        let cx = personBox.midX
        let cy = personBox.midY
        let personHeight = personBox.height

        let horizontal: PhoneMovementGuide.HorizontalMove
        if cx < 0.3 {
            horizontal = .moveRight
        } else if cx > 0.7 {
            horizontal = .moveLeft
        } else {
            horizontal = .good
        }

        let vertical: PhoneMovementGuide.VerticalMove
        if cy < 0.08 {
            vertical = .moveUp
        } else if cy > 0.15 && personHeight < 0.5 {
            vertical = .moveDown
        } else {
            vertical = .good
        }

        let distance: PhoneMovementGuide.DistanceMove
        if personHeight < 0.2 {
            distance = .closer
        } else if personHeight > 0.85 {
            distance = .farther
        } else {
            distance = .good
        }

        var rotation: String?
        if let pose = poseDetector.detectedPose,
           let ls = pose.joints[.leftShoulder], let rs = pose.joints[.rightShoulder] {
            if abs(ls.y - rs.y) > 0.04 {
                rotation = "手机有点歪"
            }
        }

        phoneMovement = PhoneMovementGuide(
            horizontal: horizontal,
            vertical: vertical,
            distance: distance,
            rotation: rotation
        )
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
