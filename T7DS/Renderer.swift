import Metal
import MetalKit
import SwiftUI
import CoreImage

struct Uniforms {
    var colorDark: SIMD4<Float>
    var colorLight: SIMD4<Float>
    var resolution: SIMD2<Float>
    var mode: Float
    var isGrayscale: Float
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var hue: Float
    var spread: Float
    var matrixSize: Int32
    var bayerScale: Float
    var paletteSize: Float
    var crtWarp: Float
    var crtScanline: Float
    var crtVignette: Float
    var crtScale: Float
    var crtBlur: Float
    var crtGlowIntensity: Float
    var crtGlowSpread: Float
    var halftoneMisprint: Float
    var asciiCharCount: Float
    var isAnsiColors: Float
    var asciiSpacing: Float
}

class Renderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    private let ciContext = CIContext()
    
    private var cachedAsciiString: String = ""
    private var cachedFontName: String = ""
    private var cachedAsciiAtlas: MTLTexture?
    private let atlasLock = NSLock()
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(), let kernel = library.makeFunction(name: "bayerDither") else { return nil }
        self.device = device; self.commandQueue = commandQueue
        do { self.pipelineState = try device.makeComputePipelineState(function: kernel) } catch { return nil }
    }
    
    func createCharAtlas(from chars: String, fontName: String) -> MTLTexture? {
        let charArray = Array(chars); let fontSize: CGFloat = 64
        let width = Int(fontSize) * charArray.count; let height = Int(fontSize)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = .shaderRead; guard let tex = device.makeTexture(descriptor: desc) else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        
        context.setFillColor(CGColor.black); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // SELECCIÓN DE FUENTE CUSTOM
        var safeFont: NSFont
        if fontName == "System" {
            safeFont = NSFont.monospacedSystemFont(ofSize: fontSize * 0.8, weight: .bold)
        } else {
            safeFont = NSFont(name: fontName, size: fontSize * 0.8) ?? NSFont.monospacedSystemFont(ofSize: fontSize * 0.8, weight: .bold)
        }
        
        let attrs: [NSAttributedString.Key: Any] = [.font: safeFont, .foregroundColor: NSColor.white]
        
        for (i, char) in charArray.enumerated() {
            let rect = CGRect(x: CGFloat(i) * fontSize, y: 0, width: fontSize, height: fontSize)
            let str = NSAttributedString(string: String(char), attributes: attrs); let size = str.size()
            let drawRect = CGRect(x: rect.origin.x + (rect.width - size.width)/2, y: rect.origin.y + (rect.height - size.height)/2, width: size.width, height: size.height)
            str.draw(in: drawRect)
        }
        NSGraphicsContext.restoreGraphicsState()
        if let data = context.data { tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: data, bytesPerRow: width) }
        return tex
    }

    func processImage(from url: URL, mode: Int, asciiString: String, fontName: String, spread: Float, isGrayscale: Bool, matrixSize: Int, bayerScale: Float, paletteSize: Float, colorDark: Color, colorLight: Color, crtWarp: Float, crtScanline: Float, crtVignette: Float, crtScale: Float, crtBlur: Float, crtGlowIntensity: Float, crtGlowSpread: Float, halftoneMisprint: Float, brightness: Float, contrast: Float, saturation: Float, hue: Float, isAnsiColors: Bool, asciiSpacing: Float) -> NSImage? {
        let textureLoader = MTKTextureLoader(device: device)
        do {
            let inputTexture = try textureLoader.newTexture(URL: url, options: [.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue), .SRGB: false])
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: inputTexture.width, height: inputTexture.height, mipmapped: false)
            descriptor.usage = [.shaderWrite, .shaderRead]
            guard let outputTexture = device.makeTexture(descriptor: descriptor) else { return nil }
            guard let commandBuffer = commandQueue.makeCommandBuffer(), let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
            
            encoder.setComputePipelineState(pipelineState)
            encoder.setTexture(inputTexture, index: 0); encoder.setTexture(outputTexture, index: 1)
            
            if mode == 5 {
                let safeAscii = asciiString.isEmpty ? " " : asciiString
                atlasLock.lock()
                // REGENERAR ATLAS SI CAMBIA EL TEXTO O LA FUENTE
                if cachedAsciiAtlas == nil || cachedAsciiString != safeAscii || cachedFontName != fontName {
                    cachedAsciiAtlas = createCharAtlas(from: safeAscii, fontName: fontName)
                    cachedAsciiString = safeAscii
                    cachedFontName = fontName
                }
                let atlas = cachedAsciiAtlas
                atlasLock.unlock()
                if let atlas = atlas { encoder.setTexture(atlas, index: 2) }
            }
            
            let cDark = colorToSimd4(colorDark); let cLight = colorToSimd4(colorLight)
            var uniforms = Uniforms(
                colorDark: cDark, colorLight: cLight,
                resolution: SIMD2<Float>(Float(inputTexture.width), Float(inputTexture.height)),
                mode: Float(mode), isGrayscale: isGrayscale ? 1.0 : 0.0,
                brightness: brightness, contrast: contrast, saturation: saturation, hue: hue, spread: spread,
                matrixSize: Int32(matrixSize), bayerScale: bayerScale, paletteSize: paletteSize,
                crtWarp: crtWarp, crtScanline: crtScanline, crtVignette: crtVignette, crtScale: crtScale, crtBlur: crtBlur,
                crtGlowIntensity: crtGlowIntensity, crtGlowSpread: crtGlowSpread, halftoneMisprint: halftoneMisprint,
                asciiCharCount: Float(asciiString.count), isAnsiColors: isAnsiColors ? 1.0 : 0.0, asciiSpacing: asciiSpacing
            )
            
            encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            let w = pipelineState.threadExecutionWidth; let h = pipelineState.maxTotalThreadsPerThreadgroup / w
            encoder.dispatchThreads(MTLSizeMake(inputTexture.width, inputTexture.height, 1), threadsPerThreadgroup: MTLSizeMake(w, h, 1))
            encoder.endEncoding(); commandBuffer.commit(); commandBuffer.waitUntilCompleted()
            
            return makeNSImage(from: outputTexture)
        } catch { return nil }
    }
    
    private func colorToSimd4(_ c: Color) -> SIMD4<Float> {
        guard let ns = NSColor(c).usingColorSpace(.sRGB) else { return SIMD4<Float>(0,0,0,1) }
        return SIMD4<Float>(pow(Float(ns.redComponent), 2.2), pow(Float(ns.greenComponent), 2.2), pow(Float(ns.blueComponent), 2.2), 1.0)
    }
    
    private func makeNSImage(from texture: MTLTexture) -> NSImage? {
        guard let ci = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()]) else { return nil }
        let flippedCI = ci.oriented(.downMirrored)
        guard let cgImage = ciContext.createCGImage(flippedCI, from: flippedCI.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: texture.width, height: texture.height))
    }
}
