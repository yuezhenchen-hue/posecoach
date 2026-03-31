import Foundation

/// Pose 模板：预置的推荐姿势
struct PoseTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let scene: SceneType
    let personCount: PersonCount
    let difficulty: Difficulty

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

    /// 根据场景返回推荐 pose 列表
    static func recommendations(for scene: SceneType) -> [PoseTemplate] {
        allPoses.filter { $0.scene == scene || scene == .unknown }
    }

    static let allPoses: [PoseTemplate] = [
        // 海边
        PoseTemplate(id: "beach_01", name: "背影看海", description: "面朝大海，微微侧头，风吹头发", scene: .beach, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "beach_02", name: "踩浪花", description: "站在浪花边缘，抬脚踩水，表情自然开心", scene: .beach, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "beach_03", name: "沙滩奔跑", description: "自然奔跑，连拍抓拍最佳瞬间", scene: .beach, personCount: .single, difficulty: .medium),
        PoseTemplate(id: "beach_04", name: "纱巾飘动", description: "手持纱巾让风吹起，营造飘逸感", scene: .beach, personCount: .single, difficulty: .medium),
        PoseTemplate(id: "beach_05", name: "情侣牵手", description: "面朝大海牵手，拍背影或侧面", scene: .beach, personCount: .couple, difficulty: .easy),

        // 城市街拍
        PoseTemplate(id: "city_01", name: "回眸一笑", description: "自然走路，回头看镜头微笑", scene: .cityStreet, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "city_02", name: "靠墙站", description: "一脚靠墙，侧身45度，看向远方", scene: .cityStreet, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "city_03", name: "走路抓拍", description: "自然行走，低角度拍摄显腿长", scene: .cityStreet, personCount: .single, difficulty: .medium),
        PoseTemplate(id: "city_04", name: "斑马线", description: "站在斑马线中间，利用线条做引导线", scene: .cityStreet, personCount: .single, difficulty: .easy),

        // 咖啡厅
        PoseTemplate(id: "cafe_01", name: "窗边阅读", description: "侧坐窗边，低头看书/手机，自然光照脸", scene: .cafe, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "cafe_02", name: "手托腮", description: "手肘撑桌，手托腮微笑，前方放咖啡杯", scene: .cafe, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "cafe_03", name: "举杯微笑", description: "双手捧杯，杯沿靠近嘴边，眼神看向窗外", scene: .cafe, personCount: .single, difficulty: .easy),

        // 日落
        PoseTemplate(id: "sunset_01", name: "剪影伸手", description: "面朝夕阳伸出手，拍剪影效果", scene: .sunset, personCount: .single, difficulty: .medium),
        PoseTemplate(id: "sunset_02", name: "举手触阳", description: "手举起假装触碰太阳，创意构图", scene: .sunset, personCount: .single, difficulty: .medium),
        PoseTemplate(id: "sunset_03", name: "情侣剪影", description: "面对面靠近，拍双人剪影", scene: .sunset, personCount: .couple, difficulty: .medium),

        // 自然/花园
        PoseTemplate(id: "nature_01", name: "花丛半遮面", description: "站在花丛中，花遮住半边脸", scene: .garden, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "nature_02", name: "闻花香", description: "微微低头闻花，表情陶醉自然", scene: .garden, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "nature_03", name: "森林漫步", description: "走在林间小路，回头看镜头", scene: .nature, personCount: .single, difficulty: .easy),

        // 夜景
        PoseTemplate(id: "night_01", name: "霓虹背景", description: "面朝镜头，霓虹灯做光斑背景", scene: .nightScene, personCount: .single, difficulty: .medium),
        PoseTemplate(id: "night_02", name: "路灯下", description: "站在路灯下，利用顶光营造氛围", scene: .nightScene, personCount: .single, difficulty: .medium),

        // 通用
        PoseTemplate(id: "general_01", name: "自然站立", description: "微侧身，一手插兜，重心放一条腿", scene: .unknown, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "general_02", name: "坐姿放松", description: "找台阶/栏杆坐下，双腿自然交叉", scene: .unknown, personCount: .single, difficulty: .easy),
        PoseTemplate(id: "general_03", name: "抬头仰望", description: "微微抬头看天空，表情放松", scene: .unknown, personCount: .single, difficulty: .easy),
    ]
}
