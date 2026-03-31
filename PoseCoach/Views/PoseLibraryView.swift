import SwiftUI

/// Pose 灵感库视图
struct PoseLibraryView: View {
    @State private var selectedScene: SceneType = .unknown
    @State private var selectedPersonCount: PoseTemplate.PersonCount = .single

    var filteredPoses: [PoseTemplate] {
        PoseTemplate.allPoses.filter { pose in
            (selectedScene == .unknown || pose.scene == selectedScene) &&
            pose.personCount == selectedPersonCount
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                poseList
            }
            .navigationTitle("Pose 灵感")
        }
    }

    private var filterBar: some View {
        VStack(spacing: 12) {
            // 人数筛选
            Picker("人数", selection: $selectedPersonCount) {
                ForEach(PoseTemplate.PersonCount.allCases, id: \.self) { count in
                    Text(count.rawValue).tag(count)
                }
            }
            .pickerStyle(.segmented)

            // 场景筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    sceneFilterChip(.unknown, label: "全部")
                    ForEach(SceneType.allCases.filter { $0 != .unknown }) { scene in
                        sceneFilterChip(scene, label: scene.displayName)
                    }
                }
            }
        }
        .padding()
    }

    private func sceneFilterChip(_ scene: SceneType, label: String) -> some View {
        let isSelected = scene == selectedScene
        return Button { selectedScene = scene } label: {
            HStack(spacing: 4) {
                if scene != .unknown {
                    Image(systemName: scene.icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? .orange : .gray.opacity(0.12), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
    }

    private var poseList: some View {
        List(filteredPoses) { pose in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pose.name)
                        .font(.headline)
                    Spacer()
                    Text(pose.difficulty.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(difficultyColor(pose.difficulty).opacity(0.15), in: Capsule())
                        .foregroundStyle(difficultyColor(pose.difficulty))
                }

                Text(pose.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: pose.scene.icon)
                        .font(.caption2)
                    Text(pose.scene.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }

    private func difficultyColor(_ difficulty: PoseTemplate.Difficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}
