import Foundation

/// 拍摄场景类型 — 30+ 场景自动识别
enum SceneType: String, CaseIterable, Identifiable, Codable {
    // 自然景观
    case beach = "beach"
    case sunset = "sunset"
    case sunrise = "sunrise"
    case mountain = "mountain"
    case forest = "forest"
    case lake = "lake"
    case waterfall = "waterfall"
    case desert = "desert"
    case snow = "snow"
    case starryNight = "starry_night"

    // 城市场景
    case cityStreet = "city_street"
    case architecture = "architecture"
    case bridge = "bridge"
    case nightScene = "night"
    case neonStreet = "neon_street"
    case subway = "subway"

    // 室内场景
    case cafe = "cafe"
    case indoor = "indoor"
    case museum = "museum"
    case library = "library"
    case gym = "gym"

    // 人物场景
    case portrait = "portrait"
    case group = "group"
    case stage = "stage"
    case wedding = "wedding"

    // 生活场景
    case food = "food"
    case pet = "pet"
    case garden = "garden"
    case market = "market"
    case amusementPark = "amusement_park"
    case festival = "festival"
    case sport = "sport"

    // 特殊场景
    case nature = "nature"
    case underwater = "underwater"
    case aerial = "aerial"
    case macro = "macro"
    case unknown = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beach: return "海边"
        case .sunset: return "日落"
        case .sunrise: return "日出"
        case .mountain: return "山景"
        case .forest: return "森林"
        case .lake: return "湖泊"
        case .waterfall: return "瀑布"
        case .desert: return "沙漠"
        case .snow: return "雪景"
        case .starryNight: return "星空"
        case .cityStreet: return "城市街拍"
        case .architecture: return "建筑"
        case .bridge: return "桥梁"
        case .nightScene: return "夜景"
        case .neonStreet: return "霓虹街景"
        case .subway: return "地铁/车站"
        case .cafe: return "咖啡厅"
        case .indoor: return "室内"
        case .museum: return "博物馆"
        case .library: return "图书馆"
        case .gym: return "运动健身"
        case .portrait: return "人像"
        case .group: return "合照"
        case .stage: return "舞台演出"
        case .wedding: return "婚礼"
        case .food: return "美食"
        case .pet: return "宠物"
        case .garden: return "花园"
        case .market: return "集市"
        case .amusementPark: return "游乐园"
        case .festival: return "节日庆典"
        case .sport: return "运动"
        case .nature: return "自然风光"
        case .underwater: return "水下"
        case .aerial: return "航拍/俯拍"
        case .macro: return "微距"
        case .unknown: return "通用"
        }
    }

    var icon: String {
        switch self {
        case .beach: return "beach.umbrella"
        case .sunset: return "sunset.fill"
        case .sunrise: return "sunrise.fill"
        case .mountain: return "mountain.2.fill"
        case .forest: return "tree.fill"
        case .lake: return "water.waves"
        case .waterfall: return "drop.triangle.fill"
        case .desert: return "sun.dust.fill"
        case .snow: return "snowflake"
        case .starryNight: return "sparkles"
        case .cityStreet: return "building.2.fill"
        case .architecture: return "building.columns.fill"
        case .bridge: return "road.lanes"
        case .nightScene: return "moon.stars.fill"
        case .neonStreet: return "lightbulb.fill"
        case .subway: return "tram.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .indoor: return "house.fill"
        case .museum: return "building.columns"
        case .library: return "books.vertical.fill"
        case .gym: return "figure.run"
        case .portrait: return "person.fill"
        case .group: return "person.3.fill"
        case .stage: return "theatermasks.fill"
        case .wedding: return "heart.fill"
        case .food: return "fork.knife"
        case .pet: return "pawprint.fill"
        case .garden: return "camera.macro"
        case .market: return "bag.fill"
        case .amusementPark: return "ferriswheel"
        case .festival: return "party.popper.fill"
        case .sport: return "sportscourt.fill"
        case .nature: return "leaf.fill"
        case .underwater: return "fish.fill"
        case .aerial: return "airplane"
        case .macro: return "magnifyingglass"
        case .unknown: return "camera.fill"
        }
    }

    var creativeTips: [String] {
        switch self {
        case .beach:
            return ["利用浪花做前景", "脚踩沙滩留下脚印", "纱巾增加飘逸感", "剪影效果"]
        case .sunset, .sunrise:
            return ["剪影效果最佳时机", "暖色光拍人物侧脸", "手举太阳创意构图", "云彩做背景"]
        case .mountain:
            return ["人物站在峰顶做剪影", "利用山路做引导线", "广角拍出壮阔感"]
        case .forest:
            return ["利用树干做框架构图", "光影斑驳效果", "低角度仰拍树冠"]
        case .lake:
            return ["利用倒影做对称构图", "前景放花草", "蹲低角度拍水面"]
        case .waterfall:
            return ["慢快门拍丝绸水流", "石头做前景", "侧面45度角最佳"]
        case .snow:
            return ["提高曝光避免灰暗", "逆光拍雪花飞舞", "红色衣物做对比色"]
        case .starryNight:
            return ["三脚架必备", "长曝光拍星轨", "手电筒补光人物"]
        case .cityStreet:
            return ["道路做引导线", "行人做前景", "蹲低拍大长腿", "橱窗反射"]
        case .architecture:
            return ["对称构图", "仰拍汇聚线条", "利用门框做框架"]
        case .nightScene, .neonStreet:
            return ["霓虹灯做背景光斑", "稳定手机很关键", "慢快门拍光轨"]
        case .cafe:
            return ["窗边自然光最佳", "咖啡杯做前景", "半身特写更有氛围"]
        case .food:
            return ["45度俯拍最经典", "自然光从侧面来", "简洁背景突出食物"]
        case .pet:
            return ["蹲下到宠物视角", "连拍抓住瞬间", "眼神对焦是关键"]
        case .portrait:
            return ["眼睛对焦最重要", "侧面45度最瘦脸", "背景虚化突出人物"]
        case .group:
            return ["让大家自然互动", "稍微仰拍更精神", "三脚架+定时器"]
        case .wedding:
            return ["抓拍自然表情", "白纱利用逆光", "细节特写戒指花束"]
        case .garden:
            return ["花丛中露出头", "低角度仰拍蓝天+花", "前景虚化花朵"]
        case .sport:
            return ["连拍模式必备", "预判动作方向", "快快门冻结动作"]
        case .macro:
            return ["保持手稳", "利用自然光", "背景越简洁越好"]
        case .stage:
            return ["提高ISO保证快门", "抓拍高潮动作", "利用舞台灯光"]
        default:
            return ["保持画面简洁", "注意背景是否杂乱", "利用对比色更出彩"]
        }
    }

    /// 从 Vision 分类器标签映射到场景类型
    static func from(classificationIdentifier: String) -> SceneType {
        let id = classificationIdentifier.lowercased()
        if id.contains("beach") || id.contains("coast") || id.contains("ocean") || id.contains("seashore") { return .beach }
        if id.contains("sunset") { return .sunset }
        if id.contains("sunrise") { return .sunrise }
        if id.contains("mountain") || id.contains("hill") || id.contains("cliff") { return .mountain }
        if id.contains("forest") || id.contains("jungle") || id.contains("woodland") { return .forest }
        if id.contains("lake") || id.contains("pond") || id.contains("reservoir") { return .lake }
        if id.contains("waterfall") || id.contains("cascade") { return .waterfall }
        if id.contains("desert") || id.contains("sand_dune") { return .desert }
        if id.contains("snow") || id.contains("winter") || id.contains("glacier") { return .snow }
        if id.contains("star") || id.contains("milky_way") || id.contains("aurora") { return .starryNight }
        if id.contains("street") || id.contains("urban") || id.contains("city") || id.contains("sidewalk") { return .cityStreet }
        if id.contains("building") || id.contains("architecture") || id.contains("tower") || id.contains("skyscraper") { return .architecture }
        if id.contains("bridge") || id.contains("viaduct") { return .bridge }
        if id.contains("night") || id.contains("nighttime") { return .nightScene }
        if id.contains("neon") || id.contains("sign") { return .neonStreet }
        if id.contains("subway") || id.contains("station") || id.contains("train") { return .subway }
        if id.contains("cafe") || id.contains("coffee") || id.contains("restaurant") || id.contains("bar") { return .cafe }
        if id.contains("museum") || id.contains("gallery") || id.contains("exhibit") { return .museum }
        if id.contains("library") || id.contains("bookshop") { return .library }
        if id.contains("gym") || id.contains("fitness") { return .gym }
        if id.contains("wedding") || id.contains("bride") || id.contains("groom") { return .wedding }
        if id.contains("stage") || id.contains("concert") || id.contains("theater") || id.contains("perform") { return .stage }
        if id.contains("food") || id.contains("dish") || id.contains("meal") || id.contains("plate") || id.contains("pizza") || id.contains("sushi") { return .food }
        if id.contains("dog") || id.contains("cat") || id.contains("pet") || id.contains("puppy") || id.contains("kitten") { return .pet }
        if id.contains("flower") || id.contains("garden") || id.contains("botanical") { return .garden }
        if id.contains("market") || id.contains("bazaar") || id.contains("shop") { return .market }
        if id.contains("sport") || id.contains("soccer") || id.contains("basketball") || id.contains("tennis") { return .sport }
        if id.contains("indoor") || id.contains("room") || id.contains("living") || id.contains("bedroom") { return .indoor }
        if id.contains("nature") || id.contains("tree") || id.contains("grass") || id.contains("meadow") { return .nature }
        if id.contains("aerial") || id.contains("drone") || id.contains("bird_eye") { return .aerial }
        return .unknown
    }
}
