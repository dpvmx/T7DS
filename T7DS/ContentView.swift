import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isTargeted = false
    @State private var filename = "ARRASTRA IMAGEN"
    @State private var processedImage: NSImage?
    @State private var originalImageURL: URL?
    @State private var selectedMode: Int = 5
    @State private var asciiString: String = " .:-=+*#%@"
    
    // Params
    @State private var bayerScale: Float = 80.0
    @State private var spread: Float = 1.0
    @State private var isGrayscale: Bool = true
    @State private var isWebSafe: Bool = false
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
                } else {
                    VStack { Image(systemName: "text.viewfinder").font(.system(size: 60)).foregroundStyle(.gray.opacity(0.3)); Text("T7DS SUITE").font(.system(.title3, design: .monospaced)).foregroundStyle(.gray.opacity(0.5)).padding(.top) }
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
                        Toggle("WebSafe Colors", isOn: $isWebSafe).onChange(of: isWebSafe) { _, _ in runProcessing() }.foregroundStyle(.white)
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
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Pattern").font(.caption2).foregroundStyle(.gray)
                                    Spacer()
                                    Button("Load Braille") {
                                        asciiString = "⠀⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏⠐⠑⠒⠓⠔⠕⠖⠗⠘⠙⠚⠛⠜⠝⠞⠟⠠⠡⠢⠣⠤⠥⠦⠧⠨⠩⠪⠫⠬⠭⠮⠯⠰⠱⠲⠳⠴⠵⠶⠷⠸⠹⠺⠻⠼⠽⠾⠿"
                                    }.font(.system(size: 9)).buttonStyle(.plain).foregroundColor(.blue)
                                }
                                TextField("Chars", text: $asciiString)
                                    .textFieldStyle(.plain).font(.system(.body, design: .monospaced))
                                    .padding(6).background(Color.white.opacity(0.1)).cornerRadius(4)
                                    .onChange(of: asciiString) { _, _ in runProcessing() }
                            }
                            controlSlider(title: "Columns (Res)", value: $bayerScale, min: 20.0, max: 300.0, defaultVal: 80.0, step: 1.0)
                            Toggle("Grayscale", isOn: $isGrayscale).onChange(of: isGrayscale) { _, _ in runProcessing() }.foregroundStyle(.white)
                            if isGrayscale {
                                ColorPicker("Background", selection: $colorDark).onChange(of: colorDark) { _, _ in runProcessing() }
                                ColorPicker("Foreground", selection: $colorLight).onChange(of: colorLight) { _, _ in runProcessing() }
                            }
                        }
                    } else { // DIGITAL
                        Group {
                            Text(selectedMode == 4 ? "HALFTONE ENGINE" : "DITHER ENGINE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                            if selectedMode != 4 { controlSlider(title: "Palette", value: $paletteSize, min: 2.0, max: 32.0, defaultVal: 2.0, step: 1.0) }
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
                    Spacer(); Text(filename).font(.system(size: 10, design: .monospaced)).foregroundStyle(.gray).lineLimit(1).padding(.bottom, 20)
                }.padding(.horizontal, 20)
            }.frame(width: 300).background(Color(red: 0.12, green: 0.12, blue: 0.12))
        }.frame(minWidth: 1000, minHeight: 700)
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
    
    func controlSlider(title: String, value: Binding<Float>, min: Float, max: Float, defaultVal: Float, step: Float? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.caption2).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.caption2)
                    .foregroundStyle(abs(value.wrappedValue - defaultVal) > 0.01 ? .yellow : .gray)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                value.wrappedValue = defaultVal;
                runProcessing()
            }
            
            if let s = step { Slider(value: value, in: min...max, step: s).onChange(of: value.wrappedValue) { _, _ in runProcessing() }.tint(.white) }
            else { Slider(value: value, in: min...max).onChange(of: value.wrappedValue) { _, _ in runProcessing() }.tint(.white) }
        }
    }
    
    func runProcessing() {
        guard let url = originalImageURL else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            if let result = self.renderer?.processImage(from: url, mode: selectedMode, asciiString: asciiString, spread: spread, isGrayscale: isGrayscale, matrixSize: matrixSize, bayerScale: bayerScale, paletteSize: paletteSize, colorDark: colorDark, colorLight: colorLight, crtWarp: crtWarp, crtScanline: crtScanline, crtVignette: crtVignette, crtScale: crtScale, crtBlur: crtBlur, crtGlowIntensity: crtGlowIntensity, crtGlowSpread: crtGlowSpread, halftoneMisprint: halftoneMisprint, brightness: brightness, contrast: contrast, saturation: saturation, hue: hue, isWebSafe: isWebSafe) {
                DispatchQueue.main.async { self.processedImage = result }
            }
        }
    }
}
