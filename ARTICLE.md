# 告别繁琐！使用 KBSanboxBrowser 优雅地管理 iOS 沙盒文件

## 引言

在 iOS 开发过程中，查看和管理 App 的沙盒文件通常是一件令人头疼的事情。我们往往需要连接 Xcode，打开 Devices and Simulators 窗口，下载容器，然后右键显示包内容……这一套流程下来，不仅繁琐，而且效率极低。特别是当我们需要在真机上快速验证生成的文件、查看日志或者上传测试数据时，现有的工具往往显得力不从心。

今天，我要向大家推荐一款能够彻底改变这一现状的开源库 —— **KBSanboxBrowser**。

## 什么是 KBSanboxBrowser？

KBSanboxBrowser 是一个强大的 iOS 沙盒文件浏览器。它在你的 App 内部启动一个轻量级的 Web 服务器（基于 GCDWebServer），并提供了一个基于 Vue 3 构建的现代化 Web 界面。

这意味着，你只需要手机和电脑（或另一台手机）在同一个局域网下，就可以通过浏览器直接访问、管理你 App 的沙盒文件！

## 核心亮点

### 1. 现代化的 Web 界面
告别简陋的 HTML 列表，KBSanboxBrowser 拥有一个响应式、美观的 Vue 3 界面，操作体验如同原生文件管理器一般流畅。

### 2. 强大的文件预览
无需下载即可直接预览多种格式的文件，极大提升调试效率：
*   **图片**：支持 jpg, png, gif, webp 等常见格式。
*   **音视频**：直接在浏览器播放 mp3, mp4, mov 等媒体文件。
*   **文档**：支持 PDF 文件直接预览。
*   **代码/文本**：支持 json, xml, log, swift, js 等文本文件的查看，方便快速检查日志或配置。

### 3. 全功能文件管理
不仅仅是查看，你还可以完全控制你的沙盒：
*   **上传文件**：直接将电脑上的测试数据、图片或配置拖入浏览器上传到沙盒指定目录。
*   **新建文件夹**：整理你的测试文件结构。
*   **重命名/删除**：快速清理垃圾文件或重命名测试用例。
*   **下载**：一键导出日志文件或数据库备份到电脑。

### 4. 安全与隐私设计
为了防止误操作导致 App 运行异常，KBSanboxBrowser 特别加入了**根目录保护机制**：
*   在沙盒根目录下，禁止新建、上传、重命名或删除文件夹。
*   自动隐藏 `SystemData`、`.plist` 等敏感系统文件，专注于你的业务数据。

## 如何使用？

### 1. 安装
目前支持通过 CocoaPods 安装。在你的 `Podfile` 中添加：

```ruby
pod 'KBSanboxBrowser', :git => 'https://github.com/Kimball-Han/KBSanboxBrowser.git'
```

### 2. 配置权限 (iOS 14+)
由于需要使用本地网络，请在 `Info.plist` 中添加以下配置，以允许 App 进行本地网络发现：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Allow access to local network to use the sandbox browser.</string>
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
</array>
```

### 3. 一行代码启动
建议在 `AppDelegate` 或你的调试菜单入口中加入启动代码：

```swift
import KBSanboxBrowser

// 启动服务 (默认端口 9906)
KBSandboxBrowser.shared.start()

// 获取并打印访问地址
if let url = KBSandboxBrowser.shared.serverURL {
    print("Server started at: \(url.absoluteString)")
}
```

启动后，控制台会输出访问地址（例如 `http://192.168.1.100:9906`），在电脑或手机浏览器中输入该地址即可开始使用。

## 结语

KBSanboxBrowser 极大地简化了 iOS 开发调试中的文件交互流程。无论是查看日志、验证下载内容，还是注入测试数据，它都能助你一臂之力，让调试工作变得更加轻松愉快。

项目已开源，欢迎大家试用、Star 和提交 Issue！

**GitHub 地址**: [https://github.com/Kimball-Han/KBSanboxBrowser](https://github.com/Kimball-Han/KBSanboxBrowser)
