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

[[ stitchable ]] half4 liquidAuraBackdrop(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float intensity,
    half4 color1,
    half4 color2,
    half4 color3,
    half4 baseColor
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;

    float2 p1 = float2(0.28 + 0.22 * cos(time * 0.35), 0.22 + 0.18 * sin(time * 0.42));
    float2 p2 = float2(0.74 + 0.20 * sin(time * 0.29), 0.48 + 0.22 * cos(time * 0.31));
    float2 p3 = float2(0.42 + 0.24 * sin(time * 0.23 + 1.4), 0.78 + 0.16 * cos(time * 0.38));

    float w1 = exp(-length_squared(uv - p1) * 3.2);
    float w2 = exp(-length_squared(uv - p2) * 2.8);
    float w3 = exp(-length_squared(uv - p3) * 3.0);

    half3 aura = (color1.rgb * half(w1) + color2.rgb * half(w2) + color3.rgb * half(w3)) * half(intensity * 0.58);
    float vignette = smoothstep(1.25, 0.15, length(uv - float2(0.5, 0.42)));
    half3 blended = clamp(baseColor.rgb + aura * half(vignette), half3(0.0), half3(1.0));

    return half4(blended, 1.0);
}
