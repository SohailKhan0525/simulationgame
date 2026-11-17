Shader "Qofeno/World Text"
{
    Properties
    {
        _MainTex ("Font atlas", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Pass
        {
            Cull Off
            ZWrite Off
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct Vertex
            {
                float4 position : POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };
            struct Interpolators
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };
            sampler2D _MainTex;

            Interpolators vert(Vertex input)
            {
                Interpolators output;
                output.position = UnityObjectToClipPos(input.position);
                output.uv = input.uv;
                output.color = input.color;
                return output;
            }

            fixed4 frag(Interpolators input) : SV_Target
            {
                return fixed4(input.color.rgb, input.color.a * tex2D(_MainTex, input.uv).a);
            }
            ENDCG
        }
    }
}
