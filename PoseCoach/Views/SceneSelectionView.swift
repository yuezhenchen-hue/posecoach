import SwiftUI

/// 场景选择视图：手动切换拍摄场景 / 切回自动
struct SceneSelectionView: View {
    let selectedScene: SceneType
    let isManualOverride: Bool
    let onSelect: (SceneType) -> Void
    let onAutoMode: () -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    autoButton
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(SceneType.allCases.filter { $0 != .unknown }) { scene in
                            sceneCard(scene)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("选择场景")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var autoButton: some View {
        Button { onAutoMode() } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundStyle(!isManualOverride ? .white : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动识别")
                        .font(.subheadline.bold())
                    Text("AI 实时分析画面，自动匹配最佳场景")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isManualOverride {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(
                !isManualOverride ? .orange.opacity(0.15) : Color(.systemGray6),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(!isManualOverride ? .orange : .clear, lineWidth: 1.5)
            )
        }
        .foregroundStyle(.primary)
    }

    private func sceneCard(_ scene: SceneType) -> some View {
        let isSelected = isManualOverride && scene == selectedScene
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
