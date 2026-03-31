# PoseCoach - AI 摄影教练

> 从构图到快门，AI 全程指导，人人都是摄影师

PoseCoach 是一款 iOS 智能相机 App，通过实时 AI 分析为用户提供全方位拍照指导，包括场景识别、光线分析、相机参数推荐、构图引导、人物姿态建议和创意拍法提示。

## 核心功能

### 智能拍照模式
- **场景自动识别** - 海边/城市/咖啡厅/自然风光等 12+ 场景
- **光线实时分析** - 检测光线方向、强度、色温，逆光预警
- **相机参数推荐** - 曝光/HDR/闪光灯/人像模式一键应用
- **构图引导** - 三分法/黄金比例/中心对称/对角线动态参考线
- **Pose 实时指导** - 基于场景推荐最佳姿势，实时评估姿态
- **语音播报** - 全程语音引导，解放双眼

### 照着拍模式
- 上传一张参考照片，AI 全维度分析
- 自动提取场景、光线、构图、姿势、参数
- 分屏对比 / 透明叠层实时引导
- 一键应用参考图的相机参数

### Pose 灵感库
- 25+ 预置姿势，按场景/人数/难度分类
- 每个场景配备创意拍摄技巧

## 技术栈

| 技术 | 用途 |
|------|------|
| Swift / SwiftUI | 原生 iOS 开发 |
| AVFoundation | 相机控制与参数调整 |
| Vision Framework | 人体姿态检测、场景分类 |
| Core ML | AI 模型推理（全部本地离线） |
| Core Image | 光线/色彩/图像分析 |
| AVSpeechSynthesizer | 语音播报引导 |

## 项目结构

```
PoseCoach/
├── App/                    # 应用入口和主导航
├── Camera/                 # 相机管理、预览、权限
├── AI/                     # 场景识别、光线分析、姿态检测、构图分析
├── Guide/                  # 引导引擎、语音教练、参数推荐
├── PhotoMatch/             # 「照着拍」参考图分析与对比
├── Models/                 # 数据模型（场景/Pose/参数/方案）
├── Views/                  # UI 视图
├── Utils/                  # 工具类和常量
└── Resources/              # Assets、Info.plist
```

## 环境要求

- macOS 14.0+
- Xcode 16.0+
- iOS 17.0+（部署目标）
- iPhone 真机（相机功能需真机测试）

## 快速开始

### 1. 安装 XcodeGen
```bash
brew install xcodegen
```

### 2. 生成 Xcode 项目
```bash
cd PoseCoach
xcodegen generate
```

### 3. 打开项目
```bash
open PoseCoach.xcodeproj
```

### 4. 选择真机目标，运行

## 开发计划

- [x] Phase 0: 项目架构搭建
- [ ] Phase 1: 相机基础模块
- [ ] Phase 2: 场景识别 + 光线参数
- [ ] Phase 3: 构图 + Pose 指导
- [ ] Phase 4: 照着拍模式
- [ ] Phase 5: 语音引导 + 联调
- [ ] Phase 6: UI 打磨 + 测试
- [ ] Phase 7: App Store 上架

## 隐私

- 所有 AI 处理均在设备本地完成
- 不上传任何用户照片到服务器
- 不收集任何个人信息

## License

Copyright © 2026 PoseCoach. All rights reserved.
