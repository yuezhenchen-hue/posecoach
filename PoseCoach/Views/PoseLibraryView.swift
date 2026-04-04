import SwiftUI
import Vision

/// Pose 灵感库视图：精美图片网格 + 场景分类
struct PoseLibraryView: View {
    @State private var selectedCategory: InspirationCategory?
    @State private var selectedTemplate: PoseTemplate?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    categoryGrid
                    if let cat = selectedCategory {
                        templateSection(category: cat)
                    } else {
                        allTemplatesSection
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Pose 灵感")
            .searchable(text: $searchText, prompt: "搜索姿势...")
            .sheet(item: $selectedTemplate) { template in
                TemplateDetailView(template: template)
            }
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryChip(nil, name: "全部", icon: "square.grid.2x2.fill", color: .orange)
                ForEach(InspirationCategory.allCategories) { cat in
                    categoryChip(cat, name: cat.name, icon: cat.icon, color: cat.color)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 4)
    }

    private func categoryChip(_ category: InspirationCategory?, name: String, icon: String, color: Color) -> some View {
        let isSelected = selectedCategory?.id == category?.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .frame(width: 50, height: 50)
                    .background(isSelected ? color : color.opacity(0.15), in: Circle())
                    .foregroundStyle(isSelected ? .white : color)
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? color : .secondary)
            }
        }
    }

    // MARK: - All Templates (Grouped by Scene)

    private var allTemplatesSection: some View {
        LazyVStack(spacing: 24) {
            ForEach(InspirationCategory.allCategories) { cat in
                if !filteredTemplates(cat.templates).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: cat.icon).foregroundStyle(cat.color)
                            Text(cat.name).font(.headline)
                            Spacer()
                            Text("\(filteredTemplates(cat.templates).count)个姿势")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        templateGrid(filteredTemplates(cat.templates))
                    }
                }
            }
        }
    }

    // MARK: - Single Category

    private func templateSection(category: InspirationCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon).foregroundStyle(category.color)
                Text(category.name).font(.headline)
                Spacer()
                Text("\(filteredTemplates(category.templates).count)个姿势")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            templateGrid(filteredTemplates(category.templates))
        }
    }

    // MARK: - Template Grid

    private func templateGrid(_ templates: [PoseTemplate]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(templates) { template in
                templateCard(template)
            }
        }
        .padding(.horizontal)
    }

    private func templateCard(_ template: PoseTemplate) -> some View {
        Button { selectedTemplate = template } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let imgName = template.imageName {
                        Image(imgName)
                            .resizable().scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: template.gradientColors,
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(height: 180)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: template.scene.icon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(template.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Text(template.difficulty.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(difficultyColor(template.difficulty).opacity(0.9), in: Capsule())
                        Text(template.personCount.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.5), in: Capsule())
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(template.description.components(separatedBy: "\n").first ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
    }

    // MARK: - Helpers

    private func filteredTemplates(_ templates: [PoseTemplate]) -> [PoseTemplate] {
        guard !searchText.isEmpty else { return templates }
        return templates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func difficultyColor(_ d: PoseTemplate.Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    let template: PoseTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var showPoseCamera = false
    @State private var silhouetteImage: UIImage?
    @State private var templateJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]?
    @State private var isLoadingSilhouette = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    templatePreview
                    descriptionSection
                    actionButtons
                    tipsSection
                }
                .padding()
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showPoseCamera) {
                PoseOverlayCameraView(
                    template: template,
                    silhouetteImage: silhouetteImage,
                    templateJoints: templateJoints
                )
            }
        }
    }

    private var templatePreview: some View {
        ZStack {
            if let imgName = template.imageName {
                Image(imgName).resizable().scaledToFill()
                    .frame(height: 300).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                LinearGradient(
                    colors: template.gradientColors,
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: template.scene.icon)
                            .font(.system(size: 48))
                        Text(template.name)
                            .font(.title2.bold())
                        Text("添加模板图片后\n将自动提取人物轮廓")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                }
            }

            if let sil = silhouetteImage {
                Image(uiImage: sil).resizable().scaledToFill()
                    .frame(height: 300).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(0.7)
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(template.scene.displayName, systemImage: template.scene.icon)
                    .font(.caption).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.orange, in: Capsule())
                Label(template.personCount.rawValue, systemImage: "person.fill")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.gray.opacity(0.12), in: Capsule())
                Label(template.difficulty.rawValue, systemImage: "chart.bar.fill")
                    .font(.caption).foregroundStyle(difficultyColor(template.difficulty))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(difficultyColor(template.difficulty).opacity(0.12), in: Capsule())
            }

            Text(template.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showPoseCamera = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                    Text("照着这个姿势拍")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.orange, in: RoundedRectangle(cornerRadius: 12))
            }

            if template.imageName != nil && silhouetteImage == nil {
                Button {
                    extractSilhouette()
                } label: {
                    HStack(spacing: 8) {
                        if isLoadingSilhouette { ProgressView().tint(.orange) }
                        else { Image(systemName: "person.crop.rectangle") }
                        Text(isLoadingSilhouette ? "提取轮廓中..." : "提取人物轮廓")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoadingSilhouette)
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍摄技巧").font(.headline)
            let tips = template.description.components(separatedBy: "\n")
            ForEach(tips.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "\(i + 1).circle.fill")
                        .foregroundStyle(.orange).font(.caption)
                    Text(tips[i]).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func extractSilhouette() {
        guard let imgName = template.imageName, let img = UIImage(named: imgName) else { return }
        isLoadingSilhouette = true
        DispatchQueue.global(qos: .userInitiated).async {
            let sil = SilhouetteExtractor.extractSilhouette(from: img, style: .outline)
            let joints = SilhouetteExtractor.extractPoseJoints(from: img)
            DispatchQueue.main.async {
                silhouetteImage = sil
                templateJoints = joints
                isLoadingSilhouette = false
            }
        }
    }

    private func difficultyColor(_ d: PoseTemplate.Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}
