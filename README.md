# NewPlayer

面向 iPhone/Apple TV 的多媒体播放器雏形，参考 Infuse 8 Pro 的体验目标。仓库提供了基于 SwiftUI + 可插拔播放内核的模块化骨架，便于后续接入 AVPlayer/FFmpeg、网络协议和元数据服务。

> 本仓库当前以 Swift Package 管理源代码，并附带 SwiftUI App 入口示例。Linux/CI 环境下无法链接 SwiftUI/AVFoundation 时使用占位实现，以保证 `swift build` 可运行；在 Xcode/iOS 设备上会自动采用原生播放与 UI。

## 模块设计
- **Common**：媒体模型、扫描源定义（本地/SMB/WebDAV/FTP/UPnP）、字幕/音轨描述、错误类型等通用定义。
- **Core**：播放引擎协议 (`PlayerEngine`) 和播放状态结构体，便于替换 AVPlayer/FFmpeg 实现。
- **Player**：包含 AVPlayer 驱动的默认播放引擎 `DefaultPlayerEngine` 与 `FFmpegPlayerEngine` 占位实现；在 Apple 平台自动启用 AVPlayer，其他平台退化为模拟状态。
- **Library**：媒体库服务、扫描器与（占位）SQLite 持久化存储，默认落地到内存存储，可自行替换为真实 SQLite 适配器。
- **Networking**：简单的网络客户端接口，可替换为 `URLSession`/`Alamofire` 或协议客户端（SMB/WebDAV/UPnP 等）。
- **App**：SwiftUI 入口与基础页面（首页、媒体库、播放详情），在非 Apple 平台会回退为命令行提示。

## 近期更新
- 新增完整的源代码文件（Common/Core/Player/Library/Networking/App），补齐 SwiftPM 所需的模块目录与占位实现，保证在 Linux/CI 上可构建。
- Player/Library/Networking 统一使用可选的协议与占位实现，方便后续在 Xcode 中替换为 AVPlayer、FFmpegKit 及真实协议栈。
- `Scripts/fetch_ffmpeg_kit.sh` 提供 FFmpegKit 下载与校验脚本，便于在配置 Package.swift 环境变量后拉取二进制依赖。

## 下一步更新建议（对照 Infuse 8 Pro 目标）
1. **接入真实网络协议与鉴权**：集成 SMB/WebDAV/FTP/UPnP 客户端库，支持登录、断点续传、目录增量刷新，并补充 NFS/云盘（OneDrive/Google Drive/Dropbox）等常见来源。
2. **媒体库刮削与组织**：扩展 `MetadataService` 做多提供方聚合（TMDb/TVDb/OMDb），加入名称清洗、季/集编号修正、合集/番外识别；新增“继续观看”/“最近添加”、类型/分辨率/字幕语言筛选与全文搜索，并把播放进度持久化到 iCloud。
3. **播放内核与体验增强**：在 `FFmpegPlayerEngine` 增加 HDR10/杜比视界/全景声路径，支持音频直通/多声道混音、章节/书签/AB 循环/睡眠定时；手势灵敏度与区域可配置，新增长按倍速、画质/音效预设、锁屏歌词/字幕展示。
4. **字幕与多语言**：接入在线字幕搜索下载（如 OpenSubtitles），支持多语言优先级与偏移校正，完善 ASS/SSA 渲染与字体打包，提供字幕样式模板和偏好保存。
5. **下载与缓存策略**：实现后台下载队列（暂停/续传/限速）、局域网高速缓存，海报/元数据增量刷新与缓存失效处理，支持离线模式提示。
6. **安全与家长控制**：加入 PIN/生物识别锁定敏感内容、分级过滤；提供日志/隐私合规提示与可选崩溃/分析上报。
7. **自动化与稳定性**：补充协议模拟、播放状态机、元数据匹配的单元/UI 测试，引入 Crash/性能监控（如 MetricKit），并在 README 中完善环境配置与故障排查指引。

## 运行说明
本仓库以 Swift Package 形式组织，可直接导入 Xcode 并设置 iOS 16+ 目标设备。`App/` 目录提供了 SwiftUI 入口样例，作为后续集成到 Xcode 工程或 `.xcodeproj` 的起点。Linux/CI 环境下可以运行 `swift build` 验证模块接口；UI 将不会渲染。

### 通过 GitHub 启用 FFmpegKit
当需要更多容器/编码格式支持时，可链接官方 GitHub 发布的 FFmpegKit iOS Full 版本：

1. 运行 `Scripts/fetch_ffmpeg_kit.sh`（需要网络）自动下载 GitHub Release 产物并计算校验值。
2. 在构建前导出环境变量，让 Package.swift 注入二进制目标：
   ```bash
   export FFMPEG_KIT_BINARY_URL="https://github.com/tanersener/ffmpeg-kit/releases/download/v6.0-lts/ffmpeg-kit-ios-full-shared-6.0-lts.zip"
   export FFMPEG_KIT_CHECKSUM="<脚本输出的 checksum>"
   ```
3. 构建时会自动把 FFmpegKit 作为二进制依赖加入 `Player` 模块，并编译 `FFmpegPlayerEngine`（App 层会默认使用它）；若未提供环境变量，则回退到 AVPlayer 驱动的默认引擎或占位实现。
