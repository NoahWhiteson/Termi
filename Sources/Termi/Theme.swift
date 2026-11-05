import SwiftUI
import AppKit

enum Palette {
    static let background = Color(hex: 0x090a08)
    static let sidebar = Color(hex: 0x34332f)
    static let elevated = Color(hex: 0x45443f)
    static let selected = Color(hex: 0x56554e)
    static let line = Color.white.opacity(0.075)
    static let text = Color(hex: 0xe5e4de)
    static let muted = Color(hex: 0xa3a19a)
    static let dim = Color(hex: 0x77756f)
    static let accent = Color(hex: 0xd8d7d0)
    static let terminal = NSColor(hex: 0x090a08)
}

/// AppKit samples the desktop behind the window, not a flat SwiftUI background.
struct DesktopMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

extension View {
    @ViewBuilder
    func nativeGlass<S: Shape>(in shape: S, tint: Color = .white.opacity(0.04), interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 0.7))
        }
    }

}

/// A separate AppKit background prevents glass sampling from including a tab's
/// own foreground. Tab labels and icons stay in the normal SwiftUI drawing layer.
struct TabGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 20
            glass.tintColor = NSColor.white.withAlphaComponent(0.045)
            return glass
        }
        let material = NSVisualEffectView()
        material.material = .selection
        material.blendingMode = .withinWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = 20
        material.layer?.masksToBounds = true
        return material
    }
    func updateNSView(_ view: NSView, context: Context) {}
}

struct GlassCircleButton: View {
    let icon: String
    let help: String
    var size: CGFloat = 40
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: icon == "plus" ? 22 : 19, weight: .regular))
                .foregroundStyle(Palette.text)
                .frame(width: size, height: size)
                .nativeGlass(in: Circle(), tint: .white.opacity(0.07), interactive: true)
                .contentShape(Circle())
        }.buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

struct IconButton: View {
    let icon: String
    let help: String
    var size: CGFloat = 28
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovered ? Palette.text : Palette.muted)
                .frame(width: size, height: size)
                .background(hovered ? Color.white.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help(help).accessibilityLabel(help).onHover { hovered = $0 }
    }
}

struct Shortcut: View {
    let label: String
    var body: some View {
        Text(label).font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.dim).padding(.horizontal, 5).padding(.vertical, 3)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.line))
    }
}
