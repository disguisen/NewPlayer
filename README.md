# NewPlayer

面向 iPhone/Apple TV 的多媒体播放器雏形，参考 Infuse 8 Pro 的体验目标。仓库提供了基于 SwiftUI + 可插拔播放内核的模块化骨架，便于
后续接入 AVPlayer/FFmpeg、网络协议和元数据服务。

## 模块设计
- **Common**：媒体模型、扫描源定义（本地/SMB/WebDAV/FTP/UPnP）、字幕/音轨描述、错误类型等通用定义。
- **Core**：播放引擎协议 (`PlayerEngine`) 和播放状态结构体，便于替换 AVPlayer/FFmpeg 实现。
- **Player**：包含 AVPlayer 驱动的默认播放引擎 `DefaultPlayerEngine` 与 `FFmpegPlayerEngine`；App 层在 FFmpegKit 可用时优先实例化 `FFmpegPlayerEngine` 以获取更广格式覆盖，缺少二进制时回退到 AVPlayer/占位实现。
- **Library**：媒体库服务、扫描器与 SQLite 持久化存储（不可用时自动回退内存存储）、示例元数据抓取逻辑（可换成 TMDb/TVDb 等）。
- **Networking**：简单的网络客户端接口，后续可接入 `URLSession`/`Alamofire` 以及 SMB/WebDAV/UPnP 等协议客户端。
- **App**：SwiftUI 入口与基础页面（首页、媒体库、设置、详情）。

## 近期更新
- 新增示例媒体库数据，App 首次启动即可看到电影/剧集条目。
- 媒体库扫描支持本地文件夹与 SMB/WebDAV/FTP/UPnP 远程源（当前为模拟目录列表），并将扫描结果写入 SQLite（在沙盒不可用时回退内存）。
- `MetadataService` 串接 TMDb/TVDb API（通过 `TMDB_API_KEY`/`TVDB_TOKEN` 环境变量配置），并将海报/背景图下载到磁盘缓存，加速后续加载与离线显示；新增重试 + 回退策略和 UI 层的缓存状态展示与刷新入口。
- 播放引擎：`DefaultPlayerEngine` 仍对接 AVPlayer 并推送播放/缓冲进度；App 层默认在 FFmpegKit 存在时改用 `FFmpegPlayerEngine` 以解锁更多格式，不存在时自动回退到 AVPlayer 或占位实现。
- SwiftUI 播放页强化：
  - 播放/暂停、快进/快退、拖拽进度、倍速、音轨、字幕切换等基础控件。
  - 双击跳转、左右/上下滑动调节进度/亮度/音量，便于快速试用真实播放时的手势体验。
  - 画中画开关、远程控制中心激活提示，支持 Now Playing 控制以及 PiP 与 AVPlayer/FFmpegKit 的联动。
  - 字幕字号/颜色/描边/背景透明度调节，便于验证字幕样式偏好；提供缓存状态标签与“刷新元数据”入口。
## 元数据与图片缓存
- **凭据配置**：在运行时设置环境变量 `TMDB_API_KEY`、`TVDB_TOKEN`，并可通过 `MetadataConfiguration.preferredProvider` 指定优先顺序（默认 TMDb→TVDb，若缺少凭据则自动跳过）。
- **抓取流程**：`MetadataService` 依据媒体类型调用 TMDb 或 TVDb 搜索接口，填充原始标题、剧情简介、上映年份等字段；若未匹配到结果，保留原条目不修改。
- **图片缓存**：
  - TMDb：按需下载 poster/backdrop，并将远端 URL 的 hash 生成本地文件名存入磁盘缓存目录（默认 `Caches/MetadataImages/`）。
  - TVDb：直接下载返回的海报/背景链接，同样写入缓存目录；重复请求会复用已有文件。
- **网络客户端**：`Networking.NetworkClient` 支持基于 URL 的 GET 请求和 Header 注入，可替换为 `URLSession`/`Alamofire` 实现。
- **缓存命中**：再次获取相同图片时将优先读取缓存文件，减少带宽并提升离线可用性，可据此在 UI 层展示本地缓存的艺术图。SwiftUI 播放详情页提供缓存状态标签与“刷新元数据”按钮。
- **错误兜底与重试**：
  - 通过 `MetadataConfiguration` 设置最大重试次数和指数退避基准间隔，网络/解码失败会自动重试。
  - 优先使用首选提供方（TMDb/TVDb），若失败则回退到次选提供方；全部失败时返回原始条目并在 UI 中提示错误。

## 下一步接入建议
1. 若使用自编译的 FFmpeg + VideoToolbox，可在 `DefaultPlayerEngine` 中扩展自定义管线；当前 App 已默认实例化 `FFmpegPlayerEngine`（若二进制可用），可在此基础上继续调优硬件解码/滤镜流程。

## 运行说明
本仓库以 Swift Package 形式组织，可直接导入 Xcode 并设置 iOS 16+ 目标设备。`App/` 目录提供了 SwiftUI 入口样例，作为后续集成到 Xcode 工程或 `.xcodeproj` 的起点。

### 通过 GitHub 启用 FFmpegKit
当需要更多容器/编码格式支持时，可链接官方 GitHub 发布的 FFmpegKit iOS Full 版本：

1. 运行 `Scripts/fetch_ffmpeg_kit.sh`（需要网络）自动下载 GitHub Release 产物并计算校验值。
2. 在构建前导出环境变量，让 Package.swift 注入二进制目标：
   ```bash
   export FFMPEG_KIT_BINARY_URL="https://github.com/tanersener/ffmpeg-kit/releases/download/v6.0-lts/ffmpeg-kit-ios-full-shared-6.0-lts.zip"
   export FFMPEG_KIT_CHECKSUM="<脚本输出的 checksum>"
   ```
3. 构建时会自动把 FFmpegKit 作为二进制依赖加入 `Player` 模块，并编译 `FFmpegPlayerEngine`（App 层会默认使用它）；若未提供环境变量，则回退到 AVPlayer 驱动的默认引擎或占位实现。
