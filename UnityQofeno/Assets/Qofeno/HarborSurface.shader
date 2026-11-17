Shader "Qofeno/Harbor Surface"
{
    Properties
    {
        _Color ("Tint", Color) = (1,1,1,1)
        _MainTex ("Surface or print atlas", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.28
        _EmissionColor ("Emission", Color) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        CGINCLUDE
        #include "UnityCG.cginc"

        #if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
        #include "UnityLightingCommon.cginc"
        #include "AutoLight.cginc"

        sampler2D _MainTex;
        float4 _MainTex_ST;
        half4 _Color, _EmissionColor;
        half _Glossiness;

        struct SurfaceVaryings
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 worldPos : TEXCOORD1;
            half3 normal : TEXCOORD2;
            UNITY_LIGHTING_COORDS(3,4)
            UNITY_FOG_COORDS(5)
            #ifdef UNITY_PASS_FORWARDBASE
                half3 indirect : TEXCOORD6;
            #endif
        };

        SurfaceVaryings SurfaceVertex(appdata_base v)
        {
            SurfaceVaryings o;
            UNITY_INITIALIZE_OUTPUT(SurfaceVaryings, o);
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
            o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
            o.normal = UnityObjectToWorldNormal(v.normal);
            UNITY_TRANSFER_LIGHTING(o, float2(0,0));
            UNITY_TRANSFER_FOG(o, o.pos);
            #ifdef UNITY_PASS_FORWARDBASE
                o.indirect = max(0, ShadeSH9(half4(o.normal, 1)));
                #ifdef VERTEXLIGHT_ON
                    o.indirect += Shade4PointLights(unity_4LightPosX0, unity_4LightPosY0,
                        unity_4LightPosZ0, unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                        unity_LightColor[2].rgb, unity_LightColor[3].rgb, unity_4LightAtten0,
                        o.worldPos, o.normal);
                #endif
            #endif
            return o;
        }

        half4 SurfaceFragment(SurfaceVaryings i) : SV_Target
        {
            half3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
            half3 normal = normalize(i.normal);
            half3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
            half3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
            half3 halfDir = normalize(lightDir + viewDir);
            half diffuse = saturate(dot(normal, lightDir));
            half gloss = pow(saturate(dot(normal, halfDir)), lerp(8.0h, 48.0h, _Glossiness));
            UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
            half3 direct = _LightColor0.rgb * (diffuse * attenuation);
            half4 color = half4((albedo + 0.18h * _Glossiness * gloss) * direct, 1);
            #ifdef UNITY_PASS_FORWARDBASE
                color.rgb += albedo * i.indirect + _EmissionColor.rgb;
            #endif
            UNITY_APPLY_FOG(i.fogCoord, color);
            return color;
        }
        #endif
        ENDCG

        // Each draw uses one object transform. Android GPUs with small uniform blocks
        // can render the same material on the combined harbor meshes and on loose stock.
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma target 2.0
            #pragma vertex SurfaceVertex
            #pragma fragment SurfaceFragment
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap
            #pragma multi_compile_fog
            ENDCG
        }

        Pass
        {
            Tags { "LightMode"="ForwardAdd" }
            Blend One One
            ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #pragma target 2.0
            #pragma vertex SurfaceVertex
            #pragma fragment SurfaceFragment
            #pragma multi_compile_fwdadd
            #pragma multi_compile_fog
            ENDCG
        }

        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            CGPROGRAM
            #pragma target 2.0
            #pragma vertex ShadowVertex
            #pragma fragment ShadowFragment
            #pragma multi_compile_shadowcaster

            struct ShadowVaryings { V2F_SHADOW_CASTER; };

            ShadowVaryings ShadowVertex(appdata_base v)
            {
                ShadowVaryings o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 ShadowFragment(ShadowVaryings i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    Fallback Off
}
