# A3 拆分 A4 - iOS App

一款专为 iPhone 设计的 A3 转 A4 拆分工具。支持将 A3 图片或 PDF 自动拆分为多页纵向 A4 PDF，并自动添加裁切线，方便打印。

## 功能特性

1. **拆分功能**：上传 A3 图片或 PDF，自动拆分为多页纵向 A4 PDF
2. **自动识别**：自动识别横向或纵向排版
3. **裁切线**：生成的 A4 PDF 自动添加裁切线（四角 L 型标记）
4. **纵向排列**：所有输出页面均为纵向（Portrait）A4，方便打印
5. **保存功能**：支持保存到文件 App 的文档目录
6. **分享功能**：支持分享到微信、邮件、AirDrop 等
7. **预览功能**：生成后可预览 PDF 效果

## 系统要求

- iOS 15.0+
- iPhone 14 或更新机型（兼容所有支持 iOS 15+ 的设备）

## 项目结构

```
A3ToA4Splitter/
├── A3ToA4Splitter/
│   ├── A3ToA4SplitterApp.swift    # App 入口
│   ├── ContentView.swift           # 主界面
│   ├── PDFProcessor.swift          # PDF 拆分核心逻辑
│   ├── Info.plist                  # 应用配置
│   ├── Assets.xcassets/            # 图标和资源
│   └── Preview Content/            # 预览资源
└── README.md                       # 本文件
```

## 如何构建 IPA

### 前提条件

1. **macOS 电脑**（必须，Xcode 仅限 macOS）
2. **Xcode 14.0 或更高版本**
3. **Apple Developer 账号**（免费或付费均可，付费才能发布到 App Store）

### 步骤

#### 1. 创建 Xcode 项目

打开 Xcode，选择 **File > New > Project**，选择 **iOS > App**，点击 Next：

- **Product Name**: `A3ToA4Splitter`
- **Team**: 选择你的 Apple Developer 账号
- **Organization Identifier**: 例如 `com.yourname`
- **Interface**: `SwiftUI`
- **Language**: `Swift`
- **Minimum Deployments**: `iOS 15.0`

#### 2. 替换源代码

将本项目中的源文件复制到 Xcode 项目中，替换自动生成的文件：

1. 替换 `A3ToA4SplitterApp.swift`
2. 替换 `ContentView.swift`
3. 添加 `PDFProcessor.swift`
4. 替换 `Info.plist`（在项目设置中手动添加权限说明）

#### 3. 添加必要权限

在 Xcode 中，选中项目 > Targets > A3ToA4Splitter > Info，添加以下权限说明：

- `Privacy - Photo Library Usage Description`：需要访问相册以选择图片或PDF文件
- `Privacy - Documents Folder Usage Description`：需要访问文件以保存生成的PDF

（或直接替换 Info.plist 文件）

#### 4. 配置签名

在 Xcode 中：

1. 选中项目 > Targets > A3ToA4Splitter > Signing & Capabilities
2. 勾选 **Automatically manage signing**
3. 选择你的 **Team**（Apple ID）
4. 修改 **Bundle Identifier** 为唯一标识，例如 `com.yourname.a3toa4splitter`

#### 5. 构建并导出 IPA

**方法 A：通过 Archive 导出（推荐）**

1. 连接 iPhone 到 Mac（或在 Xcode 中选择目标设备为 **Any iOS Device**）
2. 选择菜单 **Product > Archive**
3. 等待构建完成，Organizer 窗口会自动打开
4. 选择刚创建的 Archive，点击 **Distribute App**
5. 选择 **Ad Hoc**（用于测试）或 **App Store Connect**（用于上架）
6. 按照向导完成签名和导出

**方法 B：直接安装到手机调试**

1. 用数据线连接 iPhone 到 Mac
2. 在 Xcode 顶部选择你的 iPhone 设备
3. 点击运行按钮（▶）或按 `Cmd+R`
4. 首次运行需要在 iPhone 设置中信任开发者证书：**设置 > 通用 > VPN与设备管理 > 信任**

### 免费开发者账号限制

- 证书每 7 天需要重新签名
- 最多可安装 3 个应用
- 无法发布到 App Store

如需长期使用，建议加入 [Apple Developer Program](https://developer.apple.com/programs/)（$99/年）。

## 使用说明

1. 打开 App，点击「从相册选择图片」或「选择 PDF 文件」
2. 选择 A3 尺寸的图片或 PDF
3. App 自动处理，显示进度
4. 处理完成后，可预览、保存或分享
5. 点击「分享到微信或其他应用」可直接发送到微信

## 技术说明

- **裁切线**：在 A4 页面四角绘制 L 型标记，线长 20pt，线宽 0.5pt，距离边缘 5pt
- **自动识别**：根据源文件宽高比自动判断横向/纵向
- **坐标系处理**：PDF 使用底部原点坐标系，渲染时进行 Y 轴翻转

## 无 Mac 电脑构建方案（GitHub Actions 云打包）

如果你没有 Mac，可以使用 **GitHub Actions** 在云端自动编译 IPA。GitHub 提供免费的 macOS 云主机，推代码即可自动打包。

### 准备工作

1. **注册 GitHub 账号**：[https://github.com](https://github)
2. **注册 Apple Developer 账号**（免费 Apple ID 即可）
3. **在 Windows 上申请 iOS 证书**（使用 [Appuploader](https://www.appuploader.net/)）

### 步骤一：申请 iOS 证书（在 Windows 上完成）

由于 GitHub Actions 编译时需要签名证书，你需要先在 Windows 上准备好：

1. 下载并安装 [Appuploader](https://www.appuploader.net/)
2. 登录你的 Apple ID
3. 创建应用标识符（Bundle ID）：`com.yourname.a3toa4splitter`
4. 生成 **iOS Development 证书**（.p12 文件）
5. 生成 **描述文件**（.mobileprovision 文件）
6. 记住你的 **Team ID**（在 Apple Developer 网站查看）

> 付费开发者账号可以生成 Ad Hoc / App Store 证书，免费账号只能生成 Development 证书。

### 步骤二：创建 GitHub 仓库并上传代码

1. 在 GitHub 新建一个仓库（如 `A3ToA4Splitter`）
2. 将本项目所有文件上传到仓库：
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/你的用户名/A3ToA4Splitter.git
   git push -u origin main
   ```

### 步骤三：配置 GitHub Secrets

在 GitHub 仓库页面 → **Settings → Secrets and variables → Actions → New repository secret**，添加以下 Secrets：

| Secret 名称 | 说明 | 获取方式 |
|------------|------|---------|
| `IOS_P12_BASE64` | 证书文件 Base64 | `certutil -encode certificate.p12 output.txt` 或 `base64 certificate.p12` |
| `IOS_P12_PASSWORD` | P12 证书密码 | 创建证书时设置的密码 |
| `IOS_PROVISION_BASE64` | 描述文件 Base64 | `base64 profile.mobileprovision` |

> 在 Windows PowerShell 中转换 Base64：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.p12"))`

### 步骤四：修改配置文件

1. 打开 `project.yml`，将 `PRODUCT_BUNDLE_IDENTIFIER` 改为你申请证书时使用的 Bundle ID
2. 打开 `ExportOptions-dev.plist`，将 `YOUR_TEAM_ID` 和 `YOUR_PROVISIONING_PROFILE_NAME` 替换为你的实际值
3. 取消 `.github/workflows/build-ios.yml` 中 "Install Signing Certificate" 和 "Install Provisioning Profile" 步骤的注释

### 步骤五：触发构建

1. 提交修改并推送到 GitHub
2. 进入仓库 → **Actions** 标签页
3. 选择左侧的 **Build iOS IPA**
4. 点击右侧 **Run workflow**，选择导出方式（development / ad-hoc / app-store）
5. 等待约 5-10 分钟
6. 构建完成后，在页面底部 **Artifacts** 区域下载 IPA 文件

### 项目文件说明（新增）

```
A3ToA4Splitter/
├── .github/workflows/build-ios.yml    # GitHub Actions 自动打包脚本
├── project.yml                        # XcodeGen 项目配置（生成 .xcodeproj）
├── ExportOptions-dev.plist            # 开发模式导出配置
├── ExportOptions-adhoc.plist          # Ad Hoc 分发配置
├── ExportOptions-appstore.plist       # App Store 上架配置
├── A3ToA4Splitter/                    # 源码目录
└── README.md                          # 本文件
```

### 常见问题

**Q：没有付费开发者账号能安装到 iPhone 吗？**
> 可以，但需要先将你的 iPhone UDID 添加到开发者账号的设备列表中（通过 Appuploader 或 Apple Developer 网站）。Development 证书签名的 IPA 只能安装到已注册设备上，且每 7 天需要重新签名。

**Q：免费开发者账号有什么限制？**
> - 证书 7 天过期，需要每周重新打包
> - 最多注册 3 台设备
> - 无法上架 App Store

**Q：可以上传到 App Store 吗？**
> 可以，但需要：
> 1. 加入 Apple Developer Program（$99/年）
> 2. 使用 App Store 证书和描述文件
> 3. 在 GitHub Actions 中选择 `app-store` 导出方式
> 4. 构建完成后使用 [Appuploader](https://www.appuploader.net/) 或 Transporter 上传

**Q：构建失败怎么办？**
> 1. 检查 GitHub Actions 日志中的错误信息
> 2. 确认 Bundle ID 与证书中的完全一致
> 3. 确认证书未过期
> 4. 尝试在 `project.yml` 中修改 `SWIFT_VERSION` 为当前 Xcode 支持的版本

## 许可证

MIT License
