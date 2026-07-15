import SwiftUI

/// Sheet for creating a new AVD.
public struct CreateAVDSheet: View {
    @ObservedObject public var viewModel: AVDManagerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedImageID: String = ""
    @State private var selectedSkin: String = "pixel_9"

    /// Only allow creating from locally installed images.
    private var installedImages: [SystemImage] {
        viewModel.systemImages.filter(\.isInstalled)
    }

    /// Curated device skins.
    private let deviceSkins: [(id: String, name: String)] = [
        ("pixel_9", "Pixel 9"),
        ("pixel_9_pro", "Pixel 9 Pro"),
        ("pixel_9_pro_fold", "Pixel 9 Pro Fold"),
        ("pixel_9_pro_xl", "Pixel 9 Pro XL"),
        ("pixel_9a", "Pixel 9a"),
        ("pixel_tablet", "Pixel Tablet"),
        ("wearos_large_round", "Wear OS"),
        ("tv_1080p", "TV (1080p)"),
        ("tv_4k", "TV (4K)"),
        ("tv_720p", "TV (720p)"),
    ]

    public init(viewModel: AVDManagerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding()
                .background(.ultraThinMaterial)

            form
                .padding()

            Spacer()

            footer
                .padding()
                .background(.ultraThinMaterial)
        }
        .frame(minWidth: 480, minHeight: 400)
        .background(.thinMaterial)
        .onAppear {
            if selectedImageID.isEmpty, let first = installedImages.first {
                selectedImageID = first.id
            }
        }
    }

    private var header: some View {
        HStack {
            Text(NSLocalizedString("create_avd_title", comment: ""))
                .font(.title2.weight(.bold))
            Spacer()
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AVD Name
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("avd_name", comment: ""))
                    .font(.callout.weight(.medium))
                TextField("MyAVD", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // System Image
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("system_image", comment: ""))
                    .font(.callout.weight(.medium))
                if installedImages.isEmpty {
                    Text("没有本地已安装的系统镜像")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    Picker(selection: $selectedImageID) {
                        ForEach(installedImages) { image in
                            Text(image.localizedDescription)
                                .tag(image.id)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.radioGroup)
                }
            }

            // Device Skin
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("device_skin", comment: ""))
                    .font(.callout.weight(.medium))
                Picker(selection: $selectedSkin) {
                    ForEach(deviceSkins, id: \.id) { skin in
                        Text(skin.name).tag(skin.id)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(NSLocalizedString("cancel", comment: "")) {
                dismiss()
            }
            .buttonStyle(.glass)

            Button(NSLocalizedString("create", comment: "")) {
                create()
            }
            .buttonStyle(.glassProminent)
            .disabled(name.isEmpty || selectedImageID.isEmpty)
        }
    }

    private func create() {
        guard let image = installedImages.first(where: { $0.id == selectedImageID }) else { return }
        Task {
            await viewModel.create(name: name, systemImage: image, skin: selectedSkin)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#if DEBUG
#Preview {
    CreateAVDSheet(viewModel: AVDManagerViewModel())
}
#endif
