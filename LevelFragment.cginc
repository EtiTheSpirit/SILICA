#ifndef __LEVEL_FRAGMENT__
#define __LEVEL_FRAGMENT__

#ifndef __XFUTILE_LEVEL_COMMON__
	#error("Please include LevelCommon.cginc before LevelFragment.cginc")
#endif

// RELEVANT MACROS: See LevelCommon.cginc

#ifndef ALREADY_DECLARED_LEVEL_V2F
	DECLARE_VERTEX_PROGRAM(vert, v2f)
#endif

#if (defined(SUNLIGHT_STATIC_BRANCHES_AVAILABLE) && defined(SUNLIGHT_RENDERING_ON)) || !defined(SUNLIGHT_STATIC_BRANCHES_AVAILABLE)
	#define SUNLIGHT_EFFECTIVELY_ON
#endif

half4 frag (v2f i) : SV_Target
{
	half4 setColor = half4(0, 0, 0, 1);
	half checkMaskOut = 0;
	
	// These two macros set up the RW shader variables: screenPos and displace
	// These are used by effects like wet terrain.
	DECLARE_RW_SCREEN_POS(half2, screenPos);
	DECLARE_RW_DISPLACEMENT(half, displace, screenPos, i);
	half2 adjUV = uvToNearestPixelCenter(i.uv);
	half4 texcol = tex2D(_MainTex, float2(i.uv2.x, i.uv2.y + displace));
				
#ifdef OPTIMIZE_FOR_COHERENT_SKY
	UNITY_BRANCH
#else
	UNITY_FLATTEN
#endif

	// FIRST CONDITION: SKY CHECK
	// If the pixel on the level is pure white, this should render using the sky color, which may or may not be determined by a shader global.
	if (all(texcol.xyz == 1)) {
#ifdef PROPERTY_STATIC_BRANCHES_AVAILABLE
	#ifdef RIMFIX_ON
		setColor = _AboveCloudsAtmosphereColor;
	#else
		setColor = SAMPLE_PALETTE(PALETTE_SKY);
	#endif
		checkMaskOut = 1;
#else
		UNITY_BRANCH
		if (_rimFix > 0.5) {
			setColor = _AboveCloudsAtmosphereColor;
		} else {
			setColor = SAMPLE_PALETTE(PALETTE_SKY);
		}
		checkMaskOut = 1;
#endif
	} else {
		// MAIN BODY:
		// This handles the core of all level rendering that isn't the sky.
	
		uint2 rg = COLOR_TO_BYTE(uint2, texcol.xy);
		uint red = rg.r;
		uint green = rg.g;
		uint effectType = green;
		half isPlatform = 0;
		
		// For these scenarios, branches should be okay.
		// While it's really hard to guess due to the diversity of GPU hardware, *in general*
		// warps are as little as 2x2 and as large as 32x32 (?)
		// This has a high(er) cost if the pixels in that square are divergent and result in different branch paths.
		UNITY_BRANCH
		if (green >= PLATFORM_RENDERING_OFFSET) {
			isPlatform = 1;
			green -= PLATFORM_RENDERING_OFFSET;
		}
				
		UNITY_BRANCH
		if (green >= DECAL_OR_PROP_COLOR_OFFSET) {
			effectType = EFFECT_TYPE_PROP_COLORS;
			green -= DECAL_OR_PROP_COLOR_OFFSET;
		}
		/*
		isPlatform = branchlessIsGE(green, PLATFORM_RENDERING_OFFSET);
		green -= PLATFORM_RENDERING_OFFSET * isPlatform;
		
		half isDecalOrProp = branchlessIsGE(green, DECAL_OR_PROP_COLOR_OFFSET);
		effectType = lerp(effectType, EFFECT_TYPE_PROP_COLORS, isDecalOrProp);
		green -= DECAL_OR_PROP_COLOR_OFFSET * isDecalOrProp;
		*/
					
		half shadow = 1;
				
		// This is for sunlight. Generate a shadow based on the noise texture for clouds.
#ifdef SUNLIGHT_EFFECTIVELY_ON
		float2 shadowCoord = i.uv.xy * 0.5 + (_RAIN * _cloudsSpeed * float2(0.1, 0.2)) - (fmod(red, 30) * 0.003);
				
	#if defined(OPTIMIZE_FOR_COHERENT_SUNLIGHT) && defined(SUNLIGHT_STATIC_BRANCHES_AVAILABLE)
		UNITY_BRANCH
	#endif
		if (red > 90) {
			red -= 90;
			shadow = SAMPLE_NOISE_R(shadowCoord);
			half cloudMod = _RAIN * 0.1 * _cloudsSpeed;
			shadow = sin(sfrac(shadow + cloudMod - i.uv.y) * TAU) * 0.5;
			shadow = saturate((shadow * 6) + 0.5 - (_light * 4));
		}
#endif

		// Now grab the palette color, and clamp red to depth.
		const half ONE_OVER_30 = 1.0 / 30.0;
		uint paletteColor = clamp(floor((red - 1) * ONE_OVER_30), 0, 2);
		red = fmod(red - 1, 30);
		
#ifdef SUNLIGHT_EFFECTIVELY_ON
		if (shadow != 1 && red >= 5) {
	#if UNITY_UV_STARTS_AT_TOP
			half2 grabPos = half2(screenPos.x, 1 - screenPos.y);
			// TO FUTURE XAN: Yes, this one *does* get flipped. These coordinates are not automatically corrected
			// by unity so you must do so yourself.
	#else
			half2 grabPos = screenPos.xy;
	#endif
			half red5 = red - 5;
			grabPos += half2(
				-_lightDirAndPixelSize.x * _lightDirAndPixelSize.z * red5,
					_lightDirAndPixelSize.y * _lightDirAndPixelSize.w * red5
			);
			const half2 offset = half2(0.5, 0.3);
			const half ONE_OVER_460 = 1.0 / 460.0;
			grabPos = (grabPos - offset) * (1 + red5 * ONE_OVER_460) + offset;
			half4 grabTexCol2 = tex2D(_GrabTexture, grabPos);
			if (any(grabTexCol2.xyz != 0)) {
				shadow = 1;
			}
		}
#endif

					
		// To future Xan: paletteColor is designed in such a way that it indexes the palette from the bottom up.
		// As a result of this, the palette coordinate actually needs to be inverted in the *inverse* scenario
		// of UNITY_UV_STARTS_AT_TOP.
		// To fix this, use PALETTE_COORDINATE_0BOTTOM
		half2 palCoordShade = half2(red * (1 - isPlatform), paletteColor); // red * notFloorDark, paletteColor
		half2 palCoordSun = palCoordShade + half2(0, 3);
					
		half isInSunlight = 1 - shadow;
		setColor = lerp(
			SAMPLE_PALETTE(PALETTE_COORDINATE_0BOTTOM(palCoordSun)),
			SAMPLE_PALETTE(PALETTE_COORDINATE_0BOTTOM(palCoordShade)),
			shadow
		);
#ifdef PROPERTY_STATIC_BRANCHES_AVAILABLE
	#ifdef GRIME_ON
		half noise4 = SAMPLE_NOISE_R(i.uv * 2) * 4;
		half noiseAffectedDepth = (sin((_RAIN + noise4 + red / 12.0) * TAU) * 0.5) + 0.5;
		half isGrimeEnabled = saturate(green - 3.0);
					
		setColor = lerp(
			setColor, 
			SAMPLE_PALETTE(PALETTE_COORD_GRIME(5.5 + noiseAffectedDepth * 25)),
			isGrimeEnabled * _Grime * 0.2
						
			// green >= 4 (0, 1, 2, 3 invalid)
			// green - 3 puts 0, 1, 2, and 3 at -3, -2, -1, 0 respectively
			// saturate this value, and it will be 0 or 1.
		);
	#endif
#else
		UNITY_BRANCH
		if (_Grime > 0) {
			half noise4 = SAMPLE_NOISE_R(i.uv * 2) * 4;
			half noiseAffectedDepth = (sin((_RAIN + noise4 + red / 12.0) * TAU) * 0.5) + 0.5;
			half isGrimeEnabled = saturate(green - 3.0);
			
			setColor = lerp(
				setColor, 
				SAMPLE_PALETTE(PALETTE_COORD_GRIME(5.5 + noiseAffectedDepth * 25)),
				isGrimeEnabled * _Grime * 0.2
				// green >= 4 (0, 1, 2, 3 invalid)
				// green - 3 puts 0, 1, 2, and 3 at -3, -2, -1, 0 respectively
				// saturate this value, and it will be 0 or 1.
			);
		}
#endif

		if (effectType == EFFECT_TYPE_PROP_COLORS) {
#if UNITY_UV_STARTS_AT_TOP
			const half customPropColorY = 799.5 / 800.0;
#else
			const half customPropColorY = 0.5 / 800.0;
#endif
			const half inverseLevelImageWidth = 1.0 / 1400.0;
			half customPropColorX = F32_TO_I8_F(1 - texcol.b) + 0.5; 
			// Convert the blue channel to a byte color. 
			// RW inverts this though, so B=0.0f (0) means to use the 255th color
			// and B=1.0f (255) means to use the 0th color.
			
			// A reminder that prop colors are placed across the top of the level texture, starting at (0, 0)
			// going horizontally up to 255 colors.
			
			half4 customPropColor = tex2D(
				_MainTex,
				float2(
					customPropColorX * inverseLevelImageWidth,
					customPropColorY
				)
			);
						
			if (paletteColor == PALETTE_HIGHLIGHT_INDEX) {
#ifdef SUNLIGHT_EFFECTIVELY_ON
				customPropColor = lerp(customPropColor, 1, 0.2 - shadow * 0.1);
#else
				// Lerp factor is always 0.1 (0.2 - 1 * 0.1)
				customPropColor = lerp(customPropColor, 1, 0.1);
#endif
			}
						
						
#ifndef USE_EXACT_PROP_COLORS_ON
	#ifdef SUNLIGHT_EFFECTIVELY_ON
			half customPropColorShadowFactor = 0.3 + 0.4 * shadow;
	#else
			const half customPropColorShadowFactor = 0.7;
	#endif
			const half ONE_OVER_60 = 1.0 / 60.0;
			customPropColor = lerp(customPropColor, SAMPLE_PALETTE(PALETTE_DECAL_COLOR_MOD), red * ONE_OVER_60);
						
			// Makes the prop color appear translucent, by taking 30% of the original color up.
			half4 fadedPropColor = lerp(setColor, customPropColor, 0.7);
						
			// Makes the prop color appear "groggy" or "dirty", for lack of a better term.
			half4 multipliedPropColor = setColor * customPropColor * 1.5;
						
			half propGroggynessFactor = saturate((red - 3.5) * 0.3);			
			// Here's what this results in.
			// The first range (left side) is depth.
			// The second range (right side) is the mix factor.
			// [0,  3] => 0.00
			// [4,  7] => [0.15, 1.00]
			// [8, 30] => 1.00
			half propGroggyness = lerp(0.9, customPropColorShadowFactor, propGroggynessFactor);
						
			// Set the rendered result color now.
			setColor = lerp(fadedPropColor, multipliedPropColor, propGroggyness);
#else
			if (paletteColor == PALETTE_UNDERTONE_INDEX) {
				customPropColor *= 0.8f;
			}
			setColor = customPropColor;
#endif			
		} else if (effectType == EFFECT_TYPE_COLOR_A || effectType == EFFECT_TYPE_COLOR_B) {
	#ifdef SUNLIGHT_EFFECTIVELY_ON
			half4 effect = GET_PALETTE_EFFECT_COLOR(effectType, red * ONE_OVER_30, shadow);
	#else
			half4 effect = GET_PALETTE_EFFECT_COLOR(effectType, red * ONE_OVER_30, 1);
	#endif
			setColor = lerp(setColor, effect, texcol.b);


#ifdef PROPERTY_STATIC_BRANCHES_AVAILABLE
	#ifndef IS_SWARM_ROOM
		} else if (effectType == EFFECT_TYPE_SWARMROOM) {
			setColor = lerp(setColor, 1, texcol.b);
		}
	#else
		}
		// To future Xan: It is correct that the effectType==3 condition is entirely omitted when possible here.
	#endif
#else
		} else if (effectType == EFFECT_TYPE_SWARMROOM) {
			setColor = lerp(setColor, 1, texcol.b * _SwarmRoom);
		}
#endif
					
					
		// notFloorDark is 1 or 0.
		// For some reason, original author did: lerp(notFloorDark, 1, 0.5)
		// This can be achieved WAY cheaper as: saturate(notFloorDark + 0.5)
		// isPlatform is my replacement for this, which is the opposite value (1.0 when g > 16)
		// red < 10
					
					
		half redGE10 = saturate(red - 9);
		half isNotPlatform = (1 - isPlatform);
		
		half4 fogColor = SAMPLE_PALETTE(PALETTE_FOG);
		
#ifdef IS_EDITOR_LEVEL_SHADER
		half3 fogAmountPx = SAMPLE_PALETTE(PALETTE_FOGAMOUNT).rgb;
		UNITY_BRANCH
		if (fogAmountPx.r == 0 && fogAmountPx.g == 0 && fogAmountPx.b > 0) {
			_fogAmount = 1 + fogAmountPx.b;
		} else {
			_fogAmount = 1 - fogAmountPx.r;
		}
#endif
		
		setColor = lerp(
			setColor,
			fogColor,
			saturate(red * saturate(isNotPlatform + 0.5 + redGE10) * _fogAmount * ONE_OVER_30)	
		);
					
		if (red >= 5) {
			checkMaskOut = true;
		}
	}
	
#ifdef OPTIMIZE_FOR_NO_EXPOSED_SKY
	UNITY_BRANCH
#else
	UNITY_FLATTEN
#endif
	if (checkMaskOut) {
#if UNITY_UV_STARTS_AT_TOP
		half4 grabTexCol = tex2D(_GrabTexture, float2(screenPos.x, 1 - screenPos.y));
#else
		half4 grabTexCol = tex2D(_GrabTexture, screenPos.xy);
#endif
		if (grabTexCol.r > 1.0/255.0 || grabTexCol.g != 0.0 || grabTexCol.b != 0.0) {
			setColor.a = 0;
		}
	}
				
				
	// VANILLA CODE:
	// Color Adjustment params
	setColor.rgb *= _darkness;
	setColor.rgb = ((setColor.rgb - 0.5) * _contrast) + 0.5;
	half3 greyscale = dot(setColor.rgb, half3(0.222, 0.707, 0.071));  // Convert to greyscale numbers with magic luminance numbers
	setColor.rgb = lerp(greyscale, setColor.rgb, _saturation);
	setColor.rgb = applyHue(setColor.rgb, _hue);
	setColor.rgb += _brightness;
				
	half alpha = texcol.a;
#ifdef VIRTUAL_FX_ON
	// EXPERIMENTAL // FOR DREAMS OF INFINITE GLASS //
	// Testing a basic GPU-bound effect.
	half scaledTime = _RAIN * 8;
	half scaledTimeDecA = 1 - frac(scaledTime);
	half scaledTimeDecB = saturate(frac(scaledTime * 0.5));
				
	// A is the wave effect. B is visibility.
	// If B > 0.5, the wave effect needs to be forcefully visible across the entire surface. Its value instead determines transparency.
	// If B < 0.5, the wave effect draws normally.
	half isForceVis = round(scaledTimeDecB); // Easy way to get 0 or 1 based on if its >= 0.5!
	half waveOrTransparency = (1 - i.uv.x) > scaledTimeDecA;
				
	// Write it out as traditional code then fix it.
	half value = lerp(waveOrTransparency, scaledTimeDecA, isForceVis) + 0.1;
	setColor.g += saturate(setColor.g + value) * any(frac(adjUV.xy * 64) < 0.05) * 0.0625;
#endif

#ifdef __FOG_SHADER_IN_EDITOR__
	half4 fogColorResult = ApplyFog(i, screenPos, texcol);
	setColor = lerp(setColor, half4(fogColorResult.rgb, 1), fogColorResult.a);
#endif

	return setColor;
}
#endif