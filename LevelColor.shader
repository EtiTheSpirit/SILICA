Shader "Dreams of Infinite Glass/Futile/Enhanced Level Color"
{
	Properties { }
	SubShader
	{
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
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

			#include "UnityCG.cginc"
			#include "LevelCommon.cginc"
			#include "LevelFX.cginc"
			#include "LevelFragment.cginc"
			
			ENDCG
		}
	}
}
