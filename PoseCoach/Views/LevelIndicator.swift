import SwiftUI
import CoreMotion

/// 电子水平仪：基于加速度计实时检测手机水平状态
class DeviceMotionManager: ObservableObject {
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    @Published var isLevel: Bool = false

    private let motionManager = CMMotionManager()
    private let threshold: Double = 1.5

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion, let self else { return }
            let pitchDeg = motion.attitude.pitch * 180 / .pi
            let rollDeg = motion.attitude.roll * 180 / .pi
            self.pitch = pitchDeg
            self.roll = rollDeg
            self.isLevel = abs(rollDeg) < self.threshold && abs(pitchDeg) < self.threshold
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}

/// 水平仪覆层：画面中心显示水平线+角度
struct LevelIndicatorOverlay: View {
    @ObservedObject var motionManager: DeviceMotionManager
    let isEnabled: Bool

    var body: some View {
        if isEnabled {
            GeometryReader { geo in
                let centerY = geo.size.height / 2
                let centerX = geo.size.width / 2
                let rollAngle = motionManager.roll
                let lineColor: Color = motionManager.isLevel ? .green : .orange

                ZStack {
                    // 水平参考线（固定）
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 120, height: 1)
                        .position(x: centerX, y: centerY)

                    // 实时倾斜线
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 100, height: 2)
                        .rotationEffect(.degrees(rollAngle))
                        .position(x: centerX, y: centerY)

                    // 中心圆点
                    Circle()
                        .fill(lineColor)
                        .frame(width: 8, height: 8)
                        .position(x: centerX, y: centerY)

                    // 角度数值
                    Text(String(format: "%.1f°", rollAngle))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(lineColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.5), in: Capsule())
                        .position(x: centerX, y: centerY + 20)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
