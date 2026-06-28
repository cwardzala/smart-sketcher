import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var ble = BLEManager()

    @State private var selectedImage: AppImage?
    @State private var photosItem: PhotosPickerItem?
    @State private var isDragTargeted = false
    @State private var showFilePicker = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: 0x09090b).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                header
                dropZone
                divider
                progressSection
                statusLine
                Spacer(minLength: 0)
                sendButton
            }
            .padding(24)
        }
        .onChange(of: photosItem) { item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let img = AppImage(data: data)
                else { return }
                selectedImage = img
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first,
                  url.startAccessingSecurityScopedResource(),
                  let data = try? Data(contentsOf: url),
                  let img = AppImage(data: data)
            else { return }
            url.stopAccessingSecurityScopedResource()
            selectedImage = img
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("smART Sketcher")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Transfer images to your smART Sketcher 2.0 projector over Bluetooth")
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0x71717a))
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0x18181b))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isDragTargeted ? Color(hex: 0x6366f1) : Color(hex: 0x27272a),
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                )

            if let img = selectedImage {
                Image(appImage: img)
                    .resizable()
                    .scaledToFit()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(20)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color(hex: 0x71717a))
                    Text("Drop an image here")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("or click to browse  ·  Photos & Files")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x71717a))
                }
            }
        }
        .frame(minHeight: 220)
        .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
        .onDrop(of: [UTType.image], isTargeted: $isDragTargeted) { providers in
            guard let provider = providers.first else { return false }
            #if os(iOS)
            _ = provider.loadObject(ofClass: UIImage.self) { obj, _ in
                DispatchQueue.main.async { selectedImage = obj as? UIImage }
            }
            #elseif os(macOS)
            _ = provider.loadObject(ofClass: NSImage.self) { obj, _ in
                DispatchQueue.main.async { selectedImage = obj as? NSImage }
            }
            #endif
            return true
        }
        .onTapGesture { showFilePicker = true }
        .contextMenu {
            PhotosPicker(selection: $photosItem, matching: .images) {
                Label("Choose from Photos", systemImage: "photo")
            }
            Button {
                showFilePicker = true
            } label: {
                Label("Browse Files", systemImage: "folder")
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(hex: 0x27272a))
            .frame(height: 1)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TRANSFER PROGRESS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x71717a))
                    .kerning(1)
                Spacer()
                if case .transferring(let line) = ble.transferState {
                    Text("\(line) / 128")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x71717a))
                } else if case .done = ble.transferState {
                    Text("128 / 128")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x71717a))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: 0x27272a))
                    Capsule()
                        .fill(Color(hex: 0x6366f1))
                        .frame(width: ble.progress > 0 ? geo.size.width * ble.progress : 0)
                }
            }
            .frame(height: 6)
            .animation(.linear(duration: 0.1), value: ble.progress)
        }
    }

    private var statusLine: some View {
        Text(ble.statusMessage)
            .font(.footnote)
            .foregroundStyle(statusColor)
            .animation(.default, value: ble.statusMessage)
    }

    private var sendButton: some View {
        Button(action: send) {
            Text("Send to Projector")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: 0x6366f1))
        .disabled(selectedImage == nil || ble.transferState.isActive)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch ble.transferState {
        case .done:                             return Color(hex: 0x22c55e)
        case .failed:                           return Color(hex: 0xef4444)
        case .transferring, .connecting, .scanning: return Color(hex: 0x6366f1)
        default:                                return Color(hex: 0x71717a)
        }
    }

    private func send() {
        guard let image = selectedImage else { return }
        Task { await ble.send(image: image) }
    }
}

// MARK: - Convenience

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8)  & 0xff) / 255,
            blue:  Double( hex        & 0xff) / 255
        )
    }
}
