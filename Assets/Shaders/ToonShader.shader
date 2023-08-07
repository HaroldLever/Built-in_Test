Shader "MyShader/ToonShader"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "gray" {}
        _Normal ("Normal", 2D) = "bump" {}
        _Metalness ("Metalness", 2D) = "black" {}
        _Reflection ("Reflection", 2D) = "black" {}
        _FaceLM ("FaceLM", 2D) = "white" {}
        [Toggle(IS_FACE)] _IsFace ("IsFace", Float) = 0.0
        // (_OutlineWidth, _DepthDiff)
        _OutlineParam ("OutlineParam", Vector) = (5.0, 0.00001,0,0)
        //_OutlineWidth ("OutlineWidth", Range(0.0, 10.0)) = 2.0
        _StepA ("StepA",Range(-1.0, 1.0)) = 0.0
        _StepB ("StepB",Range(-1.0, 1.0)) = 0.2
        // (_RimWidth, _RimDiff, _RimFadeStart, _RimFadeEnd)
        _RimParam ("RimParam", Vector) = (1.0, 1.0, 1.0, 1.5)
    }
    SubShader
    {
        LOD 100

        Pass 
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma multi_compile_shadowcaster

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }

        Pass
        {
            Name "BasePass"
            Tags
            {
                "Queue" = "Geometry"
                "RenderType" = "Opaque" 
                "LightMode" = "ForwardBase"
            }

            ZWrite On
            ZTest LEqual
            Cull Back
            //Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

            #pragma vertex vert             // 顶点函数
            #pragma fragment frag           // 片段函数

            #pragma multi_compile_fog       // 雾相关关键字
            #pragma multi_compile_fwdbase   // ForwardBase相关关键字

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"      // 阴影相关
            #include "Lighting.cginc"       // 灯光相关

            #include "Assets/Shaders/ToonLit.cginc"

            ENDCG
        }

        Pass
        {
            Name "AddPass"
            Tags
            {
                "Queue" = "Geometry"
                "RenderType" = "Opaque" 
                "LightMode" = "ForwardAdd"
            }

            //ZWrite On
            ZTest LEqual
            Cull Back
            Blend One One

            CGPROGRAM
            
            #pragma vertex vert             // 顶点函数
            #pragma fragment frag           // 片段函数

            #pragma multi_compile_fog                   // 雾相关关键字
            #pragma multi_compile_fwdadd_fullshadows    // ForwardAdd相关关键字

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"      // 阴影相关
            #include "Lighting.cginc"       // 灯光相关

            #include "Assets\Shaders\ToonLit.cginc"

            ENDCG
        }

        Pass
        {
            Name "Outline"
            Tags
            {
                "Queue" = "Geometry"
                "RenderType" = "Opaque" 
                "LightMode" = "ForwardBase"
            }

            ZWrite On
            ZTest LEqual
            Cull Front
            //Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

            #pragma vertex vert             // 顶点函数
            #pragma fragment frag           // 片段函数

            #pragma multi_compile_fog       // 雾相关关键字
            #pragma multi_compile_fwdbase   // ForwardBase相关关键字
            #pragma multi_compile_local __ IS_FACE

            #include "UnityCG.cginc"
            //#include "AutoLight.cginc"      // 阴影相关
            //#include "Lighting.cginc"       // 灯光相关

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                UNITY_FOG_COORDS(1)
            };

            float4 _OutlineParam;
            sampler2D _FaceLM;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                float3 norHCS = \
                mul((float3x3)unity_MatrixMVP,v.normal);
                float2 outlineOffset = normalize(norHCS.xy)/_ScreenParams.xy \
                        * o.pos.w * _OutlineParam.x;
                o.normal = v.normal;

                #ifdef IS_FACE
                    float4 faceLM = tex2Dlod(_FaceLM, float4(v.uv, 0.0, 0.0));
                    outlineOffset *= faceLM.b;
                #endif
                
                o.pos.xy += length(outlineOffset) < length(norHCS.xy) * _OutlineParam.y ? \
                        outlineOffset : norHCS.xy * _OutlineParam.y;

                UNITY_TRANSFER_FOG(o,o.pos); 
                return o;
            }

            fixed4 frag(v2f i) : SV_TARGET
            {
                float3 wNor = UnityObjectToWorldNormal(i.normal);
                float3 ambient = ShadeSH9(half4(wNor,1.0));
                fixed4 finalCol = fixed4(ambient*fixed3(0.5,0.2,0.1),1.0);

                UNITY_APPLY_FOG(i.fogCoord, finalCol);

                return finalCol;
            }

            ENDCG

        }

    }
}
