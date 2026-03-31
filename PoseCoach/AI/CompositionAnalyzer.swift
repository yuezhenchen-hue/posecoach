import UIKit
import Vision

/// 构图分析器：分析构图质量，提供构图建议和引导线
@MainActor
class CompositionAnalyzer: ObservableObject {
    @Published var currentComposition: CompositionResult?
    @Published var selectedGuide: CompositionGuide = .ruleOfThirds

    enum CompositionGuide: String, CaseIterable, Identifiable {
        case ruleOfThirds = "三分法"
        case center = "中心对称"
        case goldenRatio = "黄金比例"
        case diagonal = "对角线"
        case none = "无参考线"

        var id: String { rawValue }
    }

    struct CompositionResult {
        let personPosition: CGPoint
        let personSize: CGFloat
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

    /// 根据人物位置和当前构图规则分析构图质量
    func analyze(personBoundingBox: CGRect, imageSize: CGSize) {
        let personCenter = CGPoint(
            x: personBoundingBox.midX,
            y: personBoundingBox.midY
        )
        let personRatio = personBoundingBox.height

        switch selectedGuide {
        case .ruleOfThirds:
            analyzeRuleOfThirds(personCenter: personCenter, personRatio: personRatio)
        case .center:
            analyzeCenter(personCenter: personCenter, personRatio: personRatio)
        case .goldenRatio:
            analyzeGoldenRatio(personCenter: personCenter, personRatio: personRatio)
        case .diagonal:
            analyzeDiagonal(personCenter: personCenter, personRatio: personRatio)
        case .none:
            currentComposition = nil
        }
    }

    // MARK: - Rule of Thirds

    private func analyzeRuleOfThirds(personCenter: CGPoint, personRatio: CGFloat) {
        let thirdPoints: [CGPoint] = [
            CGPoint(x: 1.0/3.0, y: 1.0/3.0),
            CGPoint(x: 2.0/3.0, y: 1.0/3.0),
            CGPoint(x: 1.0/3.0, y: 2.0/3.0),
            CGPoint(x: 2.0/3.0, y: 2.0/3.0)
        ]

        let closest = thirdPoints.min(by: {
            distance($0, personCenter) < distance($1, personCenter)
        })!

        let dist = distance(closest, personCenter)
        let score = max(0, Int(100 - dist * 200))

        var hint: MovementHint?
        var suggestion: String

        if dist < 0.08 {
            suggestion = "构图完美！人物在三分点上"
        } else {
            let dx = closest.x - personCenter.x
            let dy = closest.y - personCenter.y

            if abs(dx) > abs(dy) {
                let dir: MovementHint.Direction = dx > 0 ? .right : .left
                hint = MovementHint(direction: dir, description: "人物\(dir.rawValue)一点到三分线上")
                suggestion = "建议人物\(dir.rawValue)一点"
            } else {
                let dir: MovementHint.Direction = dy > 0 ? .lower : .higher
                hint = MovementHint(direction: dir, description: "\(dir.rawValue)以对齐三分线")
                suggestion = "建议\(dir.rawValue)"
            }
        }

        // 检查人物占比
        if personRatio < 0.3 {
            hint = MovementHint(direction: .closer, description: "人物太小，靠近一些")
            suggestion += "，人物偏小建议靠近"
        } else if personRatio > 0.85 {
            hint = MovementHint(direction: .farther, description: "人物太大，远一些")
            suggestion += "，人物过大建议后退"
        }

        currentComposition = CompositionResult(
            personPosition: personCenter,
            personSize: personRatio,
            suggestion: suggestion,
            score: score,
            movementHint: hint
        )
    }

    // MARK: - Center

    private func analyzeCenter(personCenter: CGPoint, personRatio: CGFloat) {
        let center = CGPoint(x: 0.5, y: 0.5)
        let dist = distance(center, personCenter)
        let score = max(0, Int(100 - dist * 200))

        var suggestion: String
        var hint: MovementHint?

        if dist < 0.08 {
            suggestion = "人物居中，构图对称"
        } else {
            let dx = center.x - personCenter.x
            let dir: MovementHint.Direction = dx > 0 ? .right : .left
            hint = MovementHint(direction: dir, description: "人物\(dir.rawValue)到画面中心")
            suggestion = "建议人物\(dir.rawValue)到中心位置"
        }

        currentComposition = CompositionResult(
            personPosition: personCenter,
            personSize: personRatio,
            suggestion: suggestion,
            score: score,
            movementHint: hint
        )
    }

    // MARK: - Golden Ratio

    private func analyzeGoldenRatio(personCenter: CGPoint, personRatio: CGFloat) {
        let phi: CGFloat = 0.618
        let goldenPoints: [CGPoint] = [
            CGPoint(x: phi, y: phi),
            CGPoint(x: 1 - phi, y: phi),
            CGPoint(x: phi, y: 1 - phi),
            CGPoint(x: 1 - phi, y: 1 - phi)
        ]

        let closest = goldenPoints.min(by: {
            distance($0, personCenter) < distance($1, personCenter)
        })!

        let dist = distance(closest, personCenter)
        let score = max(0, Int(100 - dist * 200))
        let suggestion = dist < 0.08 ? "黄金比例构图，非常和谐" : "试试把人物移到黄金分割点上"

        currentComposition = CompositionResult(
            personPosition: personCenter,
            personSize: personRatio,
            suggestion: suggestion,
            score: score,
            movementHint: nil
        )
    }

    // MARK: - Diagonal

    private func analyzeDiagonal(personCenter: CGPoint, personRatio: CGFloat) {
        let distToMainDiag = abs(personCenter.y - personCenter.x) / sqrt(2)
        let distToAntiDiag = abs(personCenter.y - (1 - personCenter.x)) / sqrt(2)
        let minDist = min(distToMainDiag, distToAntiDiag)
        let score = max(0, Int(100 - Double(minDist) * 300))
        let suggestion = minDist < 0.1 ? "人物在对角线上，构图有动感" : "试试让人物靠近对角线方向"

        currentComposition = CompositionResult(
            personPosition: personCenter,
            personSize: personRatio,
            suggestion: suggestion,
            score: score,
            movementHint: nil
        )
    }

    // MARK: - Helpers

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}
