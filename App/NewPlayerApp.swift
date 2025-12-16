import SwiftUI
import Library
import Player
import Common

@main
struct NewPlayerApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(viewModel)
        }
    }
}

final class AppViewModel: ObservableObject {
    @Published var library: [MediaItem] = []
    private let libraryService = LibraryService()

    init() {
        Task { await load() }
    }

    @MainActor
    func load() async {
        library = (try? await libraryService.loadLibrary()) ?? []
    }
}

struct MainTabView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            HomeView(items: viewModel.library)
                .tabItem { Label("首页", systemImage: "house.fill") }
            LibraryView(items: viewModel.library)
                .tabItem { Label("媒体库", systemImage: "film.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
