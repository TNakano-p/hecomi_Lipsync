﻿#ifndef VRMC_MATERIALS_MTOON_LIGHTING_MTOON_INCLUDED
#define VRMC_MATERIALS_MTOON_LIGHTING_MTOON_INCLUDED

#include <UnityShaderVariables.cginc>
#include "./vrmc_materials_mtoon_define.hlsl"
#include "./vrmc_materials_mtoon_utility.hlsl"
#include "./vrmc_materials_mtoon_input.hlsl"
#include "./vrmc_materials_mtoon_lighting_unity.hlsl"

struct MToonInput
{
    float2 uv;
    half3 normalWS;
    half3 viewDirWS;
    half3 litColor;
    half alpha;
    half outlineFactor;
};

inline half GetMToonLighting_Reflectance_ShadingShift(const MToonInput input)
{
    if (MToon_IsParameterMapOn())
    {
        return UNITY_SAMPLE_TEX2D(_ShadingShiftTex, input.uv).r * _ShadingShiftTexScale + _ShadingShiftFactor;
    }
    else
    {
        return _ShadingShiftFactor;
    }
}

inline half GetMToonLighting_Reflectance(const UnityLighting lighting, const MToonInput input)
{
    const half dotNL = dot(input.normalWS, lighting.directLightDirection);
    const half shadingInput = lerp(-1, 1, mtoon_linearstep(-1, 1, dotNL) * lighting.directLightAttenuation);
    const half shadingShift = GetMToonLighting_Reflectance_ShadingShift(input);
    const half shadingToony = _ShadingToonyFactor;
    return mtoon_linearstep(-1.0 + shadingToony, +1.0 - shadingToony, shadingInput + shadingShift);
}

inline half3 GetMToonLighting_DirectLighting(const UnityLighting unityLight, const MToonInput input, const half reflectance)
{
    if (MToon_IsForwardBasePass())
    {
        const half3 shadeColor = UNITY_SAMPLE_TEX2D(_ShadeTex, input.uv).rgb * _ShadeColor.rgb;

        return lerp(shadeColor, input.litColor, reflectance) * unityLight.directLightColor;
    }
    else
    {
        return input.litColor * reflectance * unityLight.directLightColor * 0.5;
    }
}

inline half3 GetMToonLighting_GlobalIllumination(const UnityLighting unityLight, const MToonInput input)
{
    if (MToon_IsForwardBasePass())
    {
        return input.litColor * lerp(unityLight.indirectLight, unityLight.indirectLightEqualized, _GiEqualization);
    }
    else
    {
        return 0;
    }

}

inline half3 GetMToonLighting_Emissive(const MToonInput input)
{
    if (MToon_IsForwardBasePass() && MToon_IsEmissiveMapOn())
    {
        return UNITY_SAMPLE_TEX2D(_EmissionMap, input.uv).rgb * _EmissionColor.rgb;
    }
    else
    {
        return _EmissionColor.rgb;
    }
}

inline half3 GetMToonLighting_Rim_Matcap(const MToonInput input)
{
    if (MToon_IsParameterMapOn())
    {
        const half3 worldUpWS = half3(0, 1, 0);
        // TODO: use view space axis if abs(dot(viewDir, worldUp)) == 1.0
        const half3 matcapRightAxisWS = normalize(cross(input.viewDirWS, worldUpWS));
        const half3 matcapUpAxisWS = normalize(cross(matcapRightAxisWS, input.viewDirWS));
        const half2 matcapUv = float2(dot(matcapRightAxisWS, input.normalWS), dot(matcapUpAxisWS, input.normalWS)) * 0.5 + 0.5;
        return UNITY_SAMPLE_TEX2D(_MatcapTex, matcapUv).rgb;
    }
    else
    {
        return 0;
    }
}

inline half3 GetMToonLighting_Rim(const MToonInput input, const half3 lighting)
{
    if (MToon_IsForwardBasePass())
    {
        const half3 parametricRimFactor = pow(saturate(1.0 - dot(input.normalWS, input.viewDirWS) + _RimLift), _RimFresnelPower) * _RimColor.rgb;
        const half3 rimLightingFactor = lerp(half3(1, 1, 1), lighting, _RimLightingMix);
        const half3 matcapFactor = GetMToonLighting_Rim_Matcap(input);
        return (matcapFactor + parametricRimFactor) * UNITY_SAMPLE_TEX2D(_RimTex, input.uv).rgb * rimLightingFactor;
    }
    else
    {
        return 0;
    }
}

half4 GetMToonLighting(const UnityLighting unityLight, const MToonInput input)
{
    const half reflectance = GetMToonLighting_Reflectance(unityLight, input);

    const half3 direct = GetMToonLighting_DirectLighting(unityLight, input, reflectance);
    const half3 indirect = GetMToonLighting_GlobalIllumination(unityLight, input);
    const half3 lighting = direct + indirect;
    const half3 emissive = GetMToonLighting_Emissive(input);
    const half3 rim = GetMToonLighting_Rim(input, lighting);

    const half3 baseCol = lighting + emissive + rim;
    const half3 outlineCol = _OutlineColor.rgb * lerp(half3(1, 1, 1), baseCol, _OutlineLightingMix);

    const half3 col = lerp(baseCol, outlineCol, input.outlineFactor);

    return half4(col, input.alpha);
}

#endif
