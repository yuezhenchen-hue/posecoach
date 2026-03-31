import Foundation

/// 拍摄场景类型
enum SceneType: String, CaseIterable, Identifiable, Codable {
    case beach = "beach"
    case sunset = "sunset"
    case cityStreet = "city_street"
    case architecture = "architecture"
    case cafe = "cafe"
    case indoor = "indoor"
    case nature = "nature"
    case garden = "garden"
    case nightScene = "night"
    case amusementPark = "amusement_park"
    case mountain = "mountain"
    case snow = "snow"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beach: return "海边"
        case .sunset: return "日落"
        case .cityStreet: return "城市街拍"
        case .architecture: return "建筑"
        case .cafe: return "咖啡厅"
        case .indoor: return "室内"
        case .nature: return "自然风光"
        case .garden: return "花园"
        case .nightScene: return "夜景"
        case .amusementPark: return "游乐园"
        case .mountain: return "山景"
        case .snow: return "雪景"
        case .unknown: return "通用"
        }
    }

    var icon: String {
        switch self {
        case .beach: return "beach.umbrella"
        case .sunset: return "sunset.fill"
        case .cityStreet: return "building.2.fill"
        case .architecture: return "building.columns.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .indoor: return "house.fill"
        case .nature: return "leaf.fill"
        case .garden: return "camera.macro"
        case .nightScene: return "moon.stars.fill"
        case .amusementPark: return "ferriswheel"
        case .mountain: return "mountain.2.fill"
        case .snow: return "snowflake"
        case .unknown: return "camera.fill"
        }
    }

    var creativeTips: [String] {
        switch self {
        case .beach:
            return ["利用浪花做前景", "脚踩沙滩留下脚印", "用纱巾增加飘逸感", "剪影效果（逆光降曝光）"]
        case .sunset:
            return ["剪影效果最佳时机", "利用暖色光拍人物侧脸", "手举太阳的创意构图"]
        case .cityStreet:
            return ["利用道路做引导线", "利用行人做前景", "蹲低拍出大长腿", "利用橱窗反射"]
        case .cafe:
            return ["窗边自然光最佳", "利用咖啡杯做前景", "拍半身特写更有氛围"]
        case .nature:
            return ["利用花丛做前景虚化", "找框架构图（树枝/石洞）", "利用溪流做引导线"]
        case .nightScene:
            return ["利用霓虹灯做背景光斑", "找光源均匀的位置", "保持手机稳定很关键"]
        case .garden:
            return ["花丛中只露出头部", "低角度仰拍（蓝天+花）", "靠近花朵做大虚化前景"]
        default:
            return ["保持画面简洁", "注意背景是否杂乱", "利用对比色更出彩"]
        }
    }

    /// 从 Vision 分类器标签映射到场景类型
    static func from(classificationIdentifier: String) -> SceneType {
        let id = classificationIdentifier.lowercased()
        if id.contains("beach") || id.contains("coast") || id.contains("ocean") { return .beach }
        if id.contains("sunset") || id.contains("sunrise") { return .sunset }
        if id.contains("street") || id.contains("urban") || id.contains("city") { return .cityStreet }
        if id.contains("building") || id.contains("architecture") { return .architecture }
        if id.contains("cafe") || id.contains("coffee") || id.contains("restaurant") { return .cafe }
        if id.contains("indoor") || id.contains("room") { return .indoor }
        if id.contains("forest") || id.contains("tree") || id.contains("nature") { return .nature }
        if id.contains("garden") || id.contains("flower") { return .garden }
        if id.contains("night") { return .nightScene }
        if id.contains("mountain") || id.contains("hill") { return .mountain }
        if id.contains("snow") || id.contains("winter") { return .snow }
        return .unknown
    }
}
