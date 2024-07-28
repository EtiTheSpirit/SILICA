#ifndef __FOG_SHADER_IN_EDITOR__
#define __FOG_SHADER_IN_EDITOR__

float _devToolsFogIntensity;

static half4 ApplyFog(v2f i, half2 scrPos, half4 texcol) {

	half amount = saturate((scrPos.y - ((1 - _waterLevel) - 0.11)) * 3);
	float2 textCoord = scrPos;
	
	textCoord.x -= _spriteRect.x;
	textCoord.y -= _spriteRect.y;

	textCoord.x /= _spriteRect.z - _spriteRect.x;
	textCoord.y /= _spriteRect.w - _spriteRect.y;
	
	half fog2 = 0.5 + 0.5f * sin((tex2D(_NoiseTex, half2(textCoord.x * 0.6 + _RAIN * 0.08, textCoord.y * 1 - _RAIN * 0.01)).x + _RAIN * 0.04 + i.uv.x) * 6.28);
	half fog1 = 0.5 + 0.5f * sin((tex2D(_NoiseTex, half2(textCoord.x * 0.44 - _RAIN * 0.113, textCoord.y * 1.2 - _RAIN * 0.0032)).x + _RAIN * 0.05 + i.uv.y) * 6.28);
   
	
	  //  displace = pow(displace * displace2, 0.5);//lerp(displace, displace2, 0.5);
	fog1 = lerp(fog1, fog2, 0.5);
   
	half dp = fmod(round(texcol.x * 255) - 1, 30.0) / 30.0;
	if (texcol.x == 1 && texcol.y == 1 && texcol.z == 1)
		dp = 1;

	if (dp > 6.0 / 30.0)
	{
		half4 grabTexCol = tex2D(_GrabTexture, scrPos.xy);
		if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
			dp = 6.0 / 30.0;
	}

	if (dp == 1)
	{
		fog2 = 0.5 + 0.5f * sin((tex2D(_NoiseTex, half2(i.uv.x * 1.7 + _RAIN * 0.113, i.uv.y * 2.82)).x + _RAIN * 0.14 - i.uv.x) * 6.28);
		fog2 *= clamp(1 - distance(i.uv, half2(0, 0.9)), 0, 1);
		fog2 = pow(fog2, 0.2);
		fog2 *= amount;
		fog2 *= 1 - pow(fog1, 1.5);
		fog2 *= i.clr.w;
		if (fog2 > 0.5) {
			half4 result = lerp(tex2D(_PalTex, float2(0, 7.0 / 8.0)), half4(1, 1, 1, 1), fog2 > 0.6 ? 0.25 : 0.1);
			result.a *= _devToolsFogIntensity;
			return result;
		}
	}

	fog1 = pow(fog1, 3);
	fog1 *= i.clr.w;

	//fog1 *= min(dp+0.1, 1);
	fog1 = pow(fog1, 1 + (1 - pow(dp, 0.1)) * 30);
	fog1 = max(0, fog1 - (1 - amount));

	fog1 = pow(fog1, 0.2);

	//return half4(fog1, fog1, 0, 1);


	if (fog1 > 0.1) {
		half4 result = half4(lerp(tex2D(_PalTex, float2(0, 2.0 / 8.0)), tex2D(_PalTex, float2(0, 7.0 / 8.0)), 0.5 + 0.5 * dp).xyz, fog1 > 0.5 ? 0.6 : 0.2);
		result.a *= _devToolsFogIntensity;
		return result;
	} else {
		return 0;
	}
}
#endif