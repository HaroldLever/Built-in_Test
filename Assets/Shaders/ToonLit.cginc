#pragma multi_compile_local __ IS_FACE

struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float4 pos : SV_POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_FOG_COORDS(1)         // 雾坐标
    SHADOW_COORDS(2)            // 阴影坐标
    float4 oPos : TESSFACTOR3;
};

sampler2D _MainTex;         // 主贴图
float4 _MainTex_ST;
sampler2D _Normal;          // 法线贴图
float4 _Normal_ST;
sampler2D _Metalness;       // 金属度贴图
float4 _Metalness_ST;
sampler2D _Reflection;      // 反射球贴图
float4 _Reflection_ST;
sampler2D _FaceLM;          // 脸部光照贴图
float4 _FaceLM_ST;
UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
float4 _CameraDepthTexture_TexelSize;

float _StepA;
float _StepB;
float4x4 _FaceWorldToLocal;
float4 _RimParam;

v2f vert (appdata v)
{
    v2f o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    o.oPos = v.vertex;
    o.normal = v.normal;
    o.tangent = v.tangent;
    UNITY_TRANSFER_FOG(o,o.pos);                // 填充雾
    TRANSFER_SHADOW(o);                          // 填充阴影
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    float3 wPos = mul(unity_ObjectToWorld, i.oPos);
    float3 wNor = normalize(UnityObjectToWorldNormal(i.normal));
    float3 wTan = UnityObjectToWorldDir(i.tangent.xyz);
    float3 wBi = cross(wNor, wTan) * i.tangent.w;
    float3 wLightDir = normalize(UnityWorldSpaceLightDir(wPos));
    float3 wViewDir = normalize(wPos-_WorldSpaceCameraPos);
    
    // 采样贴图
    fixed4 main = tex2D(_MainTex, TRANSFORM_TEX(i.uv, _MainTex));
    fixed4 nor = tex2D(_Normal, TRANSFORM_TEX(i.uv, _Normal));
    fixed4 metal = tex2D(_Metalness, TRANSFORM_TEX(i.uv, _Metalness));
    //fixed4 reflect = tex2D(_Reflection, TRANSFORM_TEX(i.uv, _Reflection));
    
    // 采样阴影
    UNITY_LIGHT_ATTENUATION(shadowAtten, i, wPos)

    // 处理法线贴图
    float3 tSpace0 = float3(wTan.x, wBi.x, wNor.x);
    float3 tSpace1 = float3(wTan.y, wBi.y, wNor.y);
    float3 tSpace2 = float3(wTan.z, wBi.z, wNor.z);

    nor.xy = nor.xy * 2.0 - float2(1.0, 1.0);
    float3 tNor = float3(nor.xy, 1-sqrt(dot(nor.xy, nor.xy)));
    
    wNor = mul(float3x3(tSpace0, tSpace1, tSpace2), tNor);

    // 漫反射
    float nDotL = dot(wLightDir,wNor);
    nDotL = smoothstep(_StepA, _StepB, nDotL);

    #ifdef IS_FACE
        float3 faceLightDir = normalize(mul(_FaceWorldToLocal, float4(wLightDir, 0.0)).xyz);
        float faceStepA = dot(faceLightDir,float3(-1.0, 0.0, 0.0))*0.5+0.5;
        float2 faceUV = float2(faceLightDir.z > 0 ? 1.0-i.uv.x : i.uv.x, i.uv.y);
        fixed4 faceLM = tex2D(_FaceLM, TRANSFORM_TEX(faceUV, _FaceLM));
        float faceLit = smoothstep(1-faceStepA+_StepA, 1-faceStepA+_StepB,faceLM.r);
        nDotL = lerp(faceStepA, faceLit, faceLM.a);
    #endif

    float3 diffuse = max(nDotL, 0.0) * _LightColor0.rgb * shadowAtten;

    #ifndef UNITY_PASS_FORWARDADD
        // 反射球
        float3 vNor = mul(unity_MatrixV, float4(wNor, 0.0)).xyz;
        float3 vViewDir = mul(unity_MatrixV, float4(wViewDir, 0.0)).xyz;
        float2 sNor = vViewDir.xy * vNor.z - vNor.xy * vViewDir.z;
        fixed4 reflect = tex2D(_Reflection, sNor.xy*0.5+float2(0.5, 0.5));
        reflect.rgb *= metal.b;

        // 边缘光
        float4 screenPos = ComputeScreenPos(UnityObjectToClipPos(i.oPos));
        screenPos.xy /= screenPos.w;
        _RimParam.y /= _ProjectionParams.z - _ProjectionParams.y;

        float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,screenPos.xy));
        float depthDiff = 
                Linear01Depth(
                    SAMPLE_DEPTH_TEXTURE(
                        _CameraDepthTexture,screenPos.xy + float2(
                            _RimParam.x * _CameraDepthTexture_TexelSize.x, 0.0)))\
                - depth > _RimParam.y ? 1.0 : 0.0;
        depthDiff += 
                Linear01Depth(
                    SAMPLE_DEPTH_TEXTURE(
                        _CameraDepthTexture,screenPos.xy + float2(
                            -_RimParam.x * _CameraDepthTexture_TexelSize.x, 0.0)))\
                - depth > _RimParam.y ? 1.0 : 0.0;
        depthDiff += 
                Linear01Depth(
                    SAMPLE_DEPTH_TEXTURE(
                        _CameraDepthTexture,screenPos.xy + float2(
                            0.0, _RimParam.x * _CameraDepthTexture_TexelSize.y)))\
                - depth > _RimParam.y ? 1.0 : 0.0;
        depthDiff += 
                Linear01Depth(
                    SAMPLE_DEPTH_TEXTURE(
                        _CameraDepthTexture,screenPos.xy + float2(
                            0.0, -_RimParam.x * _CameraDepthTexture_TexelSize.y)))\
                - depth > _RimParam.y ? 1.0 : 0.0;
        depthDiff = saturate(depthDiff);

        _RimParam.zw /= _ProjectionParams.z - _ProjectionParams.y;
        float rimFadeFactor = saturate((_RimParam.w - depth) / (_RimParam.w - _RimParam.z));
        depthDiff *= rimFadeFactor;

        // 环境光
        half3 ambient = \
                ShadeSH9(half4(1.0, 0.0, 0.0, 1.0))+\
                ShadeSH9(half4(-1.0, 0.0, 0.0, 1.0))+\
                ShadeSH9(half4(0.0, 1.0, 0.0, 1.0))+\
                ShadeSH9(half4(0.0, -1.0, 0.0, 1.0))+\
                ShadeSH9(half4(0.0, 0.0, 1.0, 1.0))+\
                ShadeSH9(half4(0.0, 0.0, -1.0, 1.0));
        ambient /= 6.0;
        //half3 ambient = ShadeSH9(half4(wNor, 1.0));
        ambient += ambient * reflect.rgb + ambient * depthDiff;

        // 最终颜色
        fixed4 finalCol = fixed4(0.5, 0.5, 0.0, 1.0);
        finalCol.rgb = (diffuse + ambient) * main;

    #else
        fixed4 finalCol = fixed4(0.5, 0.5, 0.0, 1.0);
        finalCol.rgb = diffuse * main;
    #endif // #ifndef UNITY_PASS_FORWARDADD

    // 应用雾
    UNITY_APPLY_FOG(i.fogCoord, finalCol);

    return finalCol;
}