#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float sdRoundBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

[[ stitchable ]] half4 liquidGlassLens(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float cornerRadius,
    float intensity,
    float phase,
    half4 tintColor
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float2 centered = position - safeSize * 0.5;
    float2 halfExtents = safeSize * 0.5;
    float r = clamp(cornerRadius, 2.0, min(halfExtents.x, halfExtents.y));

    float dist = sdRoundBox(centered, halfExtents, r);
    float edgeZone = clamp(1.0 + dist / 28.0, 0.0, 1.0);
    float rimFactor = pow(edgeZone, 2.4) * clamp(intensity, 0.0, 1.0);

    float2 normal = normalize(centered + float2(0.0001));
    float2 refractOffset = -normal * rimFactor * 9.5;
    float2 dispersion = normal * rimFactor * 2.1;

    half4 sampleR = layer.sample(position + refractOffset + dispersion);
    half4 sampleG = layer.sample(position + refractOffset);
    half4 sampleB = layer.sample(position + refractOffset - dispersion);
    half4 refracted = half4(sampleR.r, sampleG.g, sampleB.b, sampleG.a);

    float diagonal = (uv.x * 0.68 - uv.y * 0.73) + sin(phase * 0.6) * 0.12;
    float sheen = smoothstep(0.18, 0.0, abs(diagonal - 0.12)) * 0.09 * intensity;
    float topGlow = smoothstep(0.55, 0.0, uv.y) * 0.11 * intensity;
    float rimHighlight = pow(edgeZone, 5.0) * 0.24 * intensity;

    half3 glassTint = mix(refracted.rgb, tintColor.rgb, half(tintColor.a * 0.22 * intensity));
    half3 specular = half3(sheen + topGlow + rimHighlight);
    half3 finalRGB = clamp(glassTint + specular, half3(0.0), half3(1.0));

    return half4(finalRGB, refracted.a);
}

static float auraHash(float2 p) {
    p = fract(p * float2(127.1, 311.7));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

static float auraNoise(float2 p) {
    float2 cell = floor(p);
    float2 local = fract(p);
    local = local * local * (3.0 - 2.0 * local);

    float a = auraHash(cell);
    float b = auraHash(cell + float2(1.0, 0.0));
    float c = auraHash(cell + float2(0.0, 1.0));
    float d = auraHash(cell + float2(1.0, 1.0));

    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

static float auraFbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 2; octave++) {
        value += amplitude * auraNoise(p);
        p = p * 2.07 + float2(13.7, 7.3);
        amplitude *= 0.5;
    }
    return value;
}

[[ stitchable ]] half4 liquidAuraBackdrop(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float intensity,
    float focusY,
    float bass,
    float mid,
    float high,
    float overall,
    half4 color1,
    half4 color2,
    half4 color3
) {
    float2 safeSize = max(size, float2(1.0));
    float aspect = safeSize.x / safeSize.y;
    float2 uv = position / safeSize;
    float2 p = float2((uv.x - 0.5) * aspect, uv.y - focusY);

    // Domain-warped field. The noise reshapes the falloff so the light never reads as a circle.
    float drift = 0.20 + mid * 0.16;
    float2 q = p * 3.2 + float2(time * drift, -time * drift * 0.7);
    float2 warp = float2(
        auraFbm(q + float2(0.0, time * 0.05)),
        auraFbm(q + float2(5.2, 1.7) - float2(time * 0.04, 0.0))
    );
    float warpAmp = 3.0 + mid * 1.5;
    float field = auraFbm(q + (warp - 0.5) * warpAmp);
    float grain = auraNoise(q * 3.9 + float2(time * 0.22, -time * 0.18));

    float radius = length(p);
    float core = exp(-radius * radius * (5.6 - bass * 1.6));
    float halo = exp(-radius * 3.0);
    float body = core * (0.45 + field * 1.0) + halo * (0.06 + field * 0.14);
    body += high * 0.14 * (grain - 0.35);
    body = max(body, 0.0);

    float mixA = smoothstep(0.20, 0.80, field + (warp.x - 0.5) * 0.35);
    float mixB = smoothstep(0.28, 0.92, field * 0.70 + warp.y * 0.55);
    half3 tint = mix(color1.rgb, color2.rgb, half(mixA));
    tint = mix(tint, color3.rgb, half(mixB * 0.8));

    float edge = 1.0 - smoothstep(0.36, 1.0, radius);
    float mask = clamp(body * edge, 0.0, 1.4);
    float glow = intensity * (0.60 + bass * 0.25) * (1.0 + overall * 0.30);

    half3 lit = currentColor.rgb + tint * half(glow) * half(mask);
    float dither = (auraHash(position * 0.61 + float2(7.0, 13.0)) - 0.5) * (1.0 / 255.0);
    lit += half3(half(dither));
    return half4(clamp(lit, half3(0.0), half3(1.0)), 1.0);
}
