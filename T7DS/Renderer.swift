import Metal
import MetalKit
import SwiftUI

struct Uniforms {
    var mode: Float; var isGrayscale: Float; var brightness: Float; var contrast: Float; var saturation: Float; var hue: Float; var spread: Float; var matrixSize: Int32; var bayerScale: Float; var paletteSize: Float; var colorDark: SIMD4<Float>; var colorLight: SIMD4<Float>; var crtWarp: Float; var crtScanline: Float; var crtVignette: Float; var crtScale: Float; var crtBlur: Float; var crtGlowIntensity: Float; var crtGlowSpread: Float; var halftoneMisprint: Float
}

class Renderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let kernelFunction = library.makeFunction(name: "bayerDither") else { return nil }
        self.device = device
        self.commandQueue = commandQueue
        do { self.pipelineState = try device.makeComputePipelineState(function: kernelFunction) } catch { return nil }
    }
    
    func processImage(from url: URL, mode: Int, spread: Float, isGrayscale: Bool, matrixSize: Int, bayerScale: Float, paletteSize: Float, colorDark: Color, colorLight: Color, crtWarp: Float, crtScanline: Float, crtVignette: Float, crtScale: Float, crtBlur: Float, crtGlowIntensity: Float, crtGlowSpread: Float, halftoneMisprint: Float, brightness: Float, contrast: Float, saturation: Float, hue: Float) -> NSImage? {
        let textureLoader = MTKTextureLoader(device: device)
        do {
            let inputTexture = try textureLoader.newTexture(URL: url, options: [.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue), .SRGB: false])
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: inputTexture.width, height: inputTexture.height, mipmapped: false)
            descriptor.usage = [.shaderWrite, .shaderRead]
            guard let outputTexture = device.makeTexture(descriptor: descriptor) else { return nil }
            guard let commandBuffer = commandQueue.makeCommandBuffer(), let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
            
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.setTexture(inputTexture, index: 0)
            computeEncoder.setTexture(outputTexture, index: 1)
            
            let cDark = colorToSimd4(colorDark); let cLight = colorToSimd4(colorLight)
            var uniforms = Uniforms(mode: Float(mode), isGrayscale: isGrayscale ? 1.0 : 0.0, brightness: brightness, contrast: contrast, saturation: saturation, hue: hue, spread: spread, matrixSize: Int32(matrixSize), bayerScale: bayerScale, paletteSize: paletteSize, colorDark: cDark, colorLight: cLight, crtWarp: crtWarp, crtScanline: crtScanline, crtVignette: crtVignette, crtScale: crtScale, crtBlur: crtBlur, crtGlowIntensity: crtGlowIntensity, crtGlowSpread: crtGlowSpread, halftoneMisprint: halftoneMisprint)
            
            computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            let w = pipelineState.threadExecutionWidth
            let h = pipelineState.maxTotalThreadsPerThreadgroup / w
            computeEncoder.dispatchThreads(MTLSizeMake(inputTexture.width, inputTexture.height, 1), threadsPerThreadgroup: MTLSizeMake(w, h, 1))
            
            computeEncoder.endEncoding(); commandBuffer.commit(); commandBuffer.waitUntilCompleted()
            return makeNSImage(from: outputTexture)
        } catch { return nil }
    }
    
    private func colorToSimd4(_ c: Color) -> SIMD4<Float> {
        guard let ns = NSColor(c).usingColorSpace(.sRGB) else { return SIMD4<Float>(0,0,0,1) }
        return SIMD4<Float>(pow(Float(ns.redComponent), 2.2), pow(Float(ns.greenComponent), 2.2), pow(Float(ns.blueComponent), 2.2), 1.0)
    }
    
    private func makeNSImage(from texture: MTLTexture) -> NSImage? {
        let width = texture.width; let height = texture.height; let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&data, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let ci = CIImage(bitmapData: Data(data), bytesPerRow: bytesPerRow, size: CGSize(width: width, height: height), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let rep = NSCIImageRep(ciImage: ci); let nsImage = NSImage(size: rep.size); nsImage.addRepresentation(rep); return nsImage
    }
}
