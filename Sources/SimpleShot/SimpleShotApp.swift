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

// MARK: - Annotation Model

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pointer, arrow, circle, rectangle, number, text
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pointer: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .circle: "circle"
        case .rectangle: "rectangle"
        case .number: "1.circle.fill"
        case .text: "character.textbox"
        }
    }
}

struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var startNorm: CGPoint // 0...1 normalized, origin top-left
    var endNorm: CGPoint
    var number: Int = 0
    var text: String = ""
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 4
}

let annotationColorOptions: [(String, NSColor)] = [
    ("Red", .systemRed),
    ("Orange", .systemOrange),
    ("Yellow", .systemYellow),
    ("Green", .systemGreen),
    ("Blue", .systemBlue),
    ("White", .white),
    ("Black", .black),
]

// MARK: - Aspect Ratio Presets

enum AspectRatioOption: String, CaseIterable, Identifiable {
    case free = "Free"
    case r16x9 = "16:9"
    case r4x3 = "4:3"
    case r3x2 = "3:2"
    case r1x1 = "1:1"
    case r9x16 = "9:16"

    var id: String { rawValue }

    /// nil means free (follow image)
    var ratio: CGFloat? {
        switch self {
        case .free: nil
        case .r16x9: 16.0 / 9.0
        case .r4x3: 4.0 / 3.0
        case .r3x2: 3.0 / 2.0
        case .r1x1: 1.0
        case .r9x16: 9.0 / 16.0
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var clipboardImage: NSImage? = nil
    @Published var selectedPreset: GradientPreset = gradientPresets[0]
    @Published var padding: CGFloat = 64
    @Published var cornerRadius: CGFloat = 0
    @Published var shadow: Bool = true
    @Published var contentBackground: NSColor? = nil // nil = transparent
    @Published var aspectRatioOption: AspectRatioOption = .free

    // Annotations
    @Published var annotations: [Annotation] = []
    @Published var currentTool: AnnotationTool = .pointer
    @Published var annotationColor: NSColor = .systemRed
    @Published var annotationText: String = "Label"
    @Published var strokeWidth: CGFloat = 4
    @Published var nextNumber: Int = 1

    func loadFromClipboard() {
        let pb = NSPasteboard.general

        // Check for file URLs first (e.g. files copied in Finder with ⌘C)
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingContentsConformToTypes: NSImage.imageTypes
        ]) as? [URL], let url = urls.first {
            if loadFromFile(url: url) { return }
        }

        if let data = pb.data(forType: .png), let img = NSImage(data: data) {
            setImage(img)
            return
        }
        if let data = pb.data(forType: .tiff), let img = NSImage(data: data) {
            setImage(img)
            return
        }
        if let objects = pb.readObjects(forClasses: [NSImage.self], options: nil),
           let img = objects.first as? NSImage {
            setImage(img)
        }
    }

    @discardableResult
    func loadFromFile(url: URL) -> Bool {
        guard let img = NSImage(contentsOf: url) else { return false }
        // For PDFs and multi-page formats, NSImage loads the first page
        setImage(img)
        return true
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .image, .png, .jpeg, .tiff, .gif, .bmp, .heic, .webP, .pdf, .svg, .icns
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            loadFromFile(url: url)
        }
    }

    func setImage(_ img: NSImage) {
        clipboardImage = img
        annotations.removeAll()
        nextNumber = 1
    }

    var outputSize: CGSize {
        guard let img = clipboardImage else { return .zero }
        let baseW = img.size.width + padding * 2
        let baseH = img.size.height + padding * 2
        guard let targetRatio = aspectRatioOption.ratio else {
            return CGSize(width: baseW, height: baseH)
        }
        // Expand canvas to match target aspect ratio while keeping image fully visible
        let currentRatio = baseW / baseH
        if currentRatio > targetRatio {
            // Too wide — increase height
            return CGSize(width: baseW, height: baseW / targetRatio)
        } else {
            // Too tall — increase width
            return CGSize(width: baseH * targetRatio, height: baseH)
        }
    }

    func undoAnnotation() {
        guard let last = annotations.popLast() else { return }
        if last.tool == .number { nextNumber = max(1, nextNumber - 1) }
    }

    func clearAnnotations() {
        annotations.removeAll()
        nextNumber = 1
    }

    func renderFinal() -> NSImage? {
        guard let screenshot = clipboardImage,
              let cgScreenshot = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let imgW = CGFloat(cgScreenshot.width)
        let imgH = CGFloat(cgScreenshot.height)
        let size = outputSize
        let totalW = Int(size.width)
        let totalH = Int(size.height)

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

        // 2. Draw shadow — center the image in the canvas
        let imgRect = CGRect(
            x: (CGFloat(totalW) - imgW) / 2,
            y: (CGFloat(totalH) - imgH) / 2,
            width: imgW,
            height: imgH
        )
        if shadow {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
        }

        // 3. Draw content background fill (useful for PDFs/transparent images)
        if let bg = contentBackground {
            ctx.saveGState()
            if cornerRadius > 0 {
                let clipPath = CGPath(roundedRect: imgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                ctx.addPath(clipPath)
                ctx.clip()
            }
            ctx.setFillColor(bg.cgColor)
            ctx.fill(imgRect)
            ctx.restoreGState()
        }

        // 4. Draw screenshot with optional corner radius
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

        // 4. Draw annotations
        renderAnnotations(ctx: ctx, totalW: CGFloat(totalW), totalH: CGFloat(totalH))

        guard let resultCG = ctx.makeImage() else { return nil }
        return NSImage(cgImage: resultCG, size: NSSize(width: totalW, height: totalH))
    }

    // MARK: - CG Annotation Rendering

    private func renderAnnotations(ctx: CGContext, totalW: CGFloat, totalH: CGFloat) {
        for ann in annotations {
            // Convert normalized coords to CG coords (flip Y: CG origin is bottom-left)
            let sx = ann.startNorm.x * totalW
            let sy = (1 - ann.startNorm.y) * totalH
            let ex = ann.endNorm.x * totalW
            let ey = (1 - ann.endNorm.y) * totalH
            let start = CGPoint(x: sx, y: sy)
            let end = CGPoint(x: ex, y: ey)

            switch ann.tool {
            case .arrow:
                drawArrowCG(ctx, from: start, to: end, color: ann.color, strokeWidth: ann.strokeWidth)
            case .circle:
                drawEllipseCG(ctx, from: start, to: end, color: ann.color, strokeWidth: ann.strokeWidth)
            case .rectangle:
                drawRectCG(ctx, from: start, to: end, color: ann.color, strokeWidth: ann.strokeWidth)
            case .number:
                drawNumberCG(ctx, center: start, number: ann.number, color: ann.color, totalW: totalW)
            case .text:
                drawTextCG(ctx, at: start, text: ann.text, color: ann.color, totalW: totalW)
            case .pointer:
                break
            }
        }
    }

    private func drawArrowCG(_ ctx: CGContext, from start: CGPoint, to end: CGPoint, color: NSColor, strokeWidth: CGFloat) {
        let headLength = strokeWidth * 5
        let headAngle: CGFloat = .pi / 6
        let angle = atan2(end.y - start.y, end.x - start.x)

        let p1 = CGPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
        let p2 = CGPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))
        // Line ends at the midpoint of the arrowhead base
        let lineEnd = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)

        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.move(to: start)
        ctx.addLine(to: lineEnd)
        ctx.strokePath()

        // Arrowhead
        ctx.setFillColor(color.cgColor)
        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()
    }

    private func drawEllipseCG(_ ctx: CGContext, from start: CGPoint, to end: CGPoint, color: NSColor, strokeWidth: CGFloat) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.strokeEllipse(in: rect)
        ctx.restoreGState()
    }

    private func drawRectCG(_ ctx: CGContext, from start: CGPoint, to end: CGPoint, color: NSColor, strokeWidth: CGFloat) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.stroke(rect)
        ctx.restoreGState()
    }

    private func drawNumberCG(_ ctx: CGContext, center: CGPoint, number: Int, color: NSColor, totalW: CGFloat) {
        let radius = totalW * 0.016
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

        let fontSize = radius * 1.3
        let font = CTFontCreateWithName("Helvetica Neue" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: "\(number)", attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        ctx.textPosition = CGPoint(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2 + bounds.height * 0.15)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private func drawTextCG(_ ctx: CGContext, at point: CGPoint, text: String, color: NSColor, totalW: CGFloat) {
        let fontSize = totalW * 0.022
        let font = CTFontCreateWithName("Helvetica Neue" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)
        ctx.saveGState()
        ctx.textPosition = point
        CTLineDraw(line, ctx)
        ctx.restoreGState()
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

// MARK: - Preview Canvas with Annotation Overlay

struct PreviewCanvas: View {
    @ObservedObject var state: AppState
    @State private var inProgress: Annotation?

    private var aspectRatio: CGFloat {
        let size = state.outputSize
        guard size.height > 0 else { return 16.0 / 9.0 }
        return size.width / size.height
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: state.selectedPreset.colors,
                startPoint: state.selectedPreset.startPoint,
                endPoint: state.selectedPreset.endPoint
            )

            if let img = state.clipboardImage {
                let scale = min(500.0 / (img.size.width + state.padding * 2), 1.0)
                let previewPadding = state.padding * scale

                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(img.size.width / img.size.height, contentMode: .fit)
                    .background(
                        state.contentBackground.map { Color(nsColor: $0) } ?? Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: state.cornerRadius))
                    .shadow(color: state.shadow ? .black.opacity(0.4) : .clear, radius: 16, x: 0, y: 8)
                    .padding(previewPadding)
            }

            // Annotation overlay
            GeometryReader { geo in
                let allAnnotations = state.annotations + (inProgress.map { [$0] } ?? [])
                Canvas { gfx, size in
                    for ann in allAnnotations {
                        let start = CGPoint(x: ann.startNorm.x * size.width, y: ann.startNorm.y * size.height)
                        let end = CGPoint(x: ann.endNorm.x * size.width, y: ann.endNorm.y * size.height)
                        let color = Color(nsColor: ann.color)
                        let sw = ann.strokeWidth * (size.width / state.outputSize.width)

                        switch ann.tool {
                        case .arrow:
                            drawArrowPreview(gfx, from: start, to: end, color: color, strokeWidth: sw)
                        case .circle:
                            let rect = rectFrom(start, end)
                            gfx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: sw)
                        case .rectangle:
                            let rect = rectFrom(start, end)
                            gfx.stroke(Path(rect), with: .color(color), lineWidth: sw)
                        case .number:
                            let r = size.width * 0.016
                            let circle = Path(ellipseIn: CGRect(x: start.x - r, y: start.y - r, width: r * 2, height: r * 2))
                            gfx.fill(circle, with: .color(color))
                            let text = Text("\(ann.number)").font(.system(size: r * 1.3, weight: .bold)).foregroundColor(.white)
                            gfx.draw(text, at: start)
                        case .text:
                            let fontSize = size.width * 0.022
                            let text = Text(ann.text).font(.system(size: fontSize, weight: .semibold)).foregroundColor(color)
                            gfx.draw(text, at: start, anchor: .bottomLeading)
                        case .pointer:
                            break
                        }
                    }
                }
                .allowsHitTesting(false)

                // Gesture layer
                if state.currentTool != .pointer {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let startN = CGPoint(
                                        x: clamp(value.startLocation.x / geo.size.width),
                                        y: clamp(value.startLocation.y / geo.size.height)
                                    )
                                    let curN = CGPoint(
                                        x: clamp(value.location.x / geo.size.width),
                                        y: clamp(value.location.y / geo.size.height)
                                    )

                                    var ann = Annotation(
                                        tool: state.currentTool,
                                        startNorm: startN,
                                        endNorm: state.currentTool == .number || state.currentTool == .text ? startN : curN,
                                        color: state.annotationColor,
                                        strokeWidth: state.strokeWidth
                                    )
                                    if state.currentTool == .number {
                                        ann.number = state.nextNumber
                                    }
                                    if state.currentTool == .text {
                                        ann.text = state.annotationText
                                    }
                                    inProgress = ann
                                }
                                .onEnded { value in
                                    guard var ann = inProgress else { return }
                                    let endN = CGPoint(
                                        x: clamp(value.location.x / geo.size.width),
                                        y: clamp(value.location.y / geo.size.height)
                                    )
                                    if ann.tool != .number && ann.tool != .text {
                                        ann.endNorm = endN
                                    }
                                    state.annotations.append(ann)
                                    if ann.tool == .number { state.nextNumber += 1 }
                                    inProgress = nil
                                }
                        )
                        .onHover { inside in
                            if inside && state.currentTool != .pointer {
                                NSCursor.crosshair.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func drawArrowPreview(_ gfx: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color, strokeWidth: CGFloat) {
        let headLength = strokeWidth * 5
        let headAngle: CGFloat = .pi / 6
        let angle = atan2(end.y - start.y, end.x - start.x)

        let p1 = CGPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
        let p2 = CGPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))
        let lineEnd = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)

        var linePath = Path()
        linePath.move(to: start)
        linePath.addLine(to: lineEnd)
        gfx.stroke(linePath, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

        var head = Path()
        head.move(to: end)
        head.addLine(to: p1)
        head.addLine(to: p2)
        head.closeSubpath()
        gfx.fill(head, with: .color(color))
    }

    private func rectFrom(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}

private func clamp(_ v: CGFloat) -> CGFloat {
    min(max(v, 0), 1)
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
                        Text("Drop an image here")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                        Text("or paste from clipboard / open a file")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
            .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                // Handle file URL drops
                if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                        guard let data = data as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        DispatchQueue.main.async {
                            state.loadFromFile(url: url)
                        }
                    }
                    return true
                }
                // Handle direct image data drops
                if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, _ in
                        guard let data = data as? Data, let img = NSImage(data: data) else { return }
                        DispatchQueue.main.async {
                            state.setImage(img)
                        }
                    }
                    return true
                }
                return false
            }

            Divider()

            // Controls sidebar
            VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Open / Paste
                    Button(action: { state.openFile() }) {
                        Label("Open File", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("o")
                    .controlSize(.large)

                    Button(action: { state.loadFromClipboard() }) {
                        Label("Paste from Clipboard", systemImage: "clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("v")
                    .controlSize(.large)

                    Divider()

                    // Annotation tools
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Annotate")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            ForEach(AnnotationTool.allCases) { tool in
                                Button(action: { state.currentTool = tool }) {
                                    Image(systemName: tool.icon)
                                        .font(.system(size: 14))
                                        .frame(width: 28, height: 28)
                                        .background(state.currentTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .help(tool.rawValue.capitalized)
                            }
                        }

                        // Color picker
                        HStack(spacing: 4) {
                            ForEach(annotationColorOptions, id: \.0) { name, color in
                                Button(action: { state.annotationColor = color }) {
                                    Circle()
                                        .fill(Color(nsColor: color))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle().stroke(
                                                state.annotationColor == color ? Color.white : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(name)
                            }
                        }

                        // Stroke width
                        HStack {
                            Text("Stroke")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Slider(value: $state.strokeWidth, in: 2...12, step: 1)
                            Text("\(Int(state.strokeWidth))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }

                        // Text input (for text tool)
                        if state.currentTool == .text {
                            TextField("Label text", text: $state.annotationText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }

                        // Undo / Clear
                        HStack(spacing: 6) {
                            Button(action: { state.undoAnnotation() }) {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(state.annotations.isEmpty)
                            .keyboardShortcut("z")

                            Button(role: .destructive, action: { state.clearAnnotations() }) {
                                Label("Clear All", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(state.annotations.isEmpty)
                        }
                    }
                    .disabled(state.clipboardImage == nil)

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

                    // Aspect ratio
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aspect Ratio")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            ForEach(AspectRatioOption.allCases) { option in
                                Button(action: { state.aspectRatioOption = option }) {
                                    Text(option.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(state.aspectRatioOption == option ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
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

                    // Content background fill
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            // Transparent
                            Button(action: { state.contentBackground = nil }) {
                                ZStack {
                                    // Checkerboard pattern to indicate transparency
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white)
                                        .frame(width: 28, height: 28)
                                    Path { path in
                                        for row in 0..<4 {
                                            for col in 0..<4 where (row + col).isMultiple(of: 2) {
                                                path.addRect(CGRect(x: 4 + col * 5, y: 4 + row * 5, width: 5, height: 5))
                                            }
                                        }
                                    }
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(state.contentBackground == nil ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Transparent")

                            // White
                            Button(action: { state.contentBackground = .white }) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(state.contentBackground == .white ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: state.contentBackground == .white ? 2 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("White")

                            // Black
                            Button(action: { state.contentBackground = .black }) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(state.contentBackground == .black ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: state.contentBackground == .black ? 2 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Black")

                            // Custom color picker
                            ColorPicker("", selection: Binding(
                                get: { Color(nsColor: state.contentBackground ?? .white) },
                                set: { state.contentBackground = NSColor($0) }
                            ), supportsOpacity: false)
                            .labelsHidden()
                            .help("Custom color")
                        }
                    }

                    // Shadow toggle
                    Toggle("Drop Shadow", isOn: $state.shadow)
                        .font(.system(size: 12, weight: .medium))

                }
                .padding(16)
            }

            Divider()

            // Actions pinned to bottom
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
            .padding(16)
            } // VStack sidebar
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
