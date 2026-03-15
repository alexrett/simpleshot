import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Gradient Presets

struct GradientPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
}

let gradientPresets: [GradientPreset] = [
    GradientPreset(id: "purple-blue", name: "Twilight", colors: [Color(hex: "#4338ca"), Color(hex: "#2563eb"), Color(hex: "#0891b2")], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: "pink-orange", name: "Sunset", colors: [Color(hex: "#be185d"), Color(hex: "#e11d48"), Color(hex: "#f97316")], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: "green-teal", name: "Forest", colors: [Color(hex: "#065f46"), Color(hex: "#0d9488"), Color(hex: "#2dd4bf")], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: "dark-slate", name: "Slate", colors: [Color(hex: "#0f172a"), Color(hex: "#1e293b"), Color(hex: "#334155")], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: "warm-amber", name: "Amber", colors: [Color(hex: "#78350f"), Color(hex: "#b45309"), Color(hex: "#f59e0b")], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: "ocean", name: "Ocean", colors: [Color(hex: "#0c4a6e"), Color(hex: "#0369a1"), Color(hex: "#38bdf8")], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: "lavender", name: "Lavender", colors: [Color(hex: "#581c87"), Color(hex: "#7c3aed"), Color(hex: "#c4b5fd")], startPoint: .topLeading, endPoint: .bottomTrailing),
    GradientPreset(id: "noir", name: "Noir", colors: [Color(hex: "#09090b"), Color(hex: "#18181b"), Color(hex: "#27272a")], startPoint: .top, endPoint: .bottom),
    GradientPreset(id: "candy", name: "Candy", colors: [Color(hex: "#ec4899"), Color(hex: "#8b5cf6"), Color(hex: "#3b82f6")], startPoint: .leading, endPoint: .trailing),
    GradientPreset(id: "emerald", name: "Emerald", colors: [Color(hex: "#064e3b"), Color(hex: "#059669"), Color(hex: "#34d399")], startPoint: .topLeading, endPoint: .bottomTrailing),
]

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var clipboardImage: NSImage? = nil
    @Published var selectedPreset: GradientPreset = gradientPresets[0]
    @Published var padding: CGFloat = 64
    @Published var cornerRadius: CGFloat = 0
    @Published var shadow: Bool = true

    func loadFromClipboard() {
        let pb = NSPasteboard.general
        // Try PNG first — preserves alpha from window screenshots
        if let data = pb.data(forType: .png), let img = NSImage(data: data) {
            clipboardImage = img
            return
        }
        if let data = pb.data(forType: .tiff), let img = NSImage(data: data) {
            clipboardImage = img
            return
        }
        if let objects = pb.readObjects(forClasses: [NSImage.self], options: nil),
           let img = objects.first as? NSImage {
            clipboardImage = img
        }
    }

    func renderFinal() -> NSImage? {
        guard let screenshot = clipboardImage,
              let cgScreenshot = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let imgW = CGFloat(cgScreenshot.width)
        let imgH = CGFloat(cgScreenshot.height)
        let totalW = Int(imgW + padding * 2)
        let totalH = Int(imgH + padding * 2)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: totalW,
            height: totalH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let fullRect = CGRect(x: 0, y: 0, width: totalW, height: totalH)

        // 1. Draw gradient background
        let cgColors = selectedPreset.colors.map { NSColor($0).cgColor }
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors as CFArray, locations: nil) {
            let (start, end) = gradientPoints(for: fullRect)
            ctx.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // 2. Draw shadow
        let imgRect = CGRect(x: padding, y: padding, width: imgW, height: imgH)
        if shadow {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
        }

        // 3. Draw screenshot with optional corner radius
        if cornerRadius > 0 {
            ctx.saveGState()
            let clipPath = CGPath(roundedRect: imgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.addPath(clipPath)
            ctx.clip()
            ctx.draw(cgScreenshot, in: imgRect)
            ctx.restoreGState()
        } else {
            ctx.draw(cgScreenshot, in: imgRect)
        }

        if shadow {
            ctx.restoreGState()
        }

        guard let resultCG = ctx.makeImage() else { return nil }
        return NSImage(cgImage: resultCG, size: NSSize(width: totalW, height: totalH))
    }

    private func gradientPoints(for rect: CGRect) -> (CGPoint, CGPoint) {
        let p = selectedPreset
        if p.startPoint == .topLeading && p.endPoint == .bottomTrailing {
            return (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY))
        }
        if p.startPoint == .top && p.endPoint == .bottom {
            return (CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.midX, y: rect.minY))
        }
        if p.startPoint == .leading && p.endPoint == .trailing {
            return (CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.midY))
        }
        return (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY))
    }

    func copyToClipboard() {
        guard let img = renderFinal(), let tiff = img.tiffRepresentation else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(tiff, forType: .tiff)
    }

    func saveToDisk() {
        guard let img = renderFinal(),
              let tiff = img.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = "screenshot.png"
        if panel.runModal() == .OK, let url = panel.url {
            try? pngData.write(to: url)
        }
    }
}

// MARK: - Preview View (the rendered result)

struct PreviewCanvas: View {
    @ObservedObject var state: AppState

    private var aspectRatio: CGFloat {
        guard let img = state.clipboardImage else { return 16.0 / 9.0 }
        let w = img.size.width + state.padding * 2
        let h = img.size.height + state.padding * 2
        return w / h
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: state.selectedPreset.colors,
                startPoint: state.selectedPreset.startPoint,
                endPoint: state.selectedPreset.endPoint
            )

            if let img = state.clipboardImage {
                // Scale padding proportionally for preview
                let scale = min(500.0 / (img.size.width + state.padding * 2), 1.0)
                let previewPadding = state.padding * scale

                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(img.size.width / img.size.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: state.cornerRadius))
                    .shadow(color: state.shadow ? .black.opacity(0.4) : .clear, radius: 16, x: 0, y: 8)
                    .padding(previewPadding)
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        HStack(spacing: 0) {
            // Preview area
            VStack {
                if state.clipboardImage != nil {
                    PreviewCanvas(state: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(20)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44))
                            .foregroundStyle(.tertiary)
                        Text("Take a screenshot (⌘⇧4 + Space)")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                        Text("then press Paste below")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))

            Divider()

            // Controls sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Paste
                    Button(action: { state.loadFromClipboard() }) {
                        Label("Paste from Clipboard", systemImage: "clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("v")
                    .controlSize(.large)

                    Divider()

                    // Gradient presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                            ForEach(gradientPresets) { preset in
                                Button(action: { state.selectedPreset = preset }) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LinearGradient(
                                            colors: preset.colors,
                                            startPoint: preset.startPoint,
                                            endPoint: preset.endPoint
                                        ))
                                        .frame(width: 44, height: 32)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(state.selectedPreset.id == preset.id ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(preset.name)
                            }
                        }
                    }

                    Divider()

                    // Padding
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Padding")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(state.padding))px")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Slider(value: $state.padding, in: 16...160, step: 8)

                        HStack(spacing: 6) {
                            ForEach([32, 48, 64, 96, 128], id: \.self) { val in
                                Button("\(val)") {
                                    state.padding = CGFloat(val)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .font(.system(size: 10, design: .monospaced))
                            }
                        }
                    }

                    // Corner radius
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Corner Radius")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(state.cornerRadius))px")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Slider(value: $state.cornerRadius, in: 0...32, step: 2)
                    }

                    // Shadow toggle
                    Toggle("Drop Shadow", isOn: $state.shadow)
                        .font(.system(size: 12, weight: .medium))

                    Divider()

                    // Actions
                    VStack(spacing: 8) {
                        Button(action: { state.copyToClipboard() }) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                        .controlSize(.large)
                        .disabled(state.clipboardImage == nil)

                        Button(action: { state.saveToDisk() }) {
                            Label("Save as PNG", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("s")
                        .controlSize(.large)
                        .disabled(state.clipboardImage == nil)
                    }
                }
                .padding(16)
            }
            .frame(width: 240)
        }
        .frame(minWidth: 700, minHeight: 480)
        .onAppear {
            state.loadFromClipboard()
        }
    }
}

// MARK: - App

@main
struct SimpleShotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 860, height: 560)
    }
}
