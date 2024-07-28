Shader "Dreams of Infinite Glass/Futile/Enhanced Level Color (Preview)"
{
	Properties
	{
		[Header(Primary Data)]
		[NoScaleOffset] _MainTex("Level Texture", 2D) = "white" {}
		[NoScaleOffset] _PalTex("Primary Palette Texture", 2D) = "black" {}
		
		[Header(Preview Only Data)]
		[NoScaleOffset] _PalTex2("Fade Palette Texture", 2D) = "black" {}
		_PalTexFade("Fade Palette Intensity", Range(0, 1)) = 0
		[IntRange] _EffectColorA("Effect Color A", Range(-1, 22)) = -1 
		[IntRange] _EffectColorB("Effect Color B", Range(-1, 22)) = -1 
		
		[ToggleOff(USING_FULL_PALETTE)] _isHalfPalette("Using Half (8px tall) Palettes", Float) = 1
		_RainDarkness("Rain Intensity (Full Palettes Only!)", Range(0, 1)) = 0
		
		[Space(12)]
		[Header(DevTools Values)]
		_devToolsFogIntensity("DevTools Fog Intensity", Range(0, 1)) = 0
		_waterLevel("Expected Water Level", Range(0, 1)) = 0
		_Grime("Grime Intensity", Range(0, 1)) = 0
		[Toggle(IS_SWARM_ROOM)] IS_SWARM_ROOM("Is Swarm Room", Float) = 0
		[Toggle(_)] _WetTerrain("Enable Wet Terrain", Float) = 0
		_cloudsSpeed("Cloud Scroll Speed", Float) = 0
		_hue("Hue", Range(0, 359)) = 0
		_saturation("Saturation", Range(0, 1)) = 0
		_brightness("Brightness", Range(0, 1)) = 0
		_contrast("Contrast", Range(0, 1)) = 0
		_darkness("Darkness", Range(0, 1)) = 0
		
		[Space(12)]
		[Header(Misc.)]
		[Toggle(RIMFIX_ON)] _rimFix("Rim Fix", Float) = 0
		_AboveCloudsAtmosphereColor("Above-Cloud Atmosphere Color (Rim Fix Only)", Color) = (1, 1, 1, 1)
		
		
		[Space(12)]
		[Header(Internal Data)]
		[NoScaleOffset] _NoiseTex("Noise Texture", 2D) = "black" {}
		[NoScaleOffset] _EffectsTex("Effects Texture", 2D) = "white" {}
		_lightDirAndPixelSize("_lightDirAndPixelSize", Vector) = (0, 0, 1, 1)
		_spriteRect("_spriteRect", Vector) = (0, 0, 1, 1)
		_screenSize("_screenSize", Vector) = (1366, 768, 0, 0)
		_screenPos("_screenPos", Vector) = (0, 0, 0, 0)
		_screenOffset("_screenOffset", Vector) = (0, 0, 0, 0)
		//_palette("_palette", Float) = 0
		//_light("_light", Float) = 0
		
		[Space(12)]
		[Header(SILICA Renderer Specifics)]
		[Toggle(VIRTUAL_FX_ON)] _virtualFX("[SILICA] Virtual FX", Float) = 0
		[Toggle(USE_EXACT_PROP_COLORS_ON)] _exactPropColors("[SILICA] Use Exact Prop Colors", Float) = 0
		
	}
	SubShader
	{
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One
		Cull Off

		GrabPass { } 
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 4.0 // Use target 4.0 for optimized branching behavior.
			#pragma multi_compile _ PROPERTY_STATIC_BRANCHES_AVAILABLE 
			#pragma multi_compile _ SUNLIGHT_STATIC_BRANCHES_AVAILABLE
			#pragma multi_compile _ RIMFIX_ON 
			#pragma multi_compile _ GRIME_ON 
			#pragma multi_compile _ IS_SWARM_ROOM
			#pragma multi_compile _ SUNLIGHT_RENDERING_ON 
			#pragma multi_compile _ OPTIMIZE_FOR_COHERENT_SUNLIGHT 
			#pragma multi_compile _ OPTIMIZE_FOR_COHERENT_SKY
			
			// Some special effects:
			#pragma multi_compile _ VIRTUAL_FX_ON
			#pragma multi_compile _ USE_EXACT_PROP_COLORS_ON
			
			// And preview settings:
			#pragma multi_compile _ USING_FULL_PALETTE
			
			// #define DEBUG_MODE
			#define IS_EDITOR_LEVEL_SHADER
			
#ifdef DEBUG_MODE
			#define GRIME_ON
			#define SUNLIGHT_RENDERING_ON
			#define SUNLIGHT_STATIC_BRANCHES_AVAILABLE
			#define OPTIMIZE_FOR_COHERENT_SUNLIGHT
			#define OPTIMIZE_FOR_NO_EXPOSED_SKY
			#define PROPERTY_STATIC_BRANCHES_AVAILABLE
#endif

			#include "UnityCG.cginc"
			#include "LevelCommon.cginc"
			#include "LevelFX.cginc"
			DECLARE_VERTEX_PROGRAM(vert, v2f)
			#define ALREADY_DECLARED_LEVEL_V2F
			#include "FogShaderEditor.cginc"
			#include "LevelFragment.cginc"
			
			ENDCG
		}
	}
}
