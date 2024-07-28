#ifndef __XFUTILE_LEVEL_COMMON__
#define __XFUTILE_LEVEL_COMMON__
// This cginc file declares the code common across level shaders.

// WARNING TO FUTURE MAINTAINERS:
// This is a bit of a mess. I'm sorry.
// With the addition of a variation of this shader that can be used in-editor to preview levels, a lot of weird tricks had to be done.
// The most notable of these tricks was delegating stuff like palette blending/fading and effect colors to the shader itself,
// which requires a lot of really strange code and a *lot* of static branching.

// As a benefit to this, you can do the following:
// 1: Use this in the Unity editor to preview your levels on a quad with full RW settings control.
// 2: Use this in-game.

// It was originally made for the level renderer dubbed "SILICA" that I made for my mod, which supported moving parts of the world
// as well as GPU-bound effects for advanced behavior, but this never came into fruition.

// PART 0 // VALUES YOU CAN #DEFINE //
// #define DEBUG_MODE				// This will tell the level shader to use Unity's timer instead of _RAIN for animated effects.
//									// This will also prepare the shader to use properties instead of uniforms.
// #define IS_EDITOR_LEVEL_SHADER	// This will tell the system to enable all features for use in the unity editor and/or a preview app.



// VALUES YOU CAN USE //
// DECLARE_VERTEX_PROGRAM(programName, structName)		Declares the minimal vertex program used by level shaders.
// DECLARE_RW_SCREEN_POS(type, varName)					Declares a variable with the provided name that includes the adjusted screen position of the level texture.
//														Usually type should be half2.		
// DECLARE_RW_DISPLACEMENT(type, varName, screenPos, i)	Using the value computed from the above macro (screenPos), this will compute the displacement used when
//														sampling data from the level texture. This displacement is affected by the water level, and whether or not
//														wet terrain is enabled (this is how the world gets distorted in these two scenarios).



// KEYWORDS TO ENABLE IN UNITY WITH GLASS LEVELS //
// This is more oriented to me (Xan) personally as my mod uses custom optimizations in the level shader.

// PROPERTY_STATIC_BRANCHES_AVAILABLE			// Enable this keyword to leverage the performance boost of static branching, for properties.
// SUNLIGHT_STATIC_BRANCHES_AVAILABLE			// Enable this keyword to leverage the performance boost of static branching, for sunlight.
// RIMFIX_ON									// If declared, _rimFix is 1.
// GRIME_ON										// If declared, _grime is nonzero.
// IS_SWARM_ROOM								// If declared, this room is a swarm room.
// SUNLIGHT_RENDERING_ON						// If declared, the shader is told that this room has any sunlight.
// USE_EXACT_PROP_COLORS_ON						// If declared, prop colors never interpolate to the background. This means that the exact palette color is used.



//// COHERENCY FLAGS ////
// These are ESPECIALLY important in that they dramatically change how the GPU executes the shader code.
// "Coherency" indicates that pixels with the provided values/effects (i.e. sun lit, visible to the sky) are *physically close together and bulked up*.
// A scene with a wide open sky and not many things blocking a view of the sky, or where such things blocking it are clumped together, is considered COHERENT.
// A scene with a bunch of littered parts and random obstructions dotting the sky is considedred INCOHERENT.
// Similarly, for sunlight, having a huge area completely under sunlight is considered COHERENT.
// Having small godrays and little splotched areas of some sunlight is considered INCOHERENT.

// OPTIMIZE_FOR_COHERENT_SUNLIGHT				// If declared, the shader is told that sunlight is coherent. It will use standard branching.
//												// If not declared, the shader will use flattened branching. This will make it all around a little slower,
//												// but protects against the performance drop caused a standard branch becoming divergent.
//												
// OPTIMIZE_FOR_COHERENT_SKY					// Same rule as sunlight, except this pertains to the exposed sky. Clouds count as sky.
//

// PART 1 // COMMON VALUE MACROS //

// Mathematical constant τ (2π)
const half TAU							= 6.283185482025146484375;				

const half EFFECT_TYPE_PROP_COLORS		= 100;		// This value is used by the RW shader as else dummy in the effect color index
													// to indicate to the system that it should use custom prop colors.
const half EFFECT_TYPE_COLOR_A			= 1;
const half EFFECT_TYPE_COLOR_B			= 2;
const half EFFECT_TYPE_SWARMROOM		= 3;
const half EFFECT_TYPE_GRIME			= 4;

const half PALETTE_UNDERTONE_INDEX		= 0;
const half PALETTE_FOREFACING_INDEX		= 1;
const half PALETTE_HIGHLIGHT_INDEX		= 2;

const half PLATFORM_RENDERING_OFFSET	= 16;
const half DECAL_OR_PROP_COLOR_OFFSET	= 8;
													
// PART 2 // VALUE DECLARATIONS //
sampler2D _MainTex;
sampler2D _PalTex;
sampler2D _NoiseTex;
sampler2D _GrabTexture;
uniform float2 _MainTex_TexelSize; // This is a unity built-in variable, so it will always be uniform.

// Make a macro for the uniform keyword. This way it can be toggled in source by the preprocessor.
// Also declare the appropriate _RAIN value.
#if defined(DEBUG_MODE) || defined(IS_EDITOR_LEVEL_SHADER)
	#define DBG_UNIFORM
	#define _RAIN (_Time.y * 0.2) // When in debug mode, the _RAIN variable can be hooked into Unity's timer.
#else
	#define DBG_UNIFORM uniform
	DBG_UNIFORM float _RAIN;
#endif

DBG_UNIFORM float _palette;
DBG_UNIFORM float _light = 0;
DBG_UNIFORM float4 _spriteRect;
DBG_UNIFORM float2 _screenSize;
DBG_UNIFORM float2 _screenPos;
DBG_UNIFORM float2 _screenOffset;
DBG_UNIFORM float4 _lightDirAndPixelSize;
DBG_UNIFORM float _fogAmount;
DBG_UNIFORM float _waterLevel;
DBG_UNIFORM float _Grime;
DBG_UNIFORM float _SwarmRoom;
DBG_UNIFORM float _WetTerrain;
DBG_UNIFORM float _cloudsSpeed;
DBG_UNIFORM float _darkness;
DBG_UNIFORM float _contrast;
DBG_UNIFORM float _saturation;
DBG_UNIFORM float _hue;
DBG_UNIFORM float _brightness;
DBG_UNIFORM half4 _AboveCloudsAtmosphereColor;
DBG_UNIFORM float _rimFix;


// PART 3 // MATHEMATICAL UTILITIES //
// Given a color and a hue (from 0 to 360), this will hue shift the color and return the new color.
half3 applyHue(half3 aColor, half aHue) {
	const half3 k = half3(0.57735, 0.57735, 0.57735);
	half angle = radians(aHue);
	half cosAngle = cos(angle);
	//Rodrigues' rotation formula
	return aColor * cosAngle + cross(k, aColor) * sin(angle) + k * dot(k, aColor) * (1 - cosAngle);
}

// Converts a wrapped UV coordinate (0 to 1) into screen space.
half2 getWrappedPixelCoord(half2 uv) {
    return floor(frac(uv) * _screenSize.xy);
}

// Returns 1 if left > right and 0 if not, without using a branch.
half branchlessIsGT(half left, half right) {
	return abs(sign(left - right));
}

// Returns 1 if left < right and 0 if not, without using a branch.
half branchlessIsLT(half left, half right) {
	return branchlessIsGT(right, left);
}

// Returns 1 if left >= right and 0 if not, without using a branch.
half branchlessIsGE(half left, half right) {
	return 1 - branchlessIsLT(right, left);
}

// Returns 1 if left <= right and 0 if not, without using a branch.
half branchlessIsLE(half left, half right) {
	return 1 - branchlessIsGT(left, right);
}



// Using this macro declares a variation of frac() that returns a signed value for the provided type.
// The block below declares it for all commonly supported half precision and single precision scalar and vector types
// including f1, f2, f3, f4, f2x2, f3x3, and f4x4 for both levels of precision.
// Notably, this excludes rectangular matrices as they are not supported by all GPUs.
#define DECL_SFRAC(type) type sfrac(type x) { return sign(x) * frac(x); }
DECL_SFRAC(half)
DECL_SFRAC(half2)
DECL_SFRAC(half3)
DECL_SFRAC(half4)
DECL_SFRAC(half2x2)
DECL_SFRAC(half3x3)
DECL_SFRAC(half4x4)
DECL_SFRAC(float)
DECL_SFRAC(float2)
DECL_SFRAC(float3)
DECL_SFRAC(float4)
DECL_SFRAC(float2x2)
DECL_SFRAC(float3x3)
DECL_SFRAC(float4x4)

// This macro automatically declares a dummy vertex program and struct that sets up the minimal level information.
#define DECLARE_VERTEX_PROGRAM(programName, structName)		\
struct structName											\
{															\
	float4 pos  : SV_POSITION;								\
	float2 uv   : TEXCOORD0;								\
	float2 uv2  : TEXCOORD1;								\
	float4 clr	: COLOR;									\
};															\
structName programName(appdata_full v){						\
	structName o;											\
	o.pos = UnityObjectToClipPos(v.vertex);					\
	o.uv = v.texcoord;										\
	o.uv2 = o.uv - _MainTex_TexelSize * 0.5 * _rimFix;		\
	o.clr = v.color;										\
	return o;												\
}
// PART 4 // PALETTE INFORMATION //

// x / 32 + (1/64), y / 8 + (1/32)
// Note to future Xan: The _PalTex is only half of a palette (the top half, usually, unless it is raining).
// But also: The editor preview *can* use a full palette if it wants. This only applies to IS_EDITOR_LEVEL_SHADER

// Given an xy coordinate in integer space, this will return the proper 
// coordinate on the palette texture.
half2 PALETTE_COORDINATE(half2 xy) {
	const half2 I_RESOLUTION = half2(0.03125, 0.125);
	half2 coord = xy + 0.5; // Add 0.5 to center it on the pixel.
	coord *= I_RESOLUTION;
#if UNITY_UV_STARTS_AT_TOP
	coord = half2(coord.x, 1 - coord.y);
#endif
	return coord;
}

// Given an xy coordinate in integer space, this will return the proper 
// coordinate on the palette texture.
half2 PALETTE_COORDINATE(half x, half y) {
	return PALETTE_COORDINATE(half2(x, y));
}

half2 PALETTE_COORDINATE_0BOTTOM(half2 xy) {
	const half2 I_RESOLUTION = half2(0.03125, 0.125);
	half2 coord = xy + 0.5; // Add 0.5 to center it on the pixel.
	coord *= I_RESOLUTION;
#if !UNITY_UV_STARTS_AT_TOP
	coord = half2(coord.x, 1 - coord.y);
#endif
	return coord;
}

// Given an xy coordinate in integer space, this will return the proper 
// coordinate on the palette texture.
half2 PALETTE_COORDINATE_0BOTTOM(half x, half y) {
	return PALETTE_COORDINATE_0BOTTOM(half2(x, y));
}


// Declarations of pixels for specific locations in the palette.
// These apply only to the half-height palette.
#define PALETTE_SKY					PALETTE_COORDINATE(0, 0)
#define PALETTE_FOG					PALETTE_COORDINATE(1, 0)
#define PALETTE_BLACK				PALETTE_COORDINATE(2, 0)
#define PALETTE_ITEM				PALETTE_COORDINATE(3, 0)
#define PALETTE_DEEPWATER_CLOSE		PALETTE_COORDINATE(4, 0)
#define PALETTE_DEEPWATER_FAR		PALETTE_COORDINATE(5, 0)
#define PALETTE_WATERSURFACE_CLOSE	PALETTE_COORDINATE(6, 0)
#define PALETTE_WATERSURFACE_FAR	PALETTE_COORDINATE(7, 0)
#define PALETTE_WATERHIGHLIGHT		PALETTE_COORDINATE(8, 0)
#define PALETTE_FOGAMOUNT			PALETTE_COORDINATE(9, 0)
#define PALETTE_SHORTCUT1			PALETTE_COORDINATE(10, 0)
#define PALETTE_SHORTCUT2			PALETTE_COORDINATE(11, 0)
#define PALETTE_SHORTCUT3			PALETTE_COORDINATE(12, 0)
#define PALETTE_SHORTCUT_SYM		PALETTE_COORDINATE(13, 0)
#define PALETTE_DARKNESS			PALETTE_COORDINATE(30, 0)
#define PALETTE_IS_RAIN				PALETTE_COORDINATE(31, 0)
#define PALETTE_DECAL_COLOR_MOD		PALETTE_COORDINATE(1, 0)
#define PALETTE_COORD_GRIME(x)		PALETTE_COORDINATE((x), 1)

#define SAMPLE_NOISE(at)			(tex2D(_NoiseTex, (at)))
#define SAMPLE_NOISE_R(at)			(tex2D(_NoiseTex, (at)).r)

#ifdef IS_EDITOR_LEVEL_SHADER
	half _PalTexFade, _RainDarkness; // These are properties of the shader.
	sampler2D _PalTex2; // As is this.
	
	half4 SAMPLE_PALETTE(half2 at) {	
	#ifdef USING_FULL_PALETTE
	
	#if UNITY_UV_STARTS_AT_TOP
		at.y = 1 - at.y;
	#endif
		
		at.y *= 0.5; // Using PALETTE_COORDINATE with a value larger than 7 for y will overflow, so divide it by two.
		
	#if UNITY_UV_STARTS_AT_TOP
		at.y = 1 - at.y;
	#endif
		
		half4 p1clear = tex2D(_PalTex, at);
		half4 p2clear = tex2D(_PalTex2, at);
		
	#if UNITY_UV_STARTS_AT_TOP
		at.y = 1 - at.y;
	#endif
		
		at += half2(0, 0.5);
		
	#if UNITY_UV_STARTS_AT_TOP
		at.y = 1 - at.y;
	#endif
		
		half4 p1rain = tex2D(_PalTex, at);
		half4 p2rain = tex2D(_PalTex2, at);
		
		half4 p1 = lerp(p1clear, p1rain, _RainDarkness);
		half4 p2 = lerp(p2clear, p2rain, _RainDarkness);
		
		return lerp(p1, p2, _PalTexFade);
	#else
		half4 p1 = tex2D(_PalTex, at);
		half4 p2 = tex2D(_PalTex2, at);
		return lerp(p1, p2, _PalTexFade);
	#endif
	}
#else
	#define SAMPLE_PALETTE(at)		(tex2D(_PalTex, (at)))
#endif

// Provided with an effect color index (1 or 2), whether or not the color is "far away", and whether or not it is in shade,
// this will return THE COORDINATES OF one of the 4 possible appropriate effect color shades for the provided effect color index.
// This coordinate can be used in the SAMPLE_PALETTE(at) macro.
half2 PALETTE_EFFECT(half effectCol, half isFar, half isShade) {
	const half2 baseCoord = half2(30, 2);
	half effectIndex = 1 - (effectCol - 1);
	half2 resultCoord = baseCoord + half2(
		saturate(isShade),
		(saturate(effectIndex) * 2) + saturate(isFar)
	);
	return PALETTE_COORDINATE(resultCoord);
}
#ifdef IS_EDITOR_LEVEL_SHADER
	half2 PALETTE_EFFECT_EDITOR(half actualColorIndex, half isFar, half isShade) {
		half2 specificCoord = half2(saturate(isShade), saturate(isFar));
		half2 effectColorBase = half2(actualColorIndex * 2, 0);
		return (specificCoord + effectColorBase) * half2(1.0 / 44.0, 0.25);
	}
#endif

// Provided with an effect color index (1 or 2), whether or not the color is "far away", and whether or not it is in shade,
// this will return one of the 4 possible appropriate effect color shades for the provided effect color index.
// The effect color is declared in the palette texture via runtime modification.
#ifdef IS_EDITOR_LEVEL_SHADER
	sampler2D _EffectsTex;
	half _EffectColorA, _EffectColorB;
	half4 GET_PALETTE_EFFECT_COLOR(half effectCol, half distance, half isShade) {
		half effectABto10 = saturate((effectCol - 1));
		// ^ A = 1, B = 0
			
		half2 aNear = PALETTE_EFFECT_EDITOR(_EffectColorA, 0, isShade);
		half2 aFar = PALETTE_EFFECT_EDITOR(_EffectColorA, 1, isShade);
		half2 bNear = PALETTE_EFFECT_EDITOR(_EffectColorB, 0, isShade);
		half2 bFar = PALETTE_EFFECT_EDITOR(_EffectColorB, 1, isShade);
		
		half4 near;
		[flatten]
		if (_EffectColorA == -1) {
			near = 1;
		} else {
			near = tex2D(_EffectsTex, lerp(aNear, bNear, effectABto10));
		}
		half4 far;
		[flatten]
		if (_EffectColorB == -1) {
			far = 1;
		} else {
			far = tex2D(_EffectsTex, lerp(aFar, bFar, effectABto10));
		}
		
		return lerp(
			near,
			far,
			saturate(distance)
		);
	}
#else
	half4 GET_PALETTE_EFFECT_COLOR(half effectCol, half distance, half isShade) {
		half2 near = PALETTE_EFFECT(effectCol, 0, isShade);
		half2 far = PALETTE_EFFECT(effectCol, 1, isShade);
		return lerp(
			SAMPLE_PALETTE(near),
			SAMPLE_PALETTE(far),
			saturate(distance)
		);
	}
#endif

// A sine wave at *x* with the provided timescale.
half waveS(half x, half timescale) {
	half time = _RAIN * timescale;
	return saturate(abs(sin(x + time)));
}

// A cosine wave at *x* with the provided timescale.
half waveC(half x, half timescale) {
	half time = _RAIN * -timescale;
	const half ADJUSTMENT = UNITY_HALF_PI * 2.75;
	return saturate(abs(sin(x + time + ADJUSTMENT)));
}

half sharpen(half x, half power, half clampFactor) {
	return saturate(pow(x, power) - clampFactor) / (1 - clampFactor);
}

// because my pee brain can't seem to understand it properly.
#define X_GE_Y(x, y) step((y), (x))
#define X_GT_Y(x, y) (1 - step((x), (y)))

// Converts a float32 (0 to 1) to an unsigned integer (0 to 255).
#define F32_TO_I8(value) ((uint)round(saturate(value) * 255.0))
// Converts a float (0 to 1) to an integer value (0 to 255), but keep it as its float type.
#define F32_TO_I8_F(value) (round(saturate(value) * 255.0))
#define COLOR_TO_BYTE(type, value) ((type)round(saturate(value) * 255.0))

// This sets up a texture coordinate that is scaled to the screen position (0 to 1), 
// but is only allowed to exist in increments that line it up with the center of a pixel.
half2 uvToNearestPixelCenter(half2 uv) {
	half aspect = 0;
	
	[branch]
	if (_screenSize.x > _screenSize.y) {
		aspect = _screenSize.y / _screenSize.x;
	} else {
		aspect = _screenSize.x / _screenSize.y;
	}
	
	uv.y *= aspect;
	return uv;
}

// INTERNAL MACROS //
#define RWSCRPOS_SR(m, n) _spriteRect.m + _screenOffset.m, _spriteRect.n + _screenOffset.m // No parenthesis!
#define RWSCRPOS_SR_XX_ZX RWSCRPOS_SR(x, z)
#define RWSCRPOS_SR_YY_WY RWSCRPOS_SR(y, w)
#define RWSCRPOS_LERP_X lerp(RWSCRPOS_SR_XX_ZX, i.uv.x)
#define RWSCRPOS_LERP_Y lerp(RWSCRPOS_SR_YY_WY, i.uv.y)
#if UNITY_UV_STARTS_AT_TOP
	#define DECLARE_RW_SCREEN_POS(type, varName) type varName = type(RWSCRPOS_LERP_X, 1 - RWSCRPOS_LERP_Y)
#else
	#define DECLARE_RW_SCREEN_POS(type, varName) type varName = type(RWSCRPOS_LERP_X, RWSCRPOS_LERP_Y)
#endif

// Utility: Computes the displacement for level pixels. This is common across the primary level shader and the heat wave shader.
// This notably excludes the void melt shaders, however.
#define DECLARE_RW_DISPLACEMENT(type, varName, screenPos, i) type varName;							\
{																									\
type __ugh = F32_TO_I8_F(tex2D(_MainTex, i.uv).x);													\
__ugh = fmod(__ugh, 90);																			\
__ugh = fmod(__ugh - 1, 30);																		\
__ugh *= 0.0033333333333333333333;																	\
type##2 __mcoord = (i.uv * type##2 (1.5, 0.25)) - __ugh + (_RAIN * type##2 (0.01, 0.05));			\
varName = tex2D(_NoiseTex, __mcoord).x;																\
varName = saturate((sin((displace + i.uv.x + i.uv.y + (_RAIN * 0.1)) * 3 * UNITY_PI) - 0.95) * 20);	\
}																									\
varName *= saturate(round(_WetTerrain)) * X_GE_Y(1 - screenPos.y, _waterLevel) * 0.001
// Emulates: if (_WetTerrain < 0.5 || 1 - screenPos.y > _waterLevel) displace = 0;
// the x0.001 isn't in the vanilla code here. I put it here because the single place that the variable *does* get used at ends up doing *0.001

#endif