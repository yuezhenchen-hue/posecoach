import UIKit
import CoreGraphics

/// Demo 模式图片生成器：用 Core Graphics 绘制不同场景的模拟图片
@MainActor
class DemoImageProvider: ObservableObject {
    @Published var currentScenarioIndex: Int = 0

    let scenarios: [DemoScenario] = DemoScenario.allScenarios

    var currentScenario: DemoScenario {
        scenarios[currentScenarioIndex]
    }

    func nextScenario() {
        currentScenarioIndex = (currentScenarioIndex + 1) % scenarios.count
    }

    func previousScenario() {
        currentScenarioIndex = (currentScenarioIndex - 1 + scenarios.count) % scenarios.count
    }
}

struct DemoScenario: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let image: UIImage
    let simulatedPersonBox: CGRect

    static let allScenarios: [DemoScenario] = [
        DemoScenario(
            name: "户外公园",
            description: "阳光明媚的公园场景，适合练习自然光拍摄",
            icon: "tree.fill",
            image: generateOutdoorParkImage(),
            simulatedPersonBox: CGRect(x: 0.3, y: 0.2, width: 0.25, height: 0.6)
        ),
        DemoScenario(
            name: "海滩日落",
            description: "温暖色调的海滩逆光场景",
            icon: "sun.and.horizon.fill",
            image: generateBeachSunsetImage(),
            simulatedPersonBox: CGRect(x: 0.35, y: 0.25, width: 0.2, height: 0.55)
        ),
        DemoScenario(
            name: "城市街道",
            description: "都市建筑背景，练习构图和引导线",
            icon: "building.2.fill",
            image: generateCityStreetImage(),
            simulatedPersonBox: CGRect(x: 0.25, y: 0.15, width: 0.3, height: 0.65)
        ),
        DemoScenario(
            name: "室内暖光",
            description: "室内暖色灯光环境，适合练习低光拍摄",
            icon: "lamp.desk.fill",
            image: generateIndoorWarmImage(),
            simulatedPersonBox: CGRect(x: 0.3, y: 0.2, width: 0.25, height: 0.6)
        ),
        DemoScenario(
            name: "夜景",
            description: "城市夜景，挑战低光和长曝光",
            icon: "moon.stars.fill",
            image: generateNightSceneImage(),
            simulatedPersonBox: CGRect(x: 0.35, y: 0.3, width: 0.2, height: 0.5)
        ),
    ]
}

// MARK: - Image Generation

private func generateOutdoorParkImage() -> UIImage {
    let size = CGSize(width: 400, height: 600)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let c = ctx.cgContext

        // Sky gradient
        drawGradient(in: c, rect: CGRect(x: 0, y: 0, width: 400, height: 350),
                     colors: [UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0),
                              UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1.0)])

        // Sun
        c.setFillColor(UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 0.9).cgColor)
        c.fillEllipse(in: CGRect(x: 300, y: 50, width: 60, height: 60))

        // Grass
        drawGradient(in: c, rect: CGRect(x: 0, y: 320, width: 400, height: 280),
                     colors: [UIColor(red: 0.3, green: 0.7, blue: 0.2, alpha: 1.0),
                              UIColor(red: 0.2, green: 0.55, blue: 0.15, alpha: 1.0)])

        // Trees
        drawTree(in: c, x: 50, y: 220, size: 80)
        drawTree(in: c, x: 330, y: 240, size: 65)

        // Person silhouette
        drawPersonSilhouette(in: c, x: 170, y: 200, height: 220, color: .darkGray)

        // Path
        c.setFillColor(UIColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 0.6).cgColor)
        c.move(to: CGPoint(x: 150, y: 600))
        c.addLine(to: CGPoint(x: 250, y: 600))
        c.addLine(to: CGPoint(x: 210, y: 380))
        c.addLine(to: CGPoint(x: 190, y: 380))
        c.closePath()
        c.fillPath()
    }
}

private func generateBeachSunsetImage() -> UIImage {
    let size = CGSize(width: 400, height: 600)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let c = ctx.cgContext

        // Sunset sky
        drawGradient(in: c, rect: CGRect(x: 0, y: 0, width: 400, height: 380),
                     colors: [UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0),
                              UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),
                              UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)])

        // Sun on horizon
        c.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.95).cgColor)
        c.fillEllipse(in: CGRect(x: 160, y: 260, width: 80, height: 80))

        // Sea
        drawGradient(in: c, rect: CGRect(x: 0, y: 340, width: 400, height: 100),
                     colors: [UIColor(red: 0.15, green: 0.35, blue: 0.6, alpha: 1.0),
                              UIColor(red: 0.2, green: 0.45, blue: 0.7, alpha: 1.0)])

        // Sand
        drawGradient(in: c, rect: CGRect(x: 0, y: 430, width: 400, height: 170),
                     colors: [UIColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 1.0),
                              UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)])

        // Person silhouette (backlit - dark)
        drawPersonSilhouette(in: c, x: 180, y: 230, height: 200, color: UIColor(white: 0.1, alpha: 0.85))

        // Sun reflection on water
        c.setFillColor(UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 0.3).cgColor)
        c.fill(CGRect(x: 175, y: 340, width: 50, height: 90))
    }
}

private func generateCityStreetImage() -> UIImage {
    let size = CGSize(width: 400, height: 600)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let c = ctx.cgContext

        // Sky
        drawGradient(in: c, rect: CGRect(x: 0, y: 0, width: 400, height: 300),
                     colors: [UIColor(red: 0.5, green: 0.65, blue: 0.85, alpha: 1.0),
                              UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1.0)])

        // Buildings left
        c.setFillColor(UIColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 0, y: 80, width: 100, height: 520))
        c.setFillColor(UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 100, y: 140, width: 60, height: 460))

        // Buildings right
        c.setFillColor(UIColor(red: 0.4, green: 0.42, blue: 0.48, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 280, y: 60, width: 120, height: 540))
        c.setFillColor(UIColor(red: 0.48, green: 0.48, blue: 0.52, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 250, y: 160, width: 40, height: 440))

        // Windows
        c.setFillColor(UIColor(red: 0.8, green: 0.85, blue: 0.95, alpha: 0.6).cgColor)
        for row in stride(from: 100, to: 500, by: 40) {
            for col in [15, 45, 75] {
                c.fill(CGRect(x: col, y: row, width: 18, height: 25))
            }
            for col in [295, 335, 375] {
                c.fill(CGRect(x: col, y: row, width: 18, height: 25))
            }
        }

        // Road
        c.setFillColor(UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 130, y: 300, width: 150, height: 300))

        // Sidewalks
        c.setFillColor(UIColor(red: 0.65, green: 0.65, blue: 0.68, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 110, y: 300, width: 25, height: 300))
        c.fill(CGRect(x: 275, y: 300, width: 25, height: 300))

        // Person
        drawPersonSilhouette(in: c, x: 165, y: 250, height: 200, color: UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.9))
    }
}

private func generateIndoorWarmImage() -> UIImage {
    let size = CGSize(width: 400, height: 600)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let c = ctx.cgContext

        // Warm indoor background
        drawGradient(in: c, rect: CGRect(x: 0, y: 0, width: 400, height: 600),
                     colors: [UIColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 1.0),
                              UIColor(red: 0.55, green: 0.4, blue: 0.25, alpha: 1.0)])

        // Wall
        c.setFillColor(UIColor(red: 0.85, green: 0.78, blue: 0.65, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 0, y: 0, width: 400, height: 400))

        // Floor
        c.setFillColor(UIColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 0, y: 400, width: 400, height: 200))

        // Warm light glow
        c.setFillColor(UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0.15).cgColor)
        c.fillEllipse(in: CGRect(x: 100, y: 20, width: 200, height: 200))

        // Lamp
        c.setFillColor(UIColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 192, y: 0, width: 6, height: 60))
        c.setFillColor(UIColor(red: 1.0, green: 0.9, blue: 0.65, alpha: 0.9).cgColor)
        c.fillEllipse(in: CGRect(x: 170, y: 50, width: 50, height: 35))

        // Window (right side)
        c.setFillColor(UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.4).cgColor)
        c.fill(CGRect(x: 300, y: 60, width: 70, height: 120))
        c.setStrokeColor(UIColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 1.0).cgColor)
        c.setLineWidth(3)
        c.stroke(CGRect(x: 300, y: 60, width: 70, height: 120))

        // Person
        drawPersonSilhouette(in: c, x: 155, y: 180, height: 230, color: UIColor(red: 0.4, green: 0.35, blue: 0.28, alpha: 0.85))

        // Couch
        c.setFillColor(UIColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 0.7).cgColor)
        let couchPath = UIBezierPath(roundedRect: CGRect(x: 20, y: 350, width: 120, height: 70), cornerRadius: 10)
        c.addPath(couchPath.cgPath)
        c.fillPath()
    }
}

private func generateNightSceneImage() -> UIImage {
    let size = CGSize(width: 400, height: 600)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let c = ctx.cgContext

        // Dark sky
        drawGradient(in: c, rect: CGRect(x: 0, y: 0, width: 400, height: 600),
                     colors: [UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0),
                              UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)])

        // Stars
        c.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        for _ in 0..<30 {
            let x = CGFloat.random(in: 0...400)
            let y = CGFloat.random(in: 0...250)
            let size = CGFloat.random(in: 1...3)
            c.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }

        // Moon
        c.setFillColor(UIColor(red: 0.95, green: 0.95, blue: 0.85, alpha: 0.9).cgColor)
        c.fillEllipse(in: CGRect(x: 310, y: 40, width: 50, height: 50))

        // City skyline
        c.setFillColor(UIColor(red: 0.12, green: 0.12, blue: 0.2, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 0, y: 280, width: 80, height: 320))
        c.fill(CGRect(x: 70, y: 250, width: 60, height: 350))
        c.fill(CGRect(x: 140, y: 300, width: 50, height: 300))
        c.fill(CGRect(x: 220, y: 260, width: 70, height: 340))
        c.fill(CGRect(x: 310, y: 290, width: 90, height: 310))

        // Lit windows
        c.setFillColor(UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.7).cgColor)
        for building in [(10, 300, 60), (80, 270, 45), (230, 280, 55), (320, 310, 70)] {
            for row in stride(from: building.1, to: 580, by: 30) {
                for col in stride(from: building.0, to: building.0 + building.2, by: 18) {
                    if Bool.random() {
                        c.fill(CGRect(x: col, y: row, width: 10, height: 15))
                    }
                }
            }
        }

        // Street lights glow
        c.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 0.2).cgColor)
        c.fillEllipse(in: CGRect(x: 80, y: 430, width: 60, height: 60))
        c.fillEllipse(in: CGRect(x: 280, y: 440, width: 50, height: 50))

        // Ground
        c.setFillColor(UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor)
        c.fill(CGRect(x: 0, y: 500, width: 400, height: 100))

        // Person
        drawPersonSilhouette(in: c, x: 170, y: 310, height: 190, color: UIColor(white: 0.15, alpha: 0.9))
    }
}

// MARK: - Drawing Helpers

private func drawGradient(in context: CGContext, rect: CGRect, colors: [UIColor]) {
    let cgColors = colors.map { $0.cgColor }
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: cgColors as CFArray,
        locations: nil
    ) else { return }

    context.saveGState()
    context.clip(to: rect)
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: rect.midX, y: rect.minY),
                               end: CGPoint(x: rect.midX, y: rect.maxY),
                               options: [])
    context.restoreGState()
}

private func drawTree(in context: CGContext, x: CGFloat, y: CGFloat, size: CGFloat) {
    // Trunk
    context.setFillColor(UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1.0).cgColor)
    context.fill(CGRect(x: x + size * 0.4, y: y + size * 0.6, width: size * 0.2, height: size * 0.5))

    // Canopy
    context.setFillColor(UIColor(red: 0.2, green: 0.6, blue: 0.15, alpha: 1.0).cgColor)
    context.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size * 0.7))
}

private func drawPersonSilhouette(in context: CGContext, x: CGFloat, y: CGFloat, height: CGFloat, color: UIColor) {
    let headRadius = height * 0.08
    let bodyWidth = height * 0.22
    let shoulderY = y + headRadius * 2 + height * 0.05

    context.setFillColor(color.cgColor)

    // Head
    context.fillEllipse(in: CGRect(
        x: x + bodyWidth / 2 - headRadius,
        y: y,
        width: headRadius * 2,
        height: headRadius * 2
    ))

    // Body
    let bodyPath = UIBezierPath()
    bodyPath.move(to: CGPoint(x: x + bodyWidth * 0.2, y: shoulderY))
    bodyPath.addLine(to: CGPoint(x: x + bodyWidth * 0.8, y: shoulderY))
    bodyPath.addLine(to: CGPoint(x: x + bodyWidth * 0.75, y: y + height * 0.55))
    bodyPath.addLine(to: CGPoint(x: x + bodyWidth * 0.25, y: y + height * 0.55))
    bodyPath.close()
    context.addPath(bodyPath.cgPath)
    context.fillPath()

    // Legs
    context.fill(CGRect(x: x + bodyWidth * 0.28, y: y + height * 0.53, width: bodyWidth * 0.18, height: height * 0.47))
    context.fill(CGRect(x: x + bodyWidth * 0.54, y: y + height * 0.53, width: bodyWidth * 0.18, height: height * 0.47))

    // Arms
    context.fill(CGRect(x: x - bodyWidth * 0.05, y: shoulderY, width: bodyWidth * 0.15, height: height * 0.35))
    context.fill(CGRect(x: x + bodyWidth * 0.9, y: shoulderY, width: bodyWidth * 0.15, height: height * 0.35))
}
