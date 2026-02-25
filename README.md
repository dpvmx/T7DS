# T7DS - Retro Graphics Engine

**T7DS** is a high-performance image processing suite for macOS, built with **SwiftUI** and **Metal**. 

It is designed to emulate vintage digital aesthetics, analog printing techniques, and CRT display artifacts in real-time, leveraging parallel compute shaders for instant rendering.

---

## 📺 Key Features

### 1. Digital Dithering Engines
Color quantization algorithms simulating the 1-bit and 8-bit era aesthetics.
* **Bayer Dither:** Classic ordered matrix with selectable patterns (2x, 4x, 8x, 16x).
* **Blue Noise:** Stochastic dithering for organic, noise-based distribution.
* **Error Diffusion:** Simulation of Floyd-Steinberg/Atkinson-style algorithms.
* **ANSI 256 Colors:** Optional quantization to the classic terminal color space.

### 2. ASCII Engine
Real-time text conversion using GPU-accelerated texture atlases.
* **Custom Character Ramp:** Type any string to generate the shading pattern instantly.
* **Typographic Control:** Choose from classic monospaced fonts (Menlo, Monaco, Courier, etc.).
* **Retro Presets:** One-click menus for ANSI Block Art, Retro Glyphs, Braille, and Binary patterns.
* **Proportional Grid & Scaling:** Calculates exact cell sizes to prevent edge clipping, with adjustable glyph spacing.

### 3. CRT Emulation (Cathode Ray Tube)
Physical simulation of tube monitors.
* **Geometry Warping:** Spherical screen curvature.
* **Beam Scanning:** Progressive scanlines and Shadow Mask.
* **Signal Processing:** Analog RF signal blur and chromatic aberration.
* **Phosphor Glow:** Light reactive bloom for high-luminance areas.

### 4. Halftone Engine
Simulation of editorial printing processes.
* **CMYK Simulation:** Channel separation.
* **Misprint Control:** Offset plate simulation for registration errors.
* **Adaptive Dot Gain:** Dynamic dot size adjustment based on luminance.

### 5. Pro Export Workflow
Built for modern macOS environments with a focus on pixel perfection.
* **Nearest-Neighbor Scaling:** Export up to 8x resolution without anti-aliasing blur to preserve hard pixel edges.
* **Drag & Drop:** Instantly drag the processed image directly from the canvas to your desktop.
* **Sandbox-Safe:** Uses native SwiftUI `.fileExporter` for secure, crash-free file saving.

---

## 🛠 Tech Stack

* **Language:** Swift 5.9+
* **UI Framework:** SwiftUI (macOS Target)
* **Graphics API:** Metal (MTLComputePipelineState)
* **Architecture:**
    * `ContentView.swift`: Reactive state management, UI controls, and secure exporting.
    * `Renderer.swift`: CPU-GPU bridge, dynamic Texture Atlas generation, and CIContext scaling.
    * `Shaders.metal`: Parallel compute kernels for pixel manipulation.

---

## 🎛 Controls & Parameters

### Universal Controls
* **Double-Click Reset:** Tap any parameter title twice to reset it to its default value.
* **Precise Input:** All numeric values are editable text fields—type your exact value and hit Enter.
* **Resolution (Columns):** Defines the density of the grid (pixels, dots, or characters) proportionally to the image width.

### Dither Engine
* **Spread:** Dither matrix intensity.
* **Palette Steps:** Color depth reduction (quantized).
* **ANSI 256 Colors:** Force classic terminal colors.

### ASCII Engine
* **Font Selector:** Choose your preferred monospaced typography.
* **Glyph Scale:** Adjust the spacing/padding between individual characters.
* **Grayscale/Color:** Toggle between classic terminal look or colored text.

### CRT Engine
* **Scale:** Phosphor mask size.
* **Intensity:** Scanline visibility.
* **Blur:** RF signal noise/softness.
* **Glow:** Bloom intensity.
* **Warp:** Screen curvature.

### Halftone Engine
* **Dot Intensity:** Dot gain/size.
* **Misprint:** CMYK channel misalignment (Red/Blue shift).

---

## 🚀 Installation & Usage

1.  Clone the repository.
2.  Open `T7DS.xcodeproj` in Xcode 15 or later.
3.  Ensure the target is set to **My Mac**.
4.  Run (Cmd + R).
5.  **Drag and drop** any image file (PNG, JPG, WEBP) onto the window to process it.
6.  Select an **Export Scale** and click **Export Image**, or simply drag the artwork to your desktop.

---

**License:** MIT