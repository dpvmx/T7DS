import SwiftUI
import UniformTypeIdentifiers

// ESTRUCTURA DE EXPORTACIÓN CON SOPORTE DE ESCALADO NEAREST-NEIGHBOR
struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    var pngData: Data

    init(data: Data) { self.pngData = data }
    init(configuration: ReadConfiguration) throws { throw CocoaError(.fileReadUnknown) }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: pngData)
    }
}

struct ContentView: View {
    @State private var isTargeted = false
    @State private var filename = "ARRASTRA IMAGEN"
    @State private var processedImage: NSImage?
    @State private var originalImageURL: URL?
    @State private var selectedMode: Int = 5
    
    // ASCII Customization
    @State private var asciiString: String = " .:-=+*#%@"
    @State private var selectedFont: String = "System"
    let fontOptions = ["System", "Menlo", "Monaco", "Courier", "Andale Mono"]
    
    // Exportación
    @State private var showingExporter = false
    @State private var documentToExport: PNGDocument?
    @State private var exportScale: Float = 1.0 // NUEVO: Escala de exportación
    
    // Params
    @State private var bayerScale: Float = 80.0
    @State private var spread: Float = 1.0
    @State private var isGrayscale: Bool = true
    @State private var isAnsiColors: Bool = false
    @State private var matrixSize: Int = 1
    @State private var paletteSize: Float = 2.0
    @State private var colorDark: Color = .black
    @State private var colorLight: Color = .green
    @State private var crtWarp: Float = 0.3
    @State private var crtScanline: Float = 0.8
    @State private var crtVignette: Float = 0.5
    @State private var crtScale: Float = 2.0
    @State private var crtBlur: Float = 0.2
    @State private var crtGlowIntensity: Float = 0.4
    @State private var crtGlowSpread: Float = 0.5
    @State private var halftoneMisprint: Float = 0.0
    @State private var asciiSpacing: Float = 1.0
    @State private var brightness: Float = 0.0
    @State private var contrast: Float = 1.0
    @State private var saturation: Float = 1.0
    @State private var hue: Float = 0.0
    
    private let renderer = Renderer()
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.05).ignoresSafeArea()
                if let image = processedImage {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .shadow(radius: 20)
                        .draggable(image)
                } else {
                    VStack {
                        Image(systemName: "text.viewfinder").font(.system(size: 60)).foregroundStyle(.gray.opacity(0.3))
                        Text("T7DS SUITE").font(.system(.title3, design: .monospaced)).foregroundStyle(.gray.opacity(0.5)).padding(.top)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                if let provider = providers.first {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                        DispatchQueue.main.async {
                            if let urlData = urlData as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                                self.originalImageURL = url; self.filename = url.lastPathComponent; runProcessing()
                            }
                        }
                    }
                    return true
                }
                return false
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("T7DS CONTROL").font(.system(.headline, design: .monospaced)).foregroundStyle(.white).padding(.top, 20)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        modeButton("Bayer", 0); modeButton("CRT", 1); modeButton("Blue", 2)
                        modeButton("Diff", 3); modeButton("Half", 4); modeButton("ASCII", 5)
                    }
                    
                    Group {
                        Text("PRE-PROCESS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                        controlSlider(title: "Brightness", value: $brightness, min: -0.5, max: 0.5, defaultVal: 0.0)
                        controlSlider(title: "Contrast", value: $contrast, min: 0.0, max: 2.0, defaultVal: 1.0)
                        controlSlider(title: "Saturation", value: $saturation, min: 0.0, max: 2.0, defaultVal: 1.0)
                        controlSlider(title: "Hue Shift", value: $hue, min: 0.0, max: 6.28, defaultVal: 0.0)
                        Toggle("ANSI 256 Colors", isOn: $isAnsiColors).onChange(of: isAnsiColors) { _, _ in runProcessing() }.foregroundStyle(.white)
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    if selectedMode == 1 { // CRT
                        Group {
                            Text("CRT ENGINE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                            controlSlider(title: "Scale", value: $crtScale, min: 1.0, max: 8.0, defaultVal: 2.0)
                            controlSlider(title: "Intensity", value: $crtScanline, min: 0.0, max: 1.0, defaultVal: 0.8)
                            controlSlider(title: "Blur", value: $crtBlur, min: 0.0, max: 2.0, defaultVal: 0.2)
                            controlSlider(title: "Glow Int.", value: $crtGlowIntensity, min: 0.0, max: 2.0, defaultVal: 0.4)
                            controlSlider(title: "Glow Spread", value: $crtGlowSpread, min: 0.0, max: 2.0, defaultVal: 0.5)
                            controlSlider(title: "Warp", value: $crtWarp, min: 0.0, max: 1.0, defaultVal: 0.3)
                            controlSlider(title: "Vignette", value: $crtVignette, min: 0.0, max: 1.0, defaultVal: 0.5)
                        }
                    } else if selectedMode == 5 { // ASCII
                        Group {
                            Text("ASCII ENGINE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                            
                            // SELECTOR DE FUENTES
                            HStack {
                                Text("Font").font(.caption2).foregroundStyle(.gray)
                                Spacer()
                                Picker("", selection: $selectedFont) {
                                    ForEach(fontOptions, id: \.self) { font in Text(font).tag(font) }
                                }.labelsHidden().font(.caption2).frame(width: 120)
                                .onChange(of: selectedFont) { _, _ in runProcessing() }
                            }
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Pattern").font(.caption2).foregroundStyle(.gray)
                                    Spacer()
                                    Menu("Presets") {
                                        Button("ANSI Light") { asciiString = " .,:!+*e$@8" }
                                        Button("ANSI Color") { asciiString = " .*es@" }
                                        Button("ANSI Filled") { asciiString = " ░▒▓█" }
                                        Divider()
                                        Button("Classic") { asciiString = " .:-=+*#%@" }
                                        Button("Retro Glyphs") { asciiString = " `.-':_,^=;><+!rc*/z?sLTv)J7(|Fi{C}fI31tlu[neoZ5Yxjya]2ESwqkP6h9d4VpOGbUAKXHm8RD#$Bg0MNWQ%&@" }
                                        Button("Braille") { asciiString = "⠀⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏⠐⠑⠒⠓⠔⠕⠖⠗⠘⠙⠚⠛⠜⠝⠞⠟⠠⠡⠢⠣⠤⠥⠦⠧⠨⠩⠪⠫⠬⠭⠮⠯⠰⠱⠲⠳⠴⠵⠶⠷⠸⠹⠺⠻⠼⠽⠾⠿" }
                                        Button("Binary") { asciiString = " 01" }
                                    }.font(.system(size: 10)).buttonStyle(.plain).foregroundColor(.blue)
                                }
                                TextField("Chars", text: $asciiString)
                                    .textFieldStyle(.plain).font(.system(.body, design: .monospaced))
                                    .padding(6).background(Color.white.opacity(0.1)).cornerRadius(4)
                                    .onChange(of: asciiString) { _, _ in runProcessing() }
                            }
                            
                            // AQUI EL STEP DE COLUMNAS ESTÁ CUANTIZADO A 1.0 ENTEROS
                            controlSlider(title: "Columns (Res)", value: $bayerScale, min: 20.0, max: 300.0, defaultVal: 80.0, step: 1.0)
                            controlSlider(title: "Glyph Scale", value: $asciiSpacing, min: 0.5, max: 1.5, defaultVal: 1.0, step: 0.05)
                            Toggle("Grayscale", isOn: $isGrayscale).onChange(of: isGrayscale) { _, _ in runProcessing() }.foregroundStyle(.white)
                            if isGrayscale {
                                ColorPicker("Background", selection: $colorDark).onChange(of: colorDark) { _, _ in runProcessing() }
                                ColorPicker("Foreground", selection: $colorLight).onChange(of: colorLight) { _, _ in runProcessing() }
                            }
                        }
                    } else { // DIGITAL
                        Group {
                            Text(selectedMode == 4 ? "HALFTONE ENGINE" : "DITHER ENGINE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                            // PALETTE ESTÁ CUANTIZADO CON STEP DE 1.0 (Enteros)
                            if selectedMode != 4 { controlSlider(title: "Palette Steps", value: $paletteSize, min: 2.0, max: 32.0, defaultVal: 2.0, step: 1.0) }
                            controlSlider(title: "Resolution (Cols)", value: $bayerScale, min: 20.0, max: 400.0, defaultVal: 100.0, step: 1.0)
                            controlSlider(title: "Intensity", value: $spread, min: 0.0, max: 2.0, defaultVal: 1.0)
                            if selectedMode == 4 && !isGrayscale { controlSlider(title: "Misprint", value: $halftoneMisprint, min: 0.0, max: 2.0, defaultVal: 0.0) }
                            Toggle("Grayscale", isOn: $isGrayscale).onChange(of: isGrayscale) { _, _ in runProcessing() }.foregroundStyle(.white)
                            if isGrayscale {
                                ColorPicker("Dark", selection: $colorDark).onChange(of: colorDark) { _, _ in runProcessing() }
                                ColorPicker("Light", selection: $colorLight).onChange(of: colorLight) { _, _ in runProcessing() }
                            }
                            if selectedMode == 0 { Picker("Matrix", selection: $matrixSize) { Text("2x").tag(0); Text("4x").tag(1); Text("8x").tag(2); Text("16x").tag(3) }.pickerStyle(.segmented).onChange(of: matrixSize) { _, _ in runProcessing() } }
                        }
                    }
                    
                    Spacer()
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // --- EXPORTACIÓN Y ESCALADO ---
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Export Scale").font(.caption2).foregroundStyle(.gray)
                            Spacer()
                            Picker("", selection: $exportScale) {
                                Text("0.5x (Half)").tag(Float(0.5))
                                Text("1x (Original)").tag(Float(1.0))
                                Text("2x (HD)").tag(Float(2.0))
                                Text("4x (4K Sharp)").tag(Float(4.0))
                                Text("8x (Pixel Art)").tag(Float(8.0))
                            }.labelsHidden().frame(width: 120)
                        }
                        
                        Text(filename).font(.system(size: 10, design: .monospaced)).foregroundStyle(.gray).lineLimit(1)
                        
                        Button(action: prepareExport) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Export Image")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(processedImage == nil ? Color.gray.opacity(0.2) : Color.blue)
                            .foregroundColor(processedImage == nil ? .gray : .white)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(processedImage == nil)
                    }.padding(.bottom, 20)
                    
                }.padding(.horizontal, 20)
            }.frame(width: 300).background(Color(red: 0.12, green: 0.12, blue: 0.12))
        }
        .frame(minWidth: 1000, minHeight: 700)
        .fileExporter(isPresented: $showingExporter,
                      document: documentToExport,
                      contentType: .png,
                      defaultFilename: "\(URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent)_x\(Int(exportScale)).png") { result in
            switch result {
            case .success(let url): print("Imagen guardada en: \(url)")
            case .failure(let error): print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // --- LÓGICA DE ESCALADO NEAREST NEIGHBOR ---
    func prepareExport() {
        guard let image = processedImage else { return }
        var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        guard let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else { return }
        
        let targetWidth = Int(CGFloat(cgImage.width) * CGFloat(exportScale))
        let targetHeight = Int(CGFloat(cgImage.height) * CGFloat(exportScale))
        
        // Creamos un nuevo lienzo con la medida objetivo
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        
        // MAGIA: Si el usuario escala hacia arriba (>1.0), desactivamos la interpolación
        // para que los píxeles queden como "bloques duros" perfectos (Pixel Art / Nearest Neighbor).
        // Si escala hacia abajo (<1.0), usamos alta calidad para no perder información.
        context.interpolationQuality = exportScale > 1.0 ? .none : .high
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        guard let scaledCGImage = context.makeImage() else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: scaledCGImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        self.documentToExport = PNGDocument(data: pngData)
        self.showingExporter = true
    }
    
    func modeButton(_ title: String, _ tag: Int) -> some View {
        Button(action: { selectedMode = tag; runProcessing() }) {
            Text(title).font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(selectedMode == tag ? Color.white.opacity(0.2) : Color.black.opacity(0.3))
                .foregroundColor(.white).cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }.buttonStyle(.plain)
    }
    
    // --- CONTROLES MEJORADOS (TEXTFIELDS EDITABLES) ---
    func controlSlider(title: String, value: Binding<Float>, min: Float, max: Float, defaultVal: Float, step: Float? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                // El Doble-Click para resetear ahora vive en el TÍTULO
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        value.wrappedValue = defaultVal
                        runProcessing()
                    }
                Spacer()
                
                // El valor ahora es un TextField editable. Si escribes y das Enter, se aplica.
                TextField("", value: value, format: .number.precision(.fractionLength(1...2)))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.caption2)
                    .frame(width: 45)
                    .foregroundStyle(abs(value.wrappedValue - defaultVal) > 0.01 ? .yellow : .gray)
                    .onSubmit {
                        // Restringimos el input manual para que no rompa la app
                        value.wrappedValue = Swift.min(Swift.max(value.wrappedValue, min), max)
                        runProcessing()
                    }
            }
            
            if let s = step { Slider(value: value, in: min...max, step: s).onChange(of: value.wrappedValue) { _, _ in runProcessing() }.tint(.white) }
            else { Slider(value: value, in: min...max).onChange(of: value.wrappedValue) { _, _ in runProcessing() }.tint(.white) }
        }
    }
    
    func runProcessing() {
        guard let url = originalImageURL else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            // Pasamos selectedFont al Renderer
            if let result = self.renderer?.processImage(from: url, mode: selectedMode, asciiString: asciiString, fontName: selectedFont, spread: spread, isGrayscale: isGrayscale, matrixSize: matrixSize, bayerScale: bayerScale, paletteSize: paletteSize, colorDark: colorDark, colorLight: colorLight, crtWarp: crtWarp, crtScanline: crtScanline, crtVignette: crtVignette, crtScale: crtScale, crtBlur: crtBlur, crtGlowIntensity: crtGlowIntensity, crtGlowSpread: crtGlowSpread, halftoneMisprint: halftoneMisprint, brightness: brightness, contrast: contrast, saturation: saturation, hue: hue, isAnsiColors: isAnsiColors, asciiSpacing: asciiSpacing) {
                DispatchQueue.main.async { self.processedImage = result }
            }
        }
    }
}
