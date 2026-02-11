#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float mode;             // 0:Bayer, 1:CRT, 2:Blue, 3:Diff, 4:Half, 5:ASCII
    float isGrayscale;
    float brightness;
    float contrast;
    float saturation;
    float hue;
    float spread;
    int matrixSize;
    float bayerScale;       // Column count / Density
    float paletteSize;
    float4 colorDark;
    float4 colorLight;
    float crtWarp;
    float crtScanline;
    float crtVignette;
    float crtScale;
    float crtBlur;
    float crtGlowIntensity;
    float crtGlowSpread;
    float halftoneMisprint;
    float asciiCharCount;
    float2 resolution;
    float isWebSafe;
};

// --- CONSTANTES GLOBALES (Deben estar fuera para evitar el error de address space) ---
constant float bayer2[2][2] = { {0.0/4.0, 2.0/4.0}, {3.0/4.0, 1.0/4.0} };
constant float bayer4[4][4] = { { 0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0 }, {12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0 }, { 3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0 }, {15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0 } };
constant float bayer8[8][8] = { { 0.0/64.0, 32.0/64.0, 8.0/64.0, 40.0/64.0, 2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0}, {48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0}, {12.0/64.0, 44.0/64.0, 4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0}, {60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0}, { 3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0}, {51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0}, {15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0}, {63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0} };

// --- FUNCIONES AUXILIARES ---

float hash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123); }

float3 hueRotate(float3 color, float angle) {
    const float3 k = float3(0.57735, 0.57735, 0.57735);
    float cosAngle = cos(angle);
    return color * cosAngle + cross(k, color) * sin(angle) + k * dot(k, color) * (1.0 - cosAngle);
}

float3 adjustColor(float3 rgb, constant Uniforms &uniforms) {
    if (uniforms.hue != 0.0) rgb = hueRotate(rgb, uniforms.hue);
    float luma = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    rgb = mix(float3(luma), rgb, uniforms.saturation);
    rgb = (rgb - 0.5) * uniforms.contrast + 0.5;
    rgb = rgb + uniforms.brightness;
    rgb = clamp(rgb, 0.0, 1.0);
    if (uniforms.isWebSafe > 0.5) rgb = floor(rgb * 5.0 + 0.5) / 5.0;
    return rgb;
}

float2 warpUV(float2 uv, float warpAmount) {
    float sf = 1.0 - (warpAmount * 0.15);
    float2 wuv = (uv - 0.5) * sf + 0.5;
    float2 dc = abs(0.5 - wuv);
    dc *= dc;
    wuv.x -= 0.5; wuv.x *= 1.0 + (dc.y * (0.3 * warpAmount)); wuv.x += 0.5;
    wuv.y -= 0.5; wuv.y *= 1.0 + (dc.x * (0.4 * warpAmount)); wuv.y += 0.5;
    return wuv;
}

float halftone(float2 uv, float intensity, float scale, float2 res, float ditherSpread) {
    float aspect = res.x / res.y;
    float2 st = uv; st.x *= aspect;
    float angle = 0.785398;
    float s = sin(angle), c = cos(angle);
    float2 rST = float2(st.x * c - st.y * s, st.x * s + st.y * c);
    float pLength = length(fract(rST * scale) - 0.5);
    return smoothstep(intensity * (0.6 * ditherSpread), (intensity * (0.6 * ditherSpread)) - 0.15, pLength);
}

float3 sampleHQ(texture2d<float, access::sample> tex, sampler s, float2 uv, float2 res, float amount) {
    float3 col = float3(0.0);
    float2 unit = (1.0 / res) * amount;
    float jitter = hash(uv);
    float2 off[5] = {float2(0,0), float2(1,1), float2(-1,-1), float2(1,-1), float2(-1,1)};
    for(int i=0; i<5; i++) col += tex.sample(s, uv + (off[i] + jitter * 0.1) * unit).rgb;
    return col / 5.0;
}

float getBayer16(int x, int y) {
    int x8 = x % 8, y8 = y % 8, x2 = (x/8)%2, y2 = (y/8)%2;
    return (bayer8[y8][x8] * 4.0 + bayer2[y2][x2]) / 4.0;
}

// --- KERNEL PRINCIPAL ---
kernel void bayerDither(texture2d<float, access::sample> inputTexture [[texture(0)]],
                        texture2d<float, access::write> outputTexture [[texture(1)]],
                        texture2d<float, access::sample> asciiAtlas [[texture(2)]],
                        constant Uniforms &uniforms [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]])
{
    float w = float(inputTexture.get_width());
    float h = float(inputTexture.get_height());
    if (gid.x >= uint(w) || gid.y >= uint(h)) return;

    float2 uv = float2(gid) / float2(w, h);
    constexpr sampler s(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    float2 res = float2(w, h);
    float3 outColor; // Variable de salida

    // Grid proporcional
    float columns = max(5.0, uniforms.bayerScale);
    float cellW = w / columns;
    float2 cellSize = float2(cellW, cellW);
    float2 blockCoord = floor(float2(gid) / cellSize) * cellSize;
    float2 samplePos = blockCoord + cellSize * 0.5; // Centro del bloque
    
    if (uniforms.mode > 4.5) { // ASCII
        float3 rgb = adjustColor(inputTexture.read(uint2(samplePos)).rgb, uniforms);
        float gray = dot(rgb, float3(0.299, 0.587, 0.114));
        float charIdx = floor(gray * (uniforms.asciiCharCount - 0.01));
        float2 localUV = fract(float2(gid) / cellSize);
        float2 atlasUV = float2((charIdx + localUV.x) / uniforms.asciiCharCount, localUV.y);
        float mask = asciiAtlas.sample(s, atlasUV).r;
        outColor = (uniforms.isGrayscale > 0.5) ? mix(uniforms.colorDark.rgb, uniforms.colorLight.rgb, mask) : rgb * mask;
    }
    else if (uniforms.mode > 3.5) { // HALFTONE
        float3 rgb = adjustColor(sampleHQ(inputTexture, s, uv, res, cellW * 0.5), uniforms);
        if (uniforms.isGrayscale > 0.5) {
            float pat = halftone(uv, dot(rgb, float3(0.299, 0.587, 0.114)), columns, res, uniforms.spread);
            outColor = mix(uniforms.colorDark.rgb, uniforms.colorLight.rgb, pat);
        } else {
            float mis = uniforms.halftoneMisprint * 0.01;
            outColor = float3(halftone(uv + float2(-mis,-mis), rgb.r, columns, res, uniforms.spread),
                              halftone(uv, rgb.g, columns, res, uniforms.spread),
                              halftone(uv + float2(mis,mis), rgb.b, columns, res, uniforms.spread));
        }
    }
    else if (uniforms.mode > 0.5 && uniforms.mode < 1.5) { // CRT
        float2 wuv = warpUV(uv, uniforms.crtWarp);
        float ab = 0.003 * uniforms.crtWarp;
        float3 signal = adjustColor(float3(inputTexture.sample(s, wuv + float2(ab, 0)).r, inputTexture.sample(s, wuv).g, inputTexture.sample(s, wuv - float2(ab, 0)).b), uniforms);
        float3 mask = float3(0.5 + 0.5 * cos((wuv.x * w) * (2.0 * M_PI_F / (3.0*uniforms.crtScale)) + float3(0, 2.1, 4.2)));
        mask *= mix(1.0, 0.5 + 0.5 * sin((wuv.y * h) * (2.0 * M_PI_F / (6.0*uniforms.crtScale))), uniforms.crtScanline);
        float3 glow = pow(max(float3(0.0), sampleHQ(inputTexture, s, wuv, res, uniforms.crtGlowSpread * 15.0) - 0.1), 2.0) * uniforms.crtGlowIntensity * 5.0;
        outColor = (signal * mask * 1.8) + glow;
        outColor *= 1.0 - (dot(abs(uv-0.5), abs(uv-0.5)) * uniforms.crtVignette * 1.5);
    }
    else { // DIGITAL
        float3 rgb = adjustColor(inputTexture.read(uint2(samplePos)).rgb, uniforms);
        int sx = int(floor(float(gid.x) / cellW));
        int sy = int(floor(float(gid.y) / cellW));
        float n = 0;
        if (uniforms.mode < 0.5) {
             if (uniforms.matrixSize == 0) n = bayer2[sy%2][sx%2];
             else if (uniforms.matrixSize == 1) n = bayer4[sy%4][sx%4];
             else if (uniforms.matrixSize == 2) n = bayer8[sy%8][sx%8];
             else n = getBayer16(sx, sy);
        } else if (uniforms.mode > 2.5) {
             n = fract(hash(float2(sx, sy)) + (float(sx + sy) * 0.33));
        } else {
             n = hash(float2(sx, sy));
        }
        float lv = max(1.0, uniforms.paletteSize - 1.0);
        float noise = (n - 0.5) * ((1.0 / lv) * uniforms.spread);
        if (uniforms.isGrayscale > 0.5) {
            float q = floor((dot(rgb, float3(0.299, 0.587, 0.114)) + noise) * lv + 0.5) / lv;
            outColor = mix(uniforms.colorDark.rgb, uniforms.colorLight.rgb, clamp(q, 0.0, 1.0));
        } else outColor = clamp(floor((rgb + noise) * lv + 0.5) / lv, 0.0, 1.0);
    }

    outputTexture.write(float4(outColor, 1.0), gid);
}
