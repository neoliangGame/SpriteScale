//sprite指定方向压缩变形
Shader "neo/directionScale"
{
	Properties
	{
		[PerRendererData] _MainTex("Sprite Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1,1,1,1)
		[MaterialToggle] PixelSnap("Pixel snap", Float) = 0
		[HideInInspector] _RendererColor("RendererColor", Color) = (1,1,1,1)
		[HideInInspector] _Flip("Flip", Vector) = (1,1,1,1)
		[PerRendererData] _AlphaTex("External Alpha", 2D) = "white" {}
		[PerRendererData] _EnableExternalAlpha("Enable External Alpha", Float) = 0
		_Pivot("Pivot", Vector) = (1,1,0,0)
		_Strength("Direction Strength", Range(0,10)) = 1
		_Scale("Vertical Scale", Range(0.1,10)) = 1
	}

	SubShader
	{
		Tags
		{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
			"PreviewType" = "Plane"
			"CanUseSpriteAtlas" = "True"
		}

		Cull Off
		Lighting Off
		ZWrite Off
		Blend One OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex SpriteVert
			#pragma fragment SpriteFrag
			#pragma target 2.0
			#pragma multi_compile_instancing
			#pragma multi_compile _ PIXELSNAP_ON
			#pragma multi_compile _ ETC1_EXTERNAL_ALPHA
			


			#ifndef UNITY_SPRITES_INCLUDED
			#define UNITY_SPRITES_INCLUDED

			#include "UnityCG.cginc"

			#ifdef UNITY_INSTANCING_ENABLED
				UNITY_INSTANCING_CBUFFER_START(PerDrawSprite)
					fixed4 unity_SpriteRendererColorArray[UNITY_INSTANCED_ARRAY_SIZE];
					float4 unity_SpriteFlipArray[UNITY_INSTANCED_ARRAY_SIZE];
				UNITY_INSTANCING_CBUFFER_END

				#define _RendererColor unity_SpriteRendererColorArray[unity_InstanceID]
				#define _Flip unity_SpriteFlipArray[unity_InstanceID]
			#endif // instancing

			CBUFFER_START(UnityPerDrawSprite)
				#ifndef UNITY_INSTANCING_ENABLED
					fixed4 _RendererColor;
					float4 _Flip;
				#endif
				float _EnableExternalAlpha;
			CBUFFER_END

			fixed4 _Color;
			float4 _Pivot;
			float _Scale;

			struct appdata_t
			{
				float4 vertex   : POSITION;
				float4 color    : COLOR;
				float2 texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 vertex   : SV_POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
				float4 dir : COLOR1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			//叉乘判断两点是否在直线的同一侧
			int IsTwoDotTheSameSide(fixed2 line1, fixed2 line2, fixed2 nodeA, fixed2 nodeB) {
				fixed2 vecLine = line2 - line1;
				fixed2 vecA = nodeA - line1;
				fixed2 vecB = nodeB - line1;
				fixed crossA = vecA.x * vecLine.y - vecA.y * vecLine.x;
				fixed crossB = vecB.x * vecLine.y - vecB.y * vecLine.x;
				fixed crossValue = crossA * crossB;
				crossValue = step(0, crossValue);
				crossValue = crossValue * 2 - 1;
				return crossValue;
			}

			v2f SpriteVert(appdata_t IN)
			{
				v2f OUT;

				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

				#ifdef UNITY_INSTANCING_ENABLED
					IN.vertex.xy *= _Flip.xy;
				#endif
				//计算拉伸方向
				//不拉伸，只对拉伸方向进行径向模糊
				float3 localPivot = mul(_Pivot.xyz, unity_WorldToObject);
				OUT.dir = float4(IN.vertex.xy - localPivot.xy, 0, 0);
				OUT.dir = normalize(OUT.dir);
				//对拉伸的垂直方向进行压缩
				//获取拉伸垂直向量
				float2 verDir = float2(-localPivot.y, localPivot.x);
				verDir = normalize(float3(verDir, 0)).xy;
				//纠正垂直方向与点方向是否一致
				fixed isSameSide = IsTwoDotTheSameSide(fixed2(0,0), localPivot.xy, verDir, IN.vertex.xy);
				verDir *= isSameSide;
				//顶点压缩比例与【顶点达到拉伸方向直线的垂直距离】成正比
				float len = dot(verDir, IN.vertex.xy);
				IN.vertex.xy -= verDir * _Scale * len;
				//正常赋值
				OUT.vertex = UnityObjectToClipPos(IN.vertex);
				OUT.texcoord = IN.texcoord;
				OUT.color = IN.color * _Color * _RendererColor;

				#ifdef PIXELSNAP_ON
					OUT.vertex = UnityPixelSnap(OUT.vertex);
				#endif

				return OUT;
			}

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			sampler2D _AlphaTex;

			float _Strength;

			fixed4 SampleSpriteTexture(float2 uv)
			{
				fixed4 color = tex2D(_MainTex, uv);

				#if ETC1_EXTERNAL_ALPHA
					fixed4 alpha = tex2D(_AlphaTex, uv);
					color.a = lerp(color.a, alpha.r, _EnableExternalAlpha);
				#endif

				return color;
			}

			fixed4 SpriteFrag(v2f IN) : SV_Target
			{
				//拉伸方向径向模糊
				fixed4 col = SampleSpriteTexture(IN.texcoord);
				float2 strenTexel = _MainTex_TexelSize.xy * _Strength;
				col += SampleSpriteTexture(IN.texcoord + strenTexel * IN.dir.xy * 1);
				col += SampleSpriteTexture(IN.texcoord + strenTexel * IN.dir.xy * 2);
				col += SampleSpriteTexture(IN.texcoord + strenTexel * IN.dir.xy * 3);
				col += SampleSpriteTexture(IN.texcoord + strenTexel * IN.dir.xy * 4);
				col += SampleSpriteTexture(IN.texcoord + strenTexel * IN.dir.xy * 5);
				col += SampleSpriteTexture(IN.texcoord + strenTexel * IN.dir.xy * 6);
				col /= 7;

				col *= IN.color;
				col.rgb *= col.a;
				return col;
			}
			#endif // UNITY_SPRITES_INCLUDED
			ENDCG
		}
	}
}
