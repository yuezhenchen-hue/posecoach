import SwiftUI

/// 构图参考线覆层：绘制三分线、黄金比例等构图辅助线
struct CompositionOverlay: View {
    let guide: CompositionAnalyzer.CompositionGuide

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, size in
                let style = StrokeStyle(lineWidth: 0.8, dash: [6, 4])
                let color = Color.white.opacity(0.5)

                switch guide {
                case .ruleOfThirds:
                    drawRuleOfThirds(context: context, w: w, h: h, style: style, color: color)
                case .center:
                    drawCenter(context: context, w: w, h: h, style: style, color: color)
                case .goldenRatio:
                    drawGoldenRatio(context: context, w: w, h: h, style: style, color: color)
                case .diagonal:
                    drawDiagonal(context: context, w: w, h: h, style: style, color: color)
                case .none:
                    break
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawRuleOfThirds(context: GraphicsContext, w: CGFloat, h: CGFloat, style: StrokeStyle, color: Color) {
        for i in 1...2 {
            let x = w * CGFloat(i) / 3
            var vPath = Path()
            vPath.move(to: CGPoint(x: x, y: 0))
            vPath.addLine(to: CGPoint(x: x, y: h))
            context.stroke(vPath, with: .color(color), style: style)

            let y = h * CGFloat(i) / 3
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: y))
            hPath.addLine(to: CGPoint(x: w, y: y))
            context.stroke(hPath, with: .color(color), style: style)
        }

        // 四个交叉点
        for xi in 1...2 {
            for yi in 1...2 {
                let point = CGPoint(x: w * CGFloat(xi) / 3, y: h * CGFloat(yi) / 3)
                let dotRect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dotRect), with: .color(.orange.opacity(0.8)))
            }
        }
    }

    private func drawCenter(context: GraphicsContext, w: CGFloat, h: CGFloat, style: StrokeStyle, color: Color) {
        var vPath = Path()
        vPath.move(to: CGPoint(x: w / 2, y: 0))
        vPath.addLine(to: CGPoint(x: w / 2, y: h))
        context.stroke(vPath, with: .color(color), style: style)

        var hPath = Path()
        hPath.move(to: CGPoint(x: 0, y: h / 2))
        hPath.addLine(to: CGPoint(x: w, y: h / 2))
        context.stroke(hPath, with: .color(color), style: style)

        let center = CGPoint(x: w / 2, y: h / 2)
        let crossSize: CGFloat = 12
        context.fill(Path(ellipseIn: CGRect(x: center.x - crossSize/2, y: center.y - crossSize/2, width: crossSize, height: crossSize)), with: .color(.orange.opacity(0.6)))
    }

    private func drawGoldenRatio(context: GraphicsContext, w: CGFloat, h: CGFloat, style: StrokeStyle, color: Color) {
        let phi: CGFloat = 0.618
        let positions: [CGFloat] = [phi, 1 - phi]

        for p in positions {
            var vPath = Path()
            vPath.move(to: CGPoint(x: w * p, y: 0))
            vPath.addLine(to: CGPoint(x: w * p, y: h))
            context.stroke(vPath, with: .color(color), style: style)

            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: h * p))
            hPath.addLine(to: CGPoint(x: w, y: h * p))
            context.stroke(hPath, with: .color(color), style: style)
        }
    }

    private func drawDiagonal(context: GraphicsContext, w: CGFloat, h: CGFloat, style: StrokeStyle, color: Color) {
        var path1 = Path()
        path1.move(to: .zero)
        path1.addLine(to: CGPoint(x: w, y: h))
        context.stroke(path1, with: .color(color), style: style)

        var path2 = Path()
        path2.move(to: CGPoint(x: w, y: 0))
        path2.addLine(to: CGPoint(x: 0, y: h))
        context.stroke(path2, with: .color(color), style: style)
    }
}
