# PoseCoach 项目上下文（AI 协作文档）

> **用途**：当你在新的 AI 对话（Cursor/Claude）中打开本项目时，让 AI 先阅读本文件。
> AI 读完此文件后即可理解项目全貌，无需读所有代码文件。
> **更新规则**：每次完成重要功能后，更新本文件中的对应部分。

---

## 一、项目概述

| 项目 | 值 |
|------|-----|
| **App 名称** | PoseCoach（AI 摄影教练） |
| **一句话描述** | 从构图到快门，AI 全程指导拍照，人人都是摄影师 |
| **目标平台** | iOS 17.0+ |
| **Bundle ID** | com.posecoach.app |
| **GitHub** | https://github.com/yuezhenchen-hue/posecoach |
| **主分支** | main |
| **开发语言** | Swift 5.9 / Python 3.12 |
| **当前版本** | 1.0.0 (Build 1) |
| **开发阶段** | Phase 0（架构搭建完成）→ 准备进入 Phase 1 |

---

## 二、核心功能

### 功能 A：智能拍照模式（主模式）
- 打开相机实时预览
- AI 同时运行 4 个分析器：场景识别、光线分析、人体姿态检测、构图分析
- GuideEngine 综合所有结果，生成实时建议
- 文字覆层 + 语音播报引导用户
- 一键应用推荐的相机参数（曝光/HDR/闪光灯/人像模式）
- 就绪度指示（红→黄→绿→蓝），绿色以上提示可以拍照

### 功能 B：照着拍模式（杀手功能）
- 用户从相册选择一张参考照片
- AI 分析参考图的 7 个维度：场景、光线、构图、姿态、参数、色彩、距离
- 生成拍摄方案（ShootingPlan）
- 进入分屏对比相机：左上角参考图 + 实时取景框
- 自动应用参考图的参数设置
- 实时对比姿势匹配度

### 功能 C：Pose 灵感库
- 25+ 预置 Pose 模板
- 按场景（海边/城市/咖啡厅等 12 种）、人数（单人/双人/多人）、难度筛选
- 每个场景附带创意拍摄技巧

### 功能 D：后端服务（V1.5 阶段使用）
- Pose 模板远程更新（不用发版就能加新 Pose）
- App 配置远程下发（功能开关、版本控制、公告）
- 匿名数据统计（了解用户行为）
- Apple 内购收据验证

---

## 三、技术架构

### iOS 端
```
技术栈：Swift + SwiftUI + AVFoundation + Vision + CoreML + CoreImage
架构模式：MVVM（@StateObject/@ObservableObject）
最低版本：iOS 17.0
Xcode 项目生成：XcodeGen（project.yml）
```

### 后端
```
技术栈：Python + FastAPI + SQLAlchemy 2.0 + SQLite
部署方式：Docker / 云服务器
API 文档：自动生成 Swagger（/docs）
```

### 全部本地 AI，不依赖网络
- Vision Framework → 人体姿态检测、场景分类
- CoreImage → 光线分析、色彩分析
- AVSpeechSynthesizer → 语音播报
- 自定义算法 → 构图评分、参数推荐

---

## 四、目录结构

```
PoseCoach/
├── PoseCoach/                    # iOS App 源码
│   ├── App/                      # 入口 + 主导航
│   │   ├── PoseCoachApp.swift        # @main 入口
│   │   └── ContentView.swift         # TabView (拍照/照着拍/灵感/设置)
│   ├── Camera/                   # 相机模块
│   │   ├── CameraManager.swift       # AVCaptureSession 核心控制
│   │   ├── CameraPreview.swift       # UIViewRepresentable 预览
│   │   └── CameraPermissionManager.swift
│   ├── AI/                       # AI 分析引擎
│   │   ├── SceneClassifier.swift     # Vision 场景分类（1秒/次）
│   │   ├── LightAnalyzer.swift       # CoreImage 光线分析（0.5秒/次）
│   │   ├── PoseDetector.swift        # Vision Body Pose（0.2秒/次）
│   │   └── CompositionAnalyzer.swift # 构图质量评分
│   ├── Guide/                    # 引导系统
│   │   ├── GuideEngine.swift         # ★ 核心调度器，协调所有AI模块
│   │   ├── VoiceCoach.swift          # 语音播报（中文TTS）
│   │   └── ParameterRecommender.swift # 场景+光线→参数推荐
│   ├── PhotoMatch/               # 照着拍模块
│   │   ├── ReferencePhotoAnalyzer.swift  # 参考图7维分析
│   │   └── PhotoMatchView.swift      # 上传+分析+分屏对比UI
│   ├── Models/                   # 数据模型
│   │   ├── SceneType.swift           # 12种场景枚举+创意技巧
│   │   ├── PoseTemplate.swift        # Pose模板+推荐逻辑
│   │   ├── CameraParameters.swift    # 相机参数封装
│   │   └── ShootingPlan.swift        # 拍摄方案
│   ├── Views/                    # UI 视图
│   │   ├── MainCameraView.swift      # ★ 主拍照界面（最复杂的视图）
│   │   ├── CompositionOverlay.swift  # 构图参考线绘制（Canvas）
│   │   ├── SceneSelectionView.swift  # 场景选择网格
│   │   ├── PoseLibraryView.swift     # Pose灵感库列表
│   │   └── SettingsView.swift        # 设置页
│   ├── Utils/Constants.swift     # 常量
│   └── Resources/                # Assets + Info.plist
├── PoseCoachTests/               # 单元测试
├── backend/                      # Python 后端服务
│   ├── app/
│   │   ├── api/                  # API路由（poses/config/analytics/iap）
│   │   ├── core/                 # 配置/数据库/安全
│   │   ├── models/               # SQLAlchemy模型 + Pydantic schemas
│   │   └── main.py              # FastAPI 入口
│   ├── scripts/seed_data.py      # 种子数据
│   ├── tests/test_api.py
│   ├── Dockerfile
│   └── requirements.txt
├── project.yml                   # XcodeGen 配置
├── PROJECT_CONTEXT.md            # ★ 本文件（AI必读）
├── SETUP_GUIDE.md                # 开发环境配置指南
└── README.md                     # 项目说明
```

---

## 五、关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| iOS UI 框架 | SwiftUI（非 UIKit） | 现代、声明式、代码量少 |
| 项目管理 | XcodeGen（非手写xcodeproj） | 可读的YAML、避免合并冲突 |
| AI 运行位置 | 全部本地 | 隐私、无延迟、无网可用 |
| 视频帧处理 | AVCaptureVideoDataOutput | 实时获取每帧用于AI分析 |
| 后端框架 | FastAPI | 异步、自动文档、你会Python |
| 数据库 | SQLite（可切PostgreSQL） | 初期轻量、后期可迁移 |
| 相机参数控制 | AVCaptureDevice lockForConfiguration | 精细控制曝光/对焦/白平衡 |

---

## 六、开发进度

### Phase 0：架构搭建 ✅ 已完成
- [x] 项目目录结构
- [x] 所有源文件框架代码（2,758 行 Swift）
- [x] 后端 API 完整代码
- [x] Git 初始化 + GitHub 推送
- [x] README + SETUP_GUIDE + PROJECT_CONTEXT

### Phase 1：相机跑起来 🔜 下一步
- [ ] 安装 Xcode + XcodeGen
- [ ] 生成 .xcodeproj 并在真机运行
- [ ] 验证相机预览正常工作
- [ ] 验证拍照和保存功能
- [ ] 验证构图参考线显示

### Phase 2：场景识别 + 光线参数
- [ ] 接入 Vision 场景分类
- [ ] 实现光线实时分析
- [ ] 参数推荐和一键应用
- [ ] 场景手动选择器

### Phase 3：构图 + Pose 指导
- [ ] 人体姿态检测调试
- [ ] 构图评分算法优化
- [ ] Pose 推荐逻辑
- [ ] 语音播报集成

### Phase 4：照着拍模式
- [ ] 参考图上传和分析
- [ ] 分屏对比相机视图
- [ ] 参数自动匹配
- [ ] 姿势匹配度计算

### Phase 5：联调 + 语音
- [ ] GuideEngine 全链路联调
- [ ] 语音播报时机优化
- [ ] 性能优化（帧率/电池）

### Phase 6：UI + 测试
- [ ] UI 动画和过渡效果
- [ ] 各机型适配
- [ ] TestFlight Beta 测试
- [ ] Bug 修复

### Phase 7：上架
- [ ] App Store 截图和描述
- [ ] 隐私政策页面
- [ ] 提交审核
- [ ] 应对审核反馈

---

## 七、App Store 关键信息

| 项目 | 值 |
|------|-----|
| Bundle ID | com.posecoach.app |
| 最低 iOS 版本 | 17.0 |
| 设备 | 仅 iPhone |
| 方向 | 仅竖屏 |
| 需要的权限 | 相机、相册（读+写）、麦克风（预留） |
| 隐私要点 | 所有AI本地处理，不上传照片 |
| 分类建议 | Photo & Video |
| 定价策略 | MVP免费，V2引入订阅 |

---

## 八、已知问题和待办

- [ ] CameraManager 的 `nonisolated` 标注需要在 Swift 6 严格并发下验证
- [ ] SceneClassifier 使用系统内置分类器，准确率可能需要自定义 CoreML 模型补充
- [ ] LightAnalyzer 的逆光检测算法是简化版，需要真机调优阈值
- [ ] PhotoMatchView 中参考图叠层功能目前是 placeholder，需要完善
- [ ] 后端 API 目前没有限流，上线前需要加 rate limiting

---

## 九、如何在新对话中继续开发

### 在 Cursor 中开始新对话时：
1. 打开项目文件夹 `~/Downloads/PoseCoach`
2. 告诉 AI：「请先阅读 PROJECT_CONTEXT.md 了解项目全貌」
3. 然后说明你要做什么

### 在新电脑上：
```bash
git clone https://github.com/yuezhenchen-hue/posecoach.git
cd posecoach
# iOS: xcodegen generate && open PoseCoach.xcodeproj
# Backend: cd backend && pip install -r requirements.txt
```

### 推荐的对话开场白：
```
请阅读 PROJECT_CONTEXT.md，然后帮我继续开发 PoseCoach 项目。
当前进度在 Phase X，我要做 [具体任务]。
```

---

*最后更新：2026-03-31 | Phase 0 完成*
