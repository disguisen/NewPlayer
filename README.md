# NewPlayer

面向 iPhone/Apple TV 的多媒体播放器雏形，参考 Infuse 8 Pro 的体验目标。仓库提供了基于 SwiftUI + 可插拔播放内核的模块化骨架，便于后续接入 AVPlayer/FFmpeg、网络协议和元数据服务。

## 模块设计
- **Common**：媒体模型、字幕/音轨描述、错误类型等通用定义。
- **Core**：播放引擎协议 (`PlayerEngine`) 和播放状态结构体，便于替换 AVPlayer/FFmpeg 实现。
- **Player**：默认播放引擎的占位实现 `DefaultPlayerEngine`，演示如何加载媒体、切换音轨/字幕、变速播放等。
- **Library**：媒体库服务、内存存储、示例元数据抓取逻辑（可换成 TMDb/TVDb 等）。
- **Networking**：简单的网络客户端接口，后续可接入 `URLSession`/`Alamofire` 以及 SMB/WebDAV/UPnP 等协议客户端。
- **App**：SwiftUI 入口与基础页面（首页、媒体库、设置、详情）。

## 下一步接入建议
1. 在 `DefaultPlayerEngine` 中对接 AVPlayer 或自编译的 FFmpeg + VideoToolbox，驱动真实播放、缓冲与事件回调。
2. 将 `NetworkClient` 替换为实际的 HTTP 客户端，并补充授权、错误处理与缓存策略。
3. 在 `MetadataService` 中串接 TMDb/TVDb 等 API，并为海报/背景图实现磁盘缓存。
4. 扩展媒体库扫描逻辑（本地文件、SMB/WebDAV/FTP/UPnP），将扫描结果写入持久化存储（CoreData/SQLite）。
5. 在 SwiftUI 界面加入播放器控件、手势、画中画、远程控制中心以及字幕样式设置。

## 运行说明
本仓库以 Swift Package 形式组织，可直接导入 Xcode 并设置 iOS 16+ 目标设备。`App/` 目录提供了 SwiftUI 入口样例，作为后续集成到 Xcode 工程或 `.xcodeproj` 的起点。
