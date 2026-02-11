import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isTargeted = false
    @State private var filename = "ARRASTRA IMAGEN"
    @State private var processedImage: NSImage?
    @State private var originalImageURL: URL?
    @State private var selectedMode: Int = 4
    
    // Params
    @State private var spread: Float = 1.0
    @State private var isGrayscale: Bool = true
    @State private var matrixSize: Int = 1
    @State private var bayerScale: Float = 1.5
    @State private var paletteSize: Float = 2.0
    @State private var colorDark: Color = .black
    @State private var colorLight: Color = .white
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
                    VStack {
                        Image(systemName: "circle.hexagongrid.fill").font(.system(size: 60)).foregroundStyle(.gray.opacity(0.3))
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
                    Picker("Effect", selection: $selectedMode) {
                        Text("Bayer").tag(0); Text("CRT").tag(1); Text("Blue").tag(2); Text("Diff").tag(3); Text("Half").tag(4)
                    }.pickerStyle(.segmented).onChange(of: selectedMode) { _, _ in runProcessing() }
                    
                    Group {
                        Text("PRE-PROCESS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                        controlSlider(title: "Brightness", value: $brightness, min: -0.5, max: 0.5, defaultVal: 0.0)
                        controlSlider(title: "Contrast", value: $contrast, min: 0.0, max: 2.0, defaultVal: 1.0)
                        controlSlider(title: "Saturation", value: $saturation, min: 0.0, max: 2.0, defaultVal: 1.0)
                        controlSlider(title: "Hue Shift", value: $hue, min: 0.0, max: 6.28, defaultVal: 0.0)
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    if selectedMode == 1 {
                        Group {
                            Text("CRT ENGINE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                            controlSlider(title: "Scale", value: $crtScale, min: 1.0, max: 8.0, defaultVal: 2.0)
                            controlSlider(title: "Intensity", value: $crtScanline, min: 0.0, max: 1.0, defaultVal: 0.8)
                            controlSlider(title: "Pattern Blur", value: $crtBlur, min: 0.0, max: 2.0, defaultVal: 0.2)
                            controlSlider(title: "Glow Int.", value: $crtGlowIntensity, min: 0.0, max: 2.0, defaultVal: 0.4)
                            controlSlider(title: "Glow Spread", value: $crtGlowSpread, min: 0.0, max: 2.0, defaultVal: 0.5)
                            controlSlider(title: "Warp", value: $crtWarp, min: 0.0, max: 1.0, defaultVal: 0.3)
                            controlSlider(title: "Vignette", value: $crtVignette, min: 0.0, max: 1.0, defaultVal: 0.5)
                        }
                    } else {
                        Group {
                            Text(selectedMode == 4 ? "HALFTONE ENGINE" : "DITHER ENGINE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                            if selectedMode != 4 { controlSlider(title: "Palette", value: $paletteSize, min: 2.0, max: 32.0, defaultVal: 2.0, step: 1.0) }
                            Toggle("Grayscale", isOn: $isGrayscale).onChange(of: isGrayscale) { _, _ in runProcessing() }.foregroundStyle(.white)
                            if isGrayscale {
                                ColorPicker("Dark", selection: $colorDark).onChange(of: colorDark) { _, _ in runProcessing() }
                                ColorPicker("Light", selection: $colorLight).onChange(of: colorLight) { _, _ in runProcessing() }
                            }
                            if selectedMode == 0 { Picker("Matrix", selection: $matrixSize) { Text("2x").tag(0); Text("4x").tag(1); Text("8x").tag(2); Text("16x").tag(3) }.pickerStyle(.segmented).onChange(of: matrixSize) { _, _ in runProcessing() } }
                            controlSlider(title: "Point Density", value: $bayerScale, min: 0.1, max: 15.0, defaultVal: 1.5)
                            controlSlider(title: "Dot Intensity", value: $spread, min: 0.0, max: 2.0, defaultVal: 1.0)
                            if selectedMode == 4 && !isGrayscale { controlSlider(title: "Misprint (CMYK)", value: $halftoneMisprint, min: 0.0, max: 2.0, defaultVal: 0.0) }
                        }
                    }
                    
                    Spacer(); Text(filename).font(.system(size: 10, design: .monospaced)).foregroundStyle(.gray).lineLimit(1).padding(.bottom, 20)
                }.padding(.horizontal, 20)
            }.frame(width: 280).background(Color(red: 0.12, green: 0.12, blue: 0.12))
        }.frame(minWidth: 1000, minHeight: 700)
    }
    
    func controlSlider(title: String, value: Binding<Float>, min: Float, max: Float, defaultVal: Float, step: Float? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title).font(.caption2).foregroundStyle(.white.opacity(0.8)); Spacer(); Text(String(format: "%.2f", value.wrappedValue)).font(.caption2).foregroundStyle(abs(value.wrappedValue - defaultVal) > 0.001 ? .yellow : .gray).monospacedDigit() }
            .contentShape(Rectangle()).onTapGesture(count: 2) { value.wrappedValue = defaultVal; runProcessing() }
            if let s = step { Slider(value: value, in: min...max, step: s).onChange(of: value.wrappedValue) { _, _ in runProcessing() }.tint(.white) }
            else { Slider(value: value, in: min...max).onChange(of: value.wrappedValue) { _, _ in runProcessing() }.tint(.white) }
        }
    }
    
    func runProcessing() {
        guard let url = originalImageURL else { return }
        DispatchQueue.global(qos: .userInteractive).async {
            if let result = self.renderer?.processImage(from: url, mode: selectedMode, spread: spread, isGrayscale: isGrayscale, matrixSize: matrixSize, bayerScale: bayerScale, paletteSize: paletteSize, colorDark: colorDark, colorLight: colorLight, crtWarp: crtWarp, crtScanline: crtScanline, crtVignette: crtVignette, crtScale: crtScale, crtBlur: crtBlur, crtGlowIntensity: crtGlowIntensity, crtGlowSpread: crtGlowSpread, halftoneMisprint: halftoneMisprint, brightness: brightness, contrast: contrast, saturation: saturation, hue: hue) {
                DispatchQueue.main.async { self.processedImage = result }
            }
        }
    }
}
