import SwiftUI
import AppKit

enum TabIcon: String, Codable, CaseIterable, Identifiable {
    case automatic, terminal, folder, claude, codex, opencode, docker, github
    case code, server, database, ssh, globe, python, node, rust
    var id: String { rawValue }
    var name: String {
        switch self {
        case .automatic: "Automatic"
        case .terminal: "Terminal"
        case .folder: "Folder"
        case .claude: "Claude"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        case .docker: "Docker"
        case .github: "GitHub"
        case .code: "Code"
        case .server: "Server"
        case .database: "Database"
        case .ssh: "SSH"
        case .globe: "Browser"
        case .python: "Python"
        case .node: "Node.js"
        case .rust: "Rust"
        }
    }
    var asset: String? {
        switch self {
        case .claude, .codex, .opencode, .docker, .github: rawValue
        default: nil
        }
    }
    var symbol: String {
        switch self {
        case .automatic: "sparkles"
        case .folder: "folder.fill"
        case .code, .node: "chevron.left.forwardslash.chevron.right"
        case .server: "server.rack"
        case .database: "externaldrive.fill"
        case .ssh: "network"
        case .globe: "globe"
        case .python: "curlybraces"
        case .rust: "gearshape.fill"
        default: "terminal.fill"
        }
    }
    var background: Color {
        switch self {
        case .claude: Color(hex: 0xc4775d)
        case .codex: Color(hex: 0x202624)
        case .opencode: Color(hex: 0x252525)
        case .docker: Color(hex: 0x1685ce)
        case .github: Color(hex: 0x28282d)
        case .python: Color(hex: 0x3d6687)
        case .node: Color(hex: 0x47733a)
        case .rust: Color(hex: 0x9e5b42)
        default: Color.white.opacity(0.08)
        }
    }
}

struct TabAppearance: Codable, Equatable {
    var preset: TabIcon = .automatic
    var customImage: Data? = nil
}

enum IconImportError: LocalizedError {
    case tooLarge, invalidImage
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Choose an image smaller than 20 MB."
        case .invalidImage: "This image couldn’t be opened. Try a PNG, JPEG, or another supported image."
        }
    }
}

@MainActor
enum IconImages {
    static let maximumFileSize = 20 * 1024 * 1024
    private static var cache: [String: NSImage] = [:]
    static func bundled(_ name: String) -> NSImage? {
        if let image = cache[name] { return image }
        guard let url = TermiResources.bundle.resourceURL?.appendingPathComponent("Icons/\(name).png"), let image = NSImage(contentsOf: url), image.isValid else { return nil }
        cache[name] = image
        return image
    }
    static func normalizedPNG(_ data: Data) throws -> Data {
        guard data.count <= maximumFileSize else { throw IconImportError.tooLarge }
        guard let source = NSImage(data: data), source.isValid, source.size.width > 0, source.size.height > 0 else { throw IconImportError.invalidImage }
        let size = 128
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw IconImportError.invalidImage }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let scale = min(CGFloat(size) / source.size.width, CGFloat(size) / source.size.height)
        let width = source.size.width * scale
        let height = source.size.height * scale
        source.draw(in: NSRect(x: (CGFloat(size) - width) / 2, y: (CGFloat(size) - height) / 2, width: width, height: height), from: .zero, operation: .sourceOver, fraction: 1)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw IconImportError.invalidImage }
        return png
    }
}

struct TabIconView: View {
    let appearance: TabAppearance
    var fallback: TabIcon = .terminal
    var selected = false
    var size: CGFloat = 27
    private var preset: TabIcon { appearance.preset == .automatic ? fallback : appearance.preset }
    var body: some View {
        ZStack {
            Circle().fill(preset == .terminal && selected ? Color.black.opacity(0.5) : preset.background)
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.7))
                .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center)))
            if let data = appearance.customImage, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit().padding(size * 0.1)
            } else if let asset = preset.asset, let image = IconImages.bundled(asset) {
                Image(nsImage: image).resizable().renderingMode(.template).scaledToFit().padding(size * 0.23).foregroundStyle(.white)
            } else {
                Image(systemName: preset.symbol).font(.system(size: size * 0.47, weight: .medium)).foregroundStyle(Palette.text)
            }
        }.frame(width: size, height: size).clipShape(Circle())
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }
}

struct IconPicker: View {
    @ObservedObject var store: AppStore
    @ObservedObject var tab: Tab
    @State private var query = ""
    @State private var errorMessage: String?
    var choices: [TabIcon] { query.isEmpty ? TabIcon.allCases : TabIcon.allCases.filter { $0.name.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                SessionBadge(tab: tab, selected: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tab icon").font(.system(size: 20, weight: .semibold))
                    Text(tab.title).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer()
                IconButton(icon: "xmark", help: "Close icon picker") { store.iconPickerTab = nil }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.dim)
                TextField("Search icons", text: $query).textFieldStyle(.plain)
            }.font(.system(size: 12)).padding(10).background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4), spacing: 9) {
                    ForEach(choices) { icon in
                        let active = tab.appearance.customImage == nil && tab.appearance.preset == icon
                        Button { store.setIcon(icon, for: tab); errorMessage = nil } label: {
                            VStack(spacing: 9) {
                                TabIconView(appearance: TabAppearance(preset: icon), fallback: icon == .automatic ? .terminal : icon, size: 34)
                                Text(icon.name).font(.system(size: 10)).foregroundStyle(active ? Palette.text : Palette.muted)
                            }.frame(maxWidth: .infinity).frame(height: 82)
                                .background(active ? Color.white.opacity(0.1) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(active ? .white.opacity(0.3) : Palette.line))
                                .overlay(alignment: .topTrailing) {
                                    if active { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Palette.text).padding(6) }
                                }.contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Use \(icon.name) icon")
                    }
                }
                if choices.isEmpty { Text("No matching icons").font(.system(size: 12)).foregroundStyle(Palette.muted).padding(30) }
            }.frame(height: 300)
            Divider().overlay(Palette.line)
            HStack(spacing: 12) {
                Button("Choose image…", systemImage: "photo.badge.plus") {
                    do { try store.chooseCustomIcon(for: tab); errorMessage = nil }
                    catch { errorMessage = error.localizedDescription }
                }.buttonStyle(.bordered)
                Spacer()
                if tab.appearance.customImage != nil { Text("Custom image").font(.system(size: 10)).foregroundStyle(Palette.muted) }
                Button("Done") { store.iconPickerTab = nil }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(Palette.selected)
            }
            if let errorMessage { Text(errorMessage).font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
        }.padding(24).frame(width: 420).background(Palette.sidebar).foregroundStyle(Palette.text).preferredColorScheme(.dark)
    }
}
