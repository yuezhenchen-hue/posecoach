# PoseCoach 开发环境配置指南

本文档记录了项目的关键配置信息和首次开发所需的环境搭建步骤。

## 一、关键项目信息

| 项目 | 值 |
|------|-----|
| **App 名称** | PoseCoach |
| **Bundle ID** | com.posecoach.app |
| **最低 iOS 版本** | 17.0 |
| **Swift 版本** | 5.9 |
| **当前版本** | 1.0.0 (Build 1) |
| **GitHub 仓库** | https://github.com/yuezhenchen-hue/posecoach |
| **主分支** | main |
| **开发语言** | 中文（zh-Hans） |

## 二、必须安装的软件

### 1. Xcode（必须）
从 Mac App Store 免费下载（约 12GB）：
```
打开 App Store → 搜索 "Xcode" → 下载安装
```
安装完成后运行一次 Xcode，同意 License Agreement。

### 2. 修复 Homebrew 权限
```bash
sudo chown -R $(whoami) /usr/local/bin
chmod u+w /usr/local/bin
```

### 3. 安装 GitHub CLI
```bash
brew install gh
```

### 4. GitHub 登录认证
```bash
gh auth login
```
选择 GitHub.com → HTTPS → 用浏览器完成认证。

### 5. 推送代码到 GitHub
确保 GitHub 上已创建仓库 `yuezhenchen-hue/posecoach`，然后：
```bash
cd ~/Downloads/PoseCoach
git push -u origin main
```

### 6. 安装 XcodeGen
```bash
brew install xcodegen
```

### 7. 生成 Xcode 项目文件
```bash
cd ~/Downloads/PoseCoach
xcodegen generate
```
会根据 `project.yml` 生成 `PoseCoach.xcodeproj`。

### 8. 打开项目
```bash
open PoseCoach.xcodeproj
```

## 三、Xcode 项目配置

打开项目后需要做以下配置：

### 设置 Development Team
1. 在 Xcode 左侧选择项目 → Targets → PoseCoach
2. Signing & Capabilities 标签
3. Team 下拉框选择你的 Apple Developer 账号
4. 勾选 "Automatically manage signing"

### 添加 Capabilities
1. 点击 "+ Capability"
2. 添加：Camera（已在 Info.plist 配置权限描述）

### 选择运行设备
1. 用数据线连接 iPhone
2. Xcode 顶部选择你的 iPhone 作为目标设备
3. 首次运行需要在 iPhone 上信任开发者证书：
   设置 → 通用 → VPN与设备管理 → 信任你的开发者账号

## 四、文件说明

| 文件/目录 | 说明 |
|-----------|------|
| `project.yml` | XcodeGen 项目配置，定义 targets、settings、dependencies |
| `PoseCoach/Resources/Info.plist` | App 配置，包含权限描述（相机/相册/麦克风） |
| `PoseCoach/App/PoseCoachApp.swift` | App 入口 (@main) |
| `PoseCoach/App/ContentView.swift` | 主 TabView 导航 |
| `PoseCoach/Camera/CameraManager.swift` | 相机核心：AVCaptureSession 管理 |
| `PoseCoach/AI/` | 所有 AI 分析模块 |
| `PoseCoach/Guide/GuideEngine.swift` | 核心调度引擎，协调所有 AI 模块 |
| `PoseCoach/PhotoMatch/` | 「照着拍」功能模块 |
| `PoseCoach/Models/PoseTemplate.swift` | 预置 25+ 个 Pose 模板 |

## 五、开发规范

### Git 提交规范
```
feat: 新功能
fix: Bug 修复
refactor: 重构
style: UI/样式调整
docs: 文档更新
test: 测试相关
chore: 构建/工具变更
```

### 分支策略
- `main` - 稳定版本，可提交审核
- `dev` - 日常开发分支
- `feature/xxx` - 功能分支

## 六、下一步开发任务

### Phase 1: 让相机跑起来（第一个里程碑）
1. 安装 Xcode 并生成项目
2. 在真机上运行，确认相机预览正常
3. 测试拍照和保存功能
4. 验证构图参考线显示

### 调试技巧
- 相机功能 **只能在真机上测试**，模拟器没有摄像头
- 用 `print()` 输出调试信息
- Xcode Console 查看日志
- 如果 App 闪退，看 Xcode 的 crash log
