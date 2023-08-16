Shader "Unlit/CustomLit"
{
    Properties
    {
    	_TintColor ("Tint Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
	    [Toggle(_NORMALMAP)] _NormalMapEnabled ("Normal Map Enabled", Float) = 0.0
        [NoScaleOffset]_NormalMap ("Normal Texture", 2D) = "bump" {}
    	_NormalStrength ("Normal Strength", float) = 0.5
        [NoScaleOffset]_RoughnessMap ("Roughness Map", 2D) = "white" {}
    	_Smoothness ("Smoothness", Range(0,1)) = 0.5
    	[Toggle(_CALCULATE_RIM_SPECULAR)] _RimSpecular ("Rim Specular", Float) = 0.0
    	[Toggle(_SPECULAR_COLOR)] _SpecularColor ("Specular Color", Float) = 0.0
        _SpecularStrength ("Specular Strength", Range(0,2)) = 0.5
    	[Toggle(_EMISSION)] _Emission ("Emission", Float) = 0.0
		[NoScaleOffset]_EmissionMap ("Emission Map", 2D) = "white" {}
    	[HDR]_EmissionColor ("Emission Color", Color) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        cull back
        LOD 100

        Pass
        {
            HLSLPROGRAM
            
            #pragma multi_compile_instancing
            #pragma multi_compile _ _SPECULAR_COLOR
            #pragma multi_compile _ _CALCULATE_RIM_SPECULAR
            #pragma multi_compile _ _NORMALMAP
            #pragma multi_compile _ _EMISSION
            #include "CustomLighting.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _fog
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)

                float4 _MainTex_ST;

            CBUFFER_END

            struct appdata
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            	#ifdef _NORMALMAP
            	float4 tangent : TANGENT;
            	#endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 world : TEXCOORD1;
                float3 normal : TEXCOORD2;
            	#ifdef _NORMALMAP
            	float3 binormal : TEXCOORD3;
            	float3 tangent : TEXCOORD4;
            	#endif
            	//UNITY_FOG_COORDS(1)
            	
                //if shader need a view direction, use below code in shader 
                //float3 WorldSpaceViewDirection : TEXCOORD3;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                
                o.pos = TransformObjectToHClip(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
            	o.world = TransformObjectToWorld(v.pos);
                o.normal = TransformObjectToWorldNormal(v.normal);
				#ifdef _NORMALMAP
            	o.tangent = TransformObjectToWorldNormal(v.tangent);
            	float sgn = v.tangent.w;
            	o.binormal = normalize(sgn * cross(o.normal, o.tangent.xyz));
				#endif
                //UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #ifdef _NORMALMAP
            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
			float _NormalStrength;
            #endif
            TEXTURE2D(_RoughnessMap); SAMPLER(sampler_RoughnessMap);
			#ifdef _EMISSION
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
			float4 _EmissionColor;
            #endif
            
            half4 _TintColor;
            float _Smoothness;
            float _SpecularStrength;
            half4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                // sample the texture
				half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _TintColor;
            	clip(albedo.a - .5);
                half4 roughness = SAMPLE_TEXTURE2D(_RoughnessMap, sampler_RoughnessMap, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _Smoothness;;

            	#ifdef _NORMALMAP
            	float3 normal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv * _MainTex_ST.xy + _MainTex_ST.zw));
				normal = normalize(normal);
            	
            	float3x3 TBN = float3x3(normalize(i.tangent), normalize(i.binormal), normalize(i.normal));
            	TBN = transpose(TBN);
				i.normal = normalize(lerp(i.normal, mul(TBN, normal), _NormalStrength));
            	#else
            	i.normal = normalize(i.normal);
            	#endif
            	
            	
            	InputData inputData = (InputData)0;
            	inputData.positionWS = i.world;
            	inputData.normalWS = i.normal;
            	inputData.positionCS = i.pos;
            	inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.world);
            	inputData.shadowCoord = TransformWorldToShadowCoord(i.world);
            	//inputData.normalizedScreenSpaceUV = ComputeScreenPos()

            	SurfaceData surfaceData = (SurfaceData)0;
            	surfaceData.albedo = albedo.rgb;
            	surfaceData.alpha = albedo.a;
            	surfaceData.smoothness = roughness;
            	#ifdef _SPECULAR_COLOR
            	surfaceData.specular = _SpecularStrength;
				#endif
            	#ifdef _EMISSION
            	surfaceData.emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, i.uv * _MainTex_ST.xy + _MainTex_ST.zw) * _EmissionColor;
            	#endif
            	
                CalculateCustomLighting_float(inputData, surfaceData, albedo);
                albedo.w = 1;
                // apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);
                return albedo;
            }
            ENDHLSL
        }
         Pass {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
            
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appData {
	            float3 positionOS : POSITION;
	            float3 normalOS : NORMAL;
            };

            struct v2f {
	            float4 positionCS : SV_POSITION;
            };

            float3 _LightDirection;

            float4 GetShadowCasterPositionCS(float3 positionWS, float3 normalWS) {
	            float3 lightDirectionWS = _LightDirection;
	            float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
            #if UNITY_REVERSED_Z
	            positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
	            positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif
	            return positionCS;
            }

            v2f vert(appData input) {
	            v2f output;

	            VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
	            VertexNormalInputs normInputs = GetVertexNormalInputs(input.normalOS);

	            output.positionCS = GetShadowCasterPositionCS(posnInputs.positionWS, normInputs.normalWS);
	            return output;
            }

            float4 frag(v2f input) : SV_TARGET {
	            return 0;
            }
            ENDHLSL
        }
	}
}