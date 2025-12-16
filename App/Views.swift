import SwiftUI
import Common

struct HomeView: View {
    let items: [MediaItem]

    var body: some View {
        NavigationStack {
            List(items.prefix(5)) { item in
                NavigationLink(destination: PlayerDetailView(item: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        if let overview = item.overview {
                            Text(overview)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("继续观看")
        }
    }
}

struct LibraryView: View {
    let items: [MediaItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink(destination: PlayerDetailView(item: item)) {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("媒体库")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("播放") {
                    Toggle("硬件解码", isOn: .constant(true))
                    Toggle("后台播放", isOn: .constant(true))
                }
                Section("字幕") {
                    Toggle("自动匹配字幕", isOn: .constant(true))
                    Stepper("字幕大小", value: .constant(16), in: 12...30)
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct PlayerDetailView: View {
    let item: MediaItem

    var body: some View {
        VStack(spacing: 16) {
            Text(item.title)
                .font(.title)
            if let overview = item.overview {
                Text(overview)
                    .font(.body)
                    .padding()
            }
            Spacer()
            Text("播放控件将在这里呈现")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle(item.title)
    }
}
