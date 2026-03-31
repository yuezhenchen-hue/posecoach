import SwiftUI

/// 场景选择视图：手动切换拍摄场景
struct SceneSelectionView: View {
    let selectedScene: SceneType
    let onSelect: (SceneType) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(SceneType.allCases.filter { $0 != .unknown }) { scene in
                        sceneCard(scene)
                    }
                }
                .padding()
            }
            .navigationTitle("选择场景")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sceneCard(_ scene: SceneType) -> some View {
        let isSelected = scene == selectedScene
        return Button { onSelect(scene) } label: {
            VStack(spacing: 8) {
                Image(systemName: scene.icon)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(isSelected ? .orange : .gray.opacity(0.15), in: Circle())
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(scene.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .orange : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? .orange.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
