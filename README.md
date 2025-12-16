# NewPlayer

面向 iPhone/Apple TV 的多媒体播放器雏形，参考 Infuse 8 Pro 的体验目标。仓库提供了基于 SwiftUI + 可插拔播放内核的模块化骨架，便于
后续接入 AVPlayer/FFmpeg、网络协议和元数据服务。

## 模块设计
- **Common**：媒体模型、扫描源定义（本地/SMB/WebDAV/FTP/UPnP）、字幕/音轨描述、错误类型等通用定义。
- **Core**：播放引擎协议 (`PlayerEngine`) 和播放状态结构体，便于替换 AVPlayer/FFmpeg 实现。
- **Player**：默认播放引擎的占位实现 `DefaultPlayerEngine`，演示如何加载媒体、切换音轨/字幕、变速播放等。
- **Library**：媒体库服务、扫描器与 SQLite 持久化存储（不可用时自动回退内存存储）、示例元数据抓取逻辑（可换成 TMDb/TVDb 等）。
- **Networking**：简单的网络客户端接口，后续可接入 `URLSession`/`Alamofire` 以及 SMB/WebDAV/UPnP 等协议客户端。
- **App**：SwiftUI 入口与基础页面（首页、媒体库、设置、详情）。

## 近期更新
- 新增示例媒体库数据，App 首次启动即可看到电影/剧集条目。
- 播放详情页加入播放/暂停、快进/快退、倍速选择、音轨与字幕切换，并展示缓冲与时间轴。`DefaultPlayerEngine` 增加模拟进度循环，便于 UI 预览。
- 媒体库扫描支持本地文件夹与 SMB/WebDAV/FTP/UPnP 远程源（当前为模拟目录列表），并将扫描结果写入 SQLite（在沙盒不可用时回退内存）。

## 下一步接入建议
1. 在 `DefaultPlayerEngine` 中对接 AVPlayer 或自编译的 FFmpeg + VideoToolbox，驱动真实播放、缓冲与事件回调。
2. 将 `NetworkClient` 替换为实际的 HTTP 客户端，并补充授权、错误处理与缓存策略。
3. 在 `MetadataService` 中串接 TMDb/TVDb 等 API，并为海报/背景图实现磁盘缓存。
4. 在 SwiftUI 界面加入播放器控件、手势、画中画、远程控制中心以及字幕样式设置。

## 运行说明
本仓库以 Swift Package 形式组织，可直接导入 Xcode 并设置 iOS 16+ 目标设备。`App/` 目录提供了 SwiftUI 入口样例，作为后续集成到 Xcode 工程或 `.xcodeproj` 的起点。
