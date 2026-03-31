import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .camera

    var body: some View {
        TabView(selection: $selectedTab) {
            MainCameraView()
                .tabItem {
                    Label("拍照", systemImage: "camera.fill")
                }
                .tag(AppTab.camera)

            PhotoMatchEntryView()
                .tabItem {
                    Label("照着拍", systemImage: "photo.on.rectangle.angled")
                }
                .tag(AppTab.photoMatch)

            PoseLibraryView()
                .tabItem {
                    Label("灵感", systemImage: "sparkles.rectangle.stack")
                }
                .tag(AppTab.poseLibrary)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(.orange)
    }
}

enum AppTab {
    case camera, photoMatch, poseLibrary, settings
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
