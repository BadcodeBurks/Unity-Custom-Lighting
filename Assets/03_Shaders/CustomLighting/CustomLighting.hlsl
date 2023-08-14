#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED
//#define DEBUG_DISPLAY

//Main Keywords
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _ADDITIONAL_LIGHTS
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile _ADDITIONAL_LIGHT_CALCULATE_SHADOWS
#pragma multi_compile _ _GLOBAL_ILLUMINATION
#pragma multi_compile _ _SHADOWS_SOFT
#pragma multi_compile _ _SCREEN_SPACE_OCCLUSION

//Custom Keywords
#pragma multi_compile _ _USE_STEP_DISTANCE
#pragma multi_compile _ _USE_LUT_FOR_DIFFUSE
#pragma multi_compile _ _USE_RAMP_FOR_DIFFUSE
//May move
//#define _AMBIENT_OCCLUSION

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

uniform float2 _DiffuseRamp;
TEXTURE2D(_LightLut);
SAMPLER(sampler_LightLut);

#ifdef _USE_LUT_FOR_DIFFUSE
float4 GetDiffuseCell(float diffuse)
{
    return SAMPLE_TEXTURE2D(_LightLut, sampler_LightLut, float2(diffuse, 0.5));
}
#endif

float Ramp01(float val, float min, float max)
{
    return saturate((val - min) / (max - min));
}

#ifdef _USE_RAMP_FOR_DIFFUSE
float RampDiffuse(float val)
{
    return Ramp01(val, _DiffuseRamp.x, _DiffuseRamp.y);
}

#endif

#ifdef _USE_STEP_DISTANCE
float NStep(float val, float step)
{
    return ceil(val);//floor(val*step + .5)/step;
}
#endif

float CalculateFresnel(float3 normal, half3 viewDir)
{
    return 1 - saturate(dot(viewDir, normal));
}

#ifdef _CALCULATE_RIM_SPECULAR
half3 CalculateRim(half3 lightColor, float3 lightDir, float3 normal, half3 viewDir, float fresnel)
{
    fresnel = smoothstep(.5, 1, fresnel);
    float3 lightViewDir = lightDir + viewDir;
    float viewDirNormal = dot(normal, lightViewDir);
    half rim = clamp((fresnel-dot(lightViewDir, viewDir) + viewDirNormal), 0, 1) * saturate(1-length(lightViewDir)) * fresnel;
    #ifdef _USE_RAMP_FOR_DIFFUSE
    rim = Ramp01(rim, _DiffuseRamp.x, _DiffuseRamp.y);
    #endif
    
    return lightColor * rim;
}
#endif
#ifdef _SPECULAR_COLOR
half3 CustomSpecular(half3 lightColor, half3 lightDir, half3 normal, half3 viewDir, half4 specular, half smoothness)
{
    float3 halfVec = SafeNormalize(float3(lightDir) + float3(viewDir));
    half NdotH = half(saturate(dot(normal, halfVec)));
    half modifier = pow(NdotH, smoothness);
    half3 specularReflection = specular.rgb * modifier;
    return lightColor * specularReflection;
}
#endif

half3 CalculateCustomLambert(half3 lightColor, half3 lightDirection, half3 normal)
{
    half NdotL = saturate(dot(normal, lightDirection));

    #ifdef _USE_LUT_FOR_DIFFUSE
    NdotL = GetDiffuseCell(NdotL).r;
    #endif
    #ifdef _USE_RAMP_FOR_DIFFUSE
    NdotL = RampDiffuse(NdotL);
    #endif
    return lightColor * NdotL;
}

half3 CalculateCustomBlinnPhong(Light light, InputData inputData, SurfaceData surfaceData, float fresnel)
{
    #ifdef _USE_STEP_DISTANCE
    float distanceAttenuation = NStep(light.distanceAttenuation, 2);
    #else
    float distanceAttenuation = light.distanceAttenuation;
    #endif

    float3 attenuatedLightColor = light.color * (distanceAttenuation * light.shadowAttenuation);
    half3 lightDiffuseColor = CalculateCustomLambert(attenuatedLightColor, light.direction, inputData.normalWS);

    half3 lightSpecularColor = half3(0,0,0);
    #if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
    half smoothness = exp2(5 * surfaceData.smoothness + 1);

    lightSpecularColor += CustomSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, 1), smoothness);
    #endif
    #ifdef _CALCULATE_RIM_SPECULAR
    lightSpecularColor += CalculateRim(light.color, light.direction, inputData.normalWS, inputData.viewDirectionWS, fresnel);
    #endif
    
    return lightDiffuseColor * surfaceData.albedo + lightSpecularColor;
}

half4 CalculateCustomFinalColor(half4 albedo, LightingData lightingData)
{
    half4 litColor = CalculateFinalColor(lightingData, 1);
    litColor = max(litColor, albedo* unity_AmbientSky);
    return litColor;
}

half4 CustomLighting(InputData inputData, SurfaceData surfaceData)
{
    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, debugColor))
    {
        return debugColor;
    }
    #endif

    uint meshRenderingLayers = GetMeshRenderingLayer();
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    float fresnel = CalculateFresnel(inputData.normalWS, inputData.viewDirectionWS);

    
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, aoFactor);

    inputData.bakedGI *= surfaceData.albedo;

    LightingData lightingData = CreateLightingData(inputData, surfaceData);
#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
        lightingData.mainLightColor += CalculateCustomBlinnPhong(mainLight, inputData, surfaceData, fresnel);
    }

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += CalculateBlinnPhong(light, inputData, surfaceData);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += CalculateCustomBlinnPhong(light, inputData, surfaceData, fresnel);
        }
    LIGHT_LOOP_END
    #endif

    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * surfaceData.albedo;
    #endif

    return CalculateCustomFinalColor(half4(surfaceData.albedo, 1), lightingData);
}

void CalculateCustomLighting_float(InputData inputData, SurfaceData surfaceData, out half4 Color) {
    Color = CustomLighting(inputData, surfaceData);
}



#endif