import UIKit
import Vision

/// 构图分析器：基于通用主体（人/景/物）的构图协调性评分系统
@MainActor
class CompositionAnalyzer: ObservableObject {
    @Published var currentComposition: CompositionResult?
    @Published var selectedGuide: CompositionGuide = .ruleOfThirds
    @Published var harmonyScore: HarmonyScore?

    enum CompositionGuide: String, CaseIterable, Identifiable {
        case ruleOfThirds = "三分法"
        case center = "中心对称"
        case goldenRatio = "黄金比例"
        case diagonal = "对角线"
        case none = "无参考线"

        var id: String { rawValue }
    }

    struct CompositionResult {
        let subjectPosition: CGPoint
        let subjectSize: CGFloat
        let suggestion: String
        let score: Int
        let movementHint: MovementHint?
    }

    struct MovementHint {
        let direction: Direction
        let description: String

        enum Direction: String {
            case left = "向左移"
            case right = "向右移"
            case up = "向上移"
            case down = "向下移"
            case closer = "靠近一些"
            case farther = "远一些"
            case lower = "手机放低"
            case higher = "手机抬高"
        }
    }

    /// 构图协调性综合评分
    struct HarmonyScore {
        let total: Int
        let ruleAlignment: Int
        let balance: Int
        let headroom: Int
        let subjectProportion: Int
        let depthSense: Int
        let details: [HarmonyDetail]

        struct HarmonyDetail: Identifiable {
            let id = UUID()
            let name: String
            let score: Int
            let maxScore: Int
            let suggestion: String?
            let icon: String
        }

        var level: HarmonyLevel {
            switch total {
            case 85...: return .excellent
            case 70..<85: return .good
            case 50..<70: return .fair
            default: return .poor
            }
        }

        enum HarmonyLevel: String {
            case excellent = "非常协调"
            case good = "较协调"
            case fair = "一般"
            case poor = "需要调整"

            var color: String {
                switch self {
                case .excellent: return "green"
                case .good: return "blue"
                case .fair: return "orange"
                case .poor: return "red"
                }
            }
        }
    }

    // MARK: - Unified Analysis

    /// 基于通用主体的构图分析（主体可以是人、物、景）
    func analyze(subjectBox: CGRect, subjectType: SubjectDetector.SubjectType, saliencyRegions: [CGRect]) {
        let subjectCenter = CGPoint(x: subjectBox.midX, y: subjectBox.midY)
        let subjectArea = subjectBox.width * subjectBox.height

        switch selectedGuide {
        case .ruleOfThirds:
            analyzeRuleOfThirds(center: subjectCenter, area: subjectArea, subjectType: subjectType)
        case .center:
            analyzeCenter(center: subjectCenter, area: subjectArea, subjectType: subjectType)
        case .goldenRatio:
            analyzeGoldenRatio(center: subjectCenter, area: subjectArea, subjectType: subjectType)
        case .diagonal:
            analyzeDiagonal(center: subjectCenter, area: subjectArea, subjectType: subjectType)
        case .none:
            currentComposition = nil
        }

        evaluateHarmony(
            subjectBox: subjectBox,
            subjectType: subjectType,
            saliencyRegions: saliencyRegions
        )
    }

    /// 兼容旧接口
    func analyze(personBoundingBox: CGRect, imageSize: CGSize) {
        analyze(subjectBox: personBoundingBox, subjectType: .person, saliencyRegions: [])
    }

    // MARK: - Harmony Evaluation

    private func evaluateHarmony(
        subjectBox: CGRect,
        subjectType: SubjectDetector.SubjectType,
        saliencyRegions: [CGRect]
    ) {
        var details: [HarmonyScore.HarmonyDetail] = []
        let cx = subjectBox.midX
        let cy = subjectBox.midY
        let area = subjectBox.width * subjectBox.height

        // 1. 构图规则对齐 (0~25)
        let ruleScore = evaluateRuleAlignment(cx: cx, cy: cy)
        details.append(HarmonyScore.HarmonyDetail(
            name: "构图规则",
            score: ruleScore,
            maxScore: 25,
            suggestion: ruleScore < 15 ? "主体偏离\(selectedGuide.rawValue)参考点" : nil,
            icon: "squareshape.split.3x3"
        ))

        // 2. 画面平衡 (0~25)
        let balanceScore = evaluateBalance(subjectBox: subjectBox, saliencyRegions: saliencyRegions)
        details.append(HarmonyScore.HarmonyDetail(
            name: "画面平衡",
            score: balanceScore,
            maxScore: 25,
            suggestion: balanceScore < 15 ? "画面重心偏移，可调整主体位置" : nil,
            icon: "scale.3d"
        ))

        // 3. 留白空间 (0~20)
        let headroomScore = evaluateHeadroom(subjectBox: subjectBox, subjectType: subjectType)
        details.append(HarmonyScore.HarmonyDetail(
            name: "留白空间",
            score: headroomScore,
            maxScore: 20,
            suggestion: headroomScore < 10 ? "主体周围留白不均匀" : nil,
            icon: "rectangle.dashed"
        ))

        // 4. 主体占比 (0~15)
        let proportionScore = evaluateProportion(area: area, subjectType: subjectType)
        details.append(HarmonyScore.HarmonyDetail(
            name: "主体占比",
            score: proportionScore,
            maxScore: 15,
            suggestion: proportionScore < 8 ? (area < 0.05 ? "主体太小，靠近一些" : "主体太大，后退一步") : nil,
            icon: "aspectratio"
        ))

        // 5. 层次纵深感 (0~15)
        let depthScore = evaluateDepth(subjectBox: subjectBox, saliencyRegions: saliencyRegions)
        details.append(HarmonyScore.HarmonyDetail(
            name: "层次感",
            score: depthScore,
            maxScore: 15,
            suggestion: depthScore < 8 ? "画面缺少层次，可尝试换角度" : nil,
            icon: "square.3.layers.3d.down.left"
        ))

        let total = ruleScore + balanceScore + headroomScore + proportionScore + depthScore

        harmonyScore = HarmonyScore(
            total: total,
            ruleAlignment: ruleScore,
            balance: balanceScore,
            headroom: headroomScore,
            subjectProportion: proportionScore,
            depthSense: depthScore,
            details: details
        )
    }

    /// 规则对齐度 - 主体中心到最近构图参考点的距离
    private func evaluateRuleAlignment(cx: CGFloat, cy: CGFloat) -> Int {
        let referencePoints: [CGPoint]
        switch selectedGuide {
        case .ruleOfThirds:
            referencePoints = [
                CGPoint(x: 1.0/3, y: 1.0/3), CGPoint(x: 2.0/3, y: 1.0/3),
                CGPoint(x: 1.0/3, y: 2.0/3), CGPoint(x: 2.0/3, y: 2.0/3)
            ]
        case .center:
            referencePoints = [CGPoint(x: 0.5, y: 0.5)]
        case .goldenRatio:
            let phi: CGFloat = 0.618
            referencePoints = [
                CGPoint(x: phi, y: phi), CGPoint(x: 1 - phi, y: phi),
                CGPoint(x: phi, y: 1 - phi), CGPoint(x: 1 - phi, y: 1 - phi)
            ]
        case .diagonal:
            referencePoints = [
                CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.75),
                CGPoint(x: 0.25, y: 0.75), CGPoint(x: 0.75, y: 0.25)
            ]
        case .none:
            referencePoints = [CGPoint(x: 0.5, y: 0.5)]
        }

        let center = CGPoint(x: cx, y: cy)
        let minDist = referencePoints.map { distance($0, center) }.min() ?? 1.0
        return max(0, Int(25.0 * (1.0 - minDist * 2.5)))
    }

    /// 画面平衡度 - 视觉重心与画面中心的偏移
    private func evaluateBalance(subjectBox: CGRect, saliencyRegions: [CGRect]) -> Int {
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        var totalWeight: CGFloat = 0

        let subjectWeight = subjectBox.width * subjectBox.height
        weightedX += subjectBox.midX * subjectWeight
        weightedY += subjectBox.midY * subjectWeight
        totalWeight += subjectWeight

        for region in saliencyRegions {
            let w = region.width * region.height * 0.5
            weightedX += region.midX * w
            weightedY += region.midY * w
            totalWeight += w
        }

        guard totalWeight > 0 else { return 15 }

        let gravityX = weightedX / totalWeight
        let gravityY = weightedY / totalWeight
        let offsetFromCenter = distance(
            CGPoint(x: gravityX, y: gravityY),
            CGPoint(x: 0.5, y: 0.5)
        )

        return max(0, Int(25.0 * (1.0 - offsetFromCenter * 3.0)))
    }

    /// 留白空间 - 上下左右留白是否合理
    private func evaluateHeadroom(subjectBox: CGRect, subjectType: SubjectDetector.SubjectType) -> Int {
        let top = subjectBox.minY
        let bottom = 1.0 - subjectBox.maxY
        let left = subjectBox.minX
        let right = 1.0 - subjectBox.maxX

        var score = 20

        // 任何一侧贴边扣分
        if top < 0.03 { score -= 5 }
        if bottom < 0.03 { score -= 5 }
        if left < 0.03 { score -= 3 }
        if right < 0.03 { score -= 3 }

        // 人物拍照：头顶留空 5%~15% 最佳
        if subjectType == .person || subjectType == .multiplePeople {
            if top < 0.05 { score -= 4 }
            else if top > 0.25 { score -= 3 }
        }

        // 上下不对称太严重扣分
        let verticalImbalance = abs(top - bottom)
        if verticalImbalance > 0.3 { score -= 3 }

        return max(0, score)
    }

    /// 主体占比 - 主体在画面中的面积占比是否合适
    private func evaluateProportion(area: CGFloat, subjectType: SubjectDetector.SubjectType) -> Int {
        let idealRange: ClosedRange<CGFloat>
        switch subjectType {
        case .person, .multiplePeople:
            idealRange = 0.08...0.45
        case .object, .manualFocus:
            idealRange = 0.05...0.40
        case .scene:
            idealRange = 0.20...0.80
        case .none:
            return 5
        }

        if idealRange.contains(area) {
            return 15
        }

        let distFromRange: CGFloat
        if area < idealRange.lowerBound {
            distFromRange = idealRange.lowerBound - area
        } else {
            distFromRange = area - idealRange.upperBound
        }
        return max(0, Int(15.0 * (1.0 - distFromRange * 5.0)))
    }

    /// 层次纵深感 - 多个兴趣区域分布在不同位置增加层次
    private func evaluateDepth(subjectBox: CGRect, saliencyRegions: [CGRect]) -> Int {
        if saliencyRegions.count <= 1 { return 7 }

        var yPositions: Set<Int> = []
        yPositions.insert(Int(subjectBox.midY * 3))

        for region in saliencyRegions {
            yPositions.insert(Int(region.midY * 3))
        }

        switch yPositions.count {
        case 3...: return 15
        case 2: return 11
        default: return 7
        }
    }

    // MARK: - Rule-specific Analysis

    private func analyzeRuleOfThirds(center: CGPoint, area: CGFloat, subjectType: SubjectDetector.SubjectType) {
        let thirdPoints: [CGPoint] = [
            CGPoint(x: 1.0/3.0, y: 1.0/3.0), CGPoint(x: 2.0/3.0, y: 1.0/3.0),
            CGPoint(x: 1.0/3.0, y: 2.0/3.0), CGPoint(x: 2.0/3.0, y: 2.0/3.0)
        ]

        let closest = thirdPoints.min(by: { distance($0, center) < distance($1, center) })!
        let dist = distance(closest, center)
        let score = max(0, Int(100 - dist * 200))
        let subjectName = subjectType == .person ? "人物" : "主体"

        var hint: MovementHint?
        var suggestion: String

        if dist < 0.08 {
            suggestion = "构图完美！\(subjectName)在三分点上"
        } else {
            let dx = closest.x - center.x
            let dy = closest.y - center.y

            if abs(dx) > abs(dy) {
                let dir: MovementHint.Direction = dx > 0 ? .right : .left
                hint = MovementHint(direction: dir, description: "\(subjectName)\(dir.rawValue)到三分线")
                suggestion = "建议\(subjectName)\(dir.rawValue)"
            } else {
                let dir: MovementHint.Direction = dy > 0 ? .lower : .higher
                hint = MovementHint(direction: dir, description: "\(dir.rawValue)对齐三分线")
                suggestion = "建议\(dir.rawValue)"
            }
        }

        if area < 0.05 {
            hint = MovementHint(direction: .closer, description: "\(subjectName)太小，靠近一些")
            suggestion += "，\(subjectName)偏小建议靠近"
        } else if area > 0.6 {
            hint = MovementHint(direction: .farther, description: "\(subjectName)太大，远一些")
            suggestion += "，\(subjectName)过大建议后退"
        }

        currentComposition = CompositionResult(
            subjectPosition: center, subjectSize: area, suggestion: suggestion,
            score: score, movementHint: hint
        )
    }

    private func analyzeCenter(center: CGPoint, area: CGFloat, subjectType: SubjectDetector.SubjectType) {
        let mid = CGPoint(x: 0.5, y: 0.5)
        let dist = distance(mid, center)
        let score = max(0, Int(100 - dist * 200))
        let subjectName = subjectType == .person ? "人物" : "主体"

        var suggestion: String
        var hint: MovementHint?

        if dist < 0.08 {
            suggestion = "\(subjectName)居中，构图对称"
        } else {
            let dx = mid.x - center.x
            let dir: MovementHint.Direction = dx > 0 ? .right : .left
            hint = MovementHint(direction: dir, description: "\(subjectName)\(dir.rawValue)到画面中心")
            suggestion = "建议\(subjectName)\(dir.rawValue)到中心"
        }

        currentComposition = CompositionResult(
            subjectPosition: center, subjectSize: area, suggestion: suggestion,
            score: score, movementHint: hint
        )
    }

    private func analyzeGoldenRatio(center: CGPoint, area: CGFloat, subjectType: SubjectDetector.SubjectType) {
        let phi: CGFloat = 0.618
        let goldenPoints: [CGPoint] = [
            CGPoint(x: phi, y: phi), CGPoint(x: 1 - phi, y: phi),
            CGPoint(x: phi, y: 1 - phi), CGPoint(x: 1 - phi, y: 1 - phi)
        ]

        let closest = goldenPoints.min(by: { distance($0, center) < distance($1, center) })!
        let dist = distance(closest, center)
        let score = max(0, Int(100 - dist * 200))
        let subjectName = subjectType == .person ? "人物" : "主体"
        let suggestion = dist < 0.08 ? "黄金比例构图，非常和谐" : "试试把\(subjectName)移到黄金分割点"

        currentComposition = CompositionResult(
            subjectPosition: center, subjectSize: area, suggestion: suggestion,
            score: score, movementHint: nil
        )
    }

    private func analyzeDiagonal(center: CGPoint, area: CGFloat, subjectType: SubjectDetector.SubjectType) {
        let distToMainDiag = abs(center.y - center.x) / sqrt(2)
        let distToAntiDiag = abs(center.y - (1 - center.x)) / sqrt(2)
        let minDist = min(distToMainDiag, distToAntiDiag)
        let score = max(0, Int(100 - Double(minDist) * 300))
        let subjectName = subjectType == .person ? "人物" : "主体"
        let suggestion = minDist < 0.1 ? "\(subjectName)在对角线上，有动感" : "试试让\(subjectName)靠近对角线"

        currentComposition = CompositionResult(
            subjectPosition: center, subjectSize: area, suggestion: suggestion,
            score: score, movementHint: nil
        )
    }

    // MARK: - Helpers

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}
