import AVFoundation

/// 相机参数：封装所有推荐的相机设置
struct CameraParameters {
    var exposureBias: Float?
    var flashMode: AVCaptureDevice.FlashMode = .off
    var hdrEnabled: Bool = false
    var usePortraitMode: Bool = false
    var suggestion: String?

    var displayItems: [ParameterItem] {
        var items: [ParameterItem] = []

        if usePortraitMode {
            items.append(ParameterItem(name: "模式", value: "人像模式", icon: "person.fill"))
        }

        if let exposure = exposureBias, exposure != 0 {
            items.append(ParameterItem(name: "曝光", value: String(format: "%+.1f", exposure), icon: "sun.max.fill"))
        }

        if hdrEnabled {
            items.append(ParameterItem(name: "HDR", value: "开启", icon: "camera.filters"))
        }

        let flashText: String
        switch flashMode {
        case .on: flashText = "开启"
        case .auto: flashText = "自动"
        case .off: flashText = "关闭"
        @unknown default: flashText = "关闭"
        }
        if flashMode != .off {
            items.append(ParameterItem(name: "闪光灯", value: flashText, icon: "bolt.fill"))
        }

        return items
    }

    struct ParameterItem: Identifiable {
        let id = UUID()
        let name: String
        let value: String
        let icon: String
    }
}
