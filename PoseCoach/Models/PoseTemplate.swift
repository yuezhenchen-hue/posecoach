import SwiftUI

/// 灵感场景分组
struct InspirationCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let templates: [PoseTemplate]

    static let allCategories: [InspirationCategory] = [
        InspirationCategory(
            id: "beach", name: "海边", icon: "water.waves", color: .cyan,
            templates: PoseTemplate.allPoses.filter { $0.scene == .beach }
        ),
        InspirationCategory(
            id: "city", name: "街拍", icon: "building.2.fill", color: .purple,
            templates: PoseTemplate.allPoses.filter { $0.scene == .cityStreet }
        ),
        InspirationCategory(
            id: "cafe", name: "咖啡厅", icon: "cup.and.saucer.fill", color: .brown,
            templates: PoseTemplate.allPoses.filter { $0.scene == .cafe }
        ),
        InspirationCategory(
            id: "sunset", name: "日落", icon: "sunset.fill", color: .orange,
            templates: PoseTemplate.allPoses.filter { $0.scene == .sunset }
        ),
        InspirationCategory(
            id: "nature", name: "自然/花园", icon: "leaf.fill", color: .green,
            templates: PoseTemplate.allPoses.filter { $0.scene == .garden || $0.scene == .nature }
        ),
        InspirationCategory(
            id: "spring_forest", name: "春日山林", icon: "tree.fill", color: .mint,
            templates: PoseTemplate.allPoses.filter { $0.scene == .forest || $0.scene == .mountain }
        ),
        InspirationCategory(
            id: "night", name: "夜景", icon: "moon.stars.fill", color: .indigo,
            templates: PoseTemplate.allPoses.filter { $0.scene == .nightScene }
        ),
        InspirationCategory(
            id: "general", name: "通用", icon: "sparkles", color: .pink,
            templates: PoseTemplate.allPoses.filter { $0.scene == .unknown }
        ),
    ]
}

/// Pose 模板：预置的推荐姿势
struct PoseTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let scene: SceneType
    let personCount: PersonCount
    let difficulty: Difficulty
    let placeholderGradient: [String]

    init(id: String, name: String, description: String, scene: SceneType,
         personCount: PersonCount, difficulty: Difficulty,
         placeholderGradient: [String] = ["orange", "pink"]) {
        self.id = id
        self.name = name
        self.description = description
        self.scene = scene
        self.personCount = personCount
        self.difficulty = difficulty
        self.placeholderGradient = placeholderGradient
    }

    /// 模板图片名称（Asset Catalog 中的图片名，无图时返回 nil）
    var imageName: String? {
        let name = "template_\(id)"
        return UIImage(named: name) != nil ? name : nil
    }

    /// 是否包含人物（用于判断是否需要轮廓叠加功能）
    var hasPerson: Bool { personCount != .group || scene != .unknown }

    /// 占位渐变色
    var gradientColors: [Color] {
        placeholderGradient.compactMap { Color.fromName($0) }
    }

    enum PersonCount: String, Codable, CaseIterable {
        case single = "单人"
        case couple = "双人"
        case group = "多人"
    }

    enum Difficulty: String, Codable {
        case easy = "简单"
        case medium = "中等"
        case hard = "进阶"
    }

    static func recommendations(for scene: SceneType) -> [PoseTemplate] {
        allPoses.filter { $0.scene == scene || scene == .unknown }
    }

    static let allPoses: [PoseTemplate] = [
        // 海边
        PoseTemplate(id: "beach_01", name: "背影看海", description: "面朝大海，微微侧头，风吹头发\n拍摄者在身后3-5米处低角度仰拍", scene: .beach, personCount: .single, difficulty: .easy, placeholderGradient: ["cyan", "blue"]),
        PoseTemplate(id: "beach_02", name: "踩浪花", description: "站在浪花边缘，抬脚踩水，表情自然开心\n建议连拍，抓拍水花溅起的瞬间", scene: .beach, personCount: .single, difficulty: .easy, placeholderGradient: ["cyan", "teal"]),
        PoseTemplate(id: "beach_03", name: "沙滩奔跑", description: "沿海边自然奔跑，头发飘动\n低角度连拍，用三分线构图", scene: .beach, personCount: .single, difficulty: .medium, placeholderGradient: ["orange", "cyan"]),
        PoseTemplate(id: "beach_04", name: "纱巾飘动", description: "手持纱巾让风吹起，营造飘逸感\n逆光拍摄效果更佳", scene: .beach, personCount: .single, difficulty: .medium, placeholderGradient: ["pink", "cyan"]),
        PoseTemplate(id: "beach_05", name: "情侣牵手", description: "面朝大海牵手走在海边\n从背后拍两人侧影，天际线在上三分线", scene: .beach, personCount: .couple, difficulty: .easy, placeholderGradient: ["orange", "blue"]),

        // 城市街拍
        PoseTemplate(id: "city_01", name: "回眸一笑", description: "自然走路约3步后，回头看镜头微笑\n侧面45度最自然，注意背景干净", scene: .cityStreet, personCount: .single, difficulty: .easy, placeholderGradient: ["purple", "pink"]),
        PoseTemplate(id: "city_02", name: "靠墙站", description: "一脚靠墙，侧身45度，看向远方\n利用墙面纹理做背景，注意光影", scene: .cityStreet, personCount: .single, difficulty: .easy, placeholderGradient: ["gray", "purple"]),
        PoseTemplate(id: "city_03", name: "走路抓拍", description: "自然行走，低角度拍摄显腿长\n镜头在膝盖高度，人在三分线位置", scene: .cityStreet, personCount: .single, difficulty: .medium, placeholderGradient: ["blue", "purple"]),
        PoseTemplate(id: "city_04", name: "斑马线", description: "站在斑马线中间，利用线条做引导线\n居中对称构图效果好", scene: .cityStreet, personCount: .single, difficulty: .easy, placeholderGradient: ["gray", "blue"]),

        // 咖啡厅
        PoseTemplate(id: "cafe_01", name: "窗边阅读", description: "侧坐窗边，低头看书或手机\n利用窗户自然光，侧面柔光最好", scene: .cafe, personCount: .single, difficulty: .easy, placeholderGradient: ["brown", "orange"]),
        PoseTemplate(id: "cafe_02", name: "手托腮", description: "手肘撑桌，手托腮微笑\n前方放咖啡杯做前景，虚化背景", scene: .cafe, personCount: .single, difficulty: .easy, placeholderGradient: ["brown", "pink"]),
        PoseTemplate(id: "cafe_03", name: "举杯微笑", description: "双手捧杯，杯沿靠近嘴边\n眼神看向窗外，氛围感满分", scene: .cafe, personCount: .single, difficulty: .easy, placeholderGradient: ["orange", "brown"]),

        // 日落
        PoseTemplate(id: "sunset_01", name: "剪影伸手", description: "面朝夕阳伸出手，拍剪影效果\n降低曝光，让人物变成纯黑剪影", scene: .sunset, personCount: .single, difficulty: .medium, placeholderGradient: ["orange", "red"]),
        PoseTemplate(id: "sunset_02", name: "举手触阳", description: "手举起假装触碰太阳，创意构图\n需要精确对位，多拍几张选最好的", scene: .sunset, personCount: .single, difficulty: .medium, placeholderGradient: ["yellow", "orange"]),
        PoseTemplate(id: "sunset_03", name: "情侣剪影", description: "面对面靠近，拍双人剪影\n用日落做背景光，轮廓分明", scene: .sunset, personCount: .couple, difficulty: .medium, placeholderGradient: ["red", "orange"]),

        // 自然/花园
        PoseTemplate(id: "nature_01", name: "花丛半遮面", description: "站在花丛中，花遮住半边脸\n大光圈虚化前景花朵", scene: .garden, personCount: .single, difficulty: .easy, placeholderGradient: ["green", "pink"]),
        PoseTemplate(id: "nature_02", name: "闻花香", description: "微微低头闻花，表情陶醉自然\n侧面45度拍摄最佳", scene: .garden, personCount: .single, difficulty: .easy, placeholderGradient: ["green", "yellow"]),
        PoseTemplate(id: "nature_03", name: "森林漫步", description: "走在林间小路，回头看镜头\n利用小路做引导线构图", scene: .nature, personCount: .single, difficulty: .easy, placeholderGradient: ["green", "teal"]),

        // 夜景
        PoseTemplate(id: "night_01", name: "霓虹背景", description: "面朝镜头，霓虹灯做光斑背景\n大光圈虚化灯光，人物清晰", scene: .nightScene, personCount: .single, difficulty: .medium, placeholderGradient: ["purple", "blue"]),
        PoseTemplate(id: "night_02", name: "路灯下", description: "站在路灯下，利用顶光营造氛围\n稍微仰拍，路灯入画", scene: .nightScene, personCount: .single, difficulty: .medium, placeholderGradient: ["indigo", "yellow"]),

        // 通用
        PoseTemplate(id: "general_01", name: "自然站立", description: "微侧身，一手插兜，重心放一条腿\n最基础也最好用的站姿", scene: .unknown, personCount: .single, difficulty: .easy, placeholderGradient: ["orange", "pink"]),
        PoseTemplate(id: "general_02", name: "坐姿放松", description: "找台阶或栏杆坐下，双腿自然交叉\n平视或微俯拍都可以", scene: .unknown, personCount: .single, difficulty: .easy, placeholderGradient: ["pink", "purple"]),
        PoseTemplate(id: "general_03", name: "抬头仰望", description: "微微抬头看天空，表情放松\n仰拍角度，以天空为背景", scene: .unknown, personCount: .single, difficulty: .easy, placeholderGradient: ["blue", "cyan"]),

        // 春日山林
        PoseTemplate(id: "spring_forest_01", name: "林间小路漫步", description: "沿着树林小路自然行走\n利用路径做引导线，人在三分线位置", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["green", "mint"]),
        PoseTemplate(id: "spring_forest_02", name: "阳光穿透树叶", description: "仰头感受阳光穿透树叶的光斑\n逆光拍摄，头发周围形成光晕", scene: .forest, personCount: .single, difficulty: .medium, placeholderGradient: ["green", "yellow"]),
        PoseTemplate(id: "spring_forest_03", name: "树干倚靠", description: "侧身倚靠大树干，一脚踩树根\n利用树干纹理做背景，侧光最佳", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["brown", "green"]),
        PoseTemplate(id: "spring_forest_04", name: "溪边蹲坐", description: "在山溪旁蹲下，手触碰溪水\n低角度拍摄，溪水做前景虚化", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["teal", "green"]),
        PoseTemplate(id: "spring_forest_05", name: "春日花海", description: "站在野花丛中，双臂微张感受自然\n广角拍摄，人物在花海中心", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["pink", "green"]),
        PoseTemplate(id: "spring_forest_06", name: "山顶远眺", description: "站在山顶俯瞰远处风景，背影面朝山谷\n广角构图，人物放在画面下三分之一", scene: .mountain, personCount: .single, difficulty: .medium, placeholderGradient: ["blue", "green"]),
        PoseTemplate(id: "spring_forest_07", name: "仰望参天大树", description: "仰头望向参天大树的树冠\n超低角度仰拍，树干做引导线", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["green", "teal"]),
        PoseTemplate(id: "spring_forest_08", name: "竹林穿行", description: "走在竹林间的小路上\n利用竹竿形成对称构图", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["green", "cyan"]),
        PoseTemplate(id: "spring_forest_09", name: "落叶纷飞", description: "双手向上抛撒落叶，抓拍飘散瞬间\n连拍模式，逆光效果更梦幻", scene: .forest, personCount: .single, difficulty: .medium, placeholderGradient: ["orange", "green"]),
        PoseTemplate(id: "spring_forest_10", name: "晨雾仙境", description: "清晨薄雾中站在林间空地\n雾气营造朦胧氛围，人物剪影效果好", scene: .forest, personCount: .single, difficulty: .hard, placeholderGradient: ["gray", "green"]),
        PoseTemplate(id: "spring_forest_11", name: "吊桥上回望", description: "站在山间吊桥上回头看镜头\n桥面做引导线，背景是山谷绿林", scene: .mountain, personCount: .single, difficulty: .medium, placeholderGradient: ["brown", "green"]),
        PoseTemplate(id: "spring_forest_12", name: "花瓣飘落", description: "樱花树下，花瓣随风飘落\n仰拍，让花瓣在画面中漫天飞舞", scene: .forest, personCount: .single, difficulty: .medium, placeholderGradient: ["pink", "white"]),
        PoseTemplate(id: "spring_forest_13", name: "草地躺拍", description: "躺在草地上，仰望天空和树冠\n从正上方俯拍，四周环绕绿草", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["green", "yellow"]),
        PoseTemplate(id: "spring_forest_14", name: "光影斑驳", description: "站在树影斑驳的光下\n利用树叶间的光斑照在脸上和身上", scene: .forest, personCount: .single, difficulty: .medium, placeholderGradient: ["yellow", "green"]),
        PoseTemplate(id: "spring_forest_15", name: "石阶攀登", description: "在山间石阶上行走或回望\n利用石阶做引导线，人在画面中段", scene: .mountain, personCount: .single, difficulty: .easy, placeholderGradient: ["gray", "green"]),
        PoseTemplate(id: "spring_forest_16", name: "日出山巅", description: "清晨站在山顶迎接日出\n剪影效果，双臂打开拥抱阳光", scene: .mountain, personCount: .single, difficulty: .hard, placeholderGradient: ["orange", "blue"]),
        PoseTemplate(id: "spring_forest_17", name: "雨后彩虹", description: "雨后的森林里，叶片挂着水珠\n微距前景+人物远景的层次构图", scene: .forest, personCount: .single, difficulty: .hard, placeholderGradient: ["teal", "green"]),
        PoseTemplate(id: "spring_forest_18", name: "田野奔跑", description: "在山间开阔草地上自由奔跑\n航拍视角或低角度跟拍效果好", scene: .forest, personCount: .single, difficulty: .medium, placeholderGradient: ["green", "cyan"]),
        PoseTemplate(id: "spring_forest_19", name: "情侣山间牵手", description: "两人牵手走在山间小路\n从身后拍摄背影，远处是连绵山脉", scene: .mountain, personCount: .couple, difficulty: .easy, placeholderGradient: ["green", "blue"]),
        PoseTemplate(id: "spring_forest_20", name: "山野写真", description: "在野花和绿草间自然坐下\n俯拍或平拍，裙摆铺在草地上", scene: .forest, personCount: .single, difficulty: .easy, placeholderGradient: ["pink", "green"]),
    ]
}

// MARK: - Color Name Helper

extension Color {
    static func fromName(_ name: String) -> Color? {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return .orange
        }
    }
}
