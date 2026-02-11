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
* **WebSafe Mode:** Optional quantization to the standard 216-color web palette.

### 2. ASCII Engine (New)
Real-time text conversion using GPU-accelerated texture atlases.
* **Custom Character Ramp:** Type any string to generate the shading pattern instantly.
* **Braille Mode:** One-click preset for high-density Braille art.
* **Proportional Grid:** Calculates exact cell sizes to prevent edge clipping.

### 3. CRT Emulation (Cathode Ray Tube)
Physical simulation of tube monitors.
* **Geometry Warping:** Spherical screen curvature.
* **Beam Scanning:** Progressive scanlines and Shadow Mask.
* **Signal Processing:** Analog signal blur and chromatic aberration.
* **Phosphor Glow:** Light reactive bloom for high-luminance areas.

### 4. Halftone Engine
Simulation of editorial printing processes.
* **CMYK Simulation:** Channel separation.
* **Misprint Control:** Offset plate simulation for registration errors.
* **Adaptive Dot Gain:** Dynamic dot size adjustment based on luminance.

---

## 🛠 Tech Stack

* **Language:** Swift 5.9+
* **UI Framework:** SwiftUI (macOS Target)
* **Graphics API:** Metal (MTLComputePipelineState)
* **Architecture:**
    * `ContentView.swift`: Reactive state management and UI controls.
    * `Renderer.swift`: CPU-GPU bridge and dynamic Texture Atlas generation.
    * `Shaders.metal`: Parallel compute kernels for pixel manipulation.

---

## 🎛 Controls & Parameters

### Universal
* **Double-Click Reset:** Tap any value label twice to reset it to default.
* **Resolution (Columns):** Defines the density of the grid (pixels, dots, or characters) proportionally to the image width.

### Dither Engine
* **Spread:** Dither matrix intensity.
* **Palette:** Color depth reduction.
* **WebSafe Colors:** Force 90s web standard colors.

### ASCII Engine
* **Character Field:** Live-editable text ramp.
* **Grayscale/Color:** Toggle between classic terminal look or colored text.

### CRT Engine
* **Scale:** Phosphor mask size.
* **Intensity:** Scanline visibility.
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

---

**License:** MIT
