#version 460 compatibility

uniform float alphaTestRef = 0.1;
uniform float worldTime;

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform float frameTimeCounter;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 vertexPosition;
in vec3 worldPosition;
in vec4 shadowPos;
in float depth;
in vec3 normal;
in float blockId;

const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

#include "distort.glsl"
#include "lib.glsl"
#include "waves.glsl"
#include "shadow.glsl"

/* DRAWBUFFERS: 041 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;
layout(location = 2) out vec4 outColor2;

void main() {
	vec4 color = texture(gtexture, texcoord) * glcolor;

	color.rgb = pow(color.rgb, vec3(2.2));
	
	if (color.a < alphaTestRef) {
		discard;
	}

	vec2 lm = lmcoord;

	float inShadow = 0.0;

	// Shadows
	if (shadowPos.w < 0.0) {
		//surface is facing away from shadowLightPosition -> definitely in shadow.
		inShadow = 1.0;
	}
	if (shadowPos.w > 0.0) {
		//surface is facing towards shadowLightPosition
		inShadow = GetShadow();

	#ifdef COLORED_SHADOWS
		//when colored shadows are enabled and there's something translucent between the sun and the nearest opaque thing.
		float shadowDepth0 = texture2D(shadowtex0, shadowPos.xy).r;
		float shadowDepth1 = texture2D(shadowtex1, shadowPos.xy).r;
		if (shadowDepth0 < shadowDepth1) {
			//surface has translucent object between it and the sun. modify its color.
			//if the block light is high, modify the color less.
			vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
			shadowLightColor.rgb = pow(shadowLightColor.rgb, vec3(2.2));
			//make colors more intense when the shadow light color is more opaque.
			shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, clamp(shadowLightColor.a * 2.0, 0.0, 1.0));
			//also make colors less intense when the block light level is high.
			shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lm.x);
			//apply the color.
			float shadowFactor = 1.0 - ShadowBrightnessAdjusted(lm.x);
			vec3 shadowTint = mix(vec3(1.0), shadowLightColor.rgb, shadowFactor);
			shadowTint = mix(shadowTint, vec3(1.0), inShadow);
			color.rgb *= shadowTint;
		}
	#endif
	}

	bool water = abs(blockId - 10060.0) < 0.1;

	// Calculate normals
	vec3 waveNormal = normal;
	if(water)
	{
		if(abs(dot(waveNormal, vec3(0.0, 1.0, 0.0))) > 0.9)
		{
			int iterations = 40;
			// Vertical displacement of vertices
			float wave = getWaves(worldPosition.xz, iterations);
			// Derivatives of wave in x and z direction using finite difference
			float xderiv = waves_amplitude * (getWaves(worldPosition.xz + vec2(0.001, 0.0), iterations) - wave) / 0.001;
			float zderiv = waves_amplitude * (getWaves(worldPosition.xz + vec2(0.0, 0.001), iterations) - wave) / 0.001;
			// Calculate normal vector based on derivatives
			vec3 xtan = vec3(1.0, xderiv, 0.0);
			vec3 ztan = vec3(0.0, zderiv, 1.0);
			waveNormal = normalize(cross(ztan, xtan)) * sign(dot(waveNormal, vec3(0.0, 1.0, 0.0)));
		}
	}

	// Lighting

	// Adjust lightmap coords
	//lm.x = pow(lm.x, 4.0);
	// Avoids weird issues when lm.x is 0 or 1
	//lm.x = clamp(lm.x, 1.0/32.0, 31.0/32.0);

	//color *= pow(texture2D(lightmap, lm), vec4(2.2));

	lm.x = pow(lm.x, 3.0);

	// Darken shadowed regions
	float shadowFactor = mix(inShadow, 0.0, ShadowBrightnessAdjusted(lm.x));
	color.rgb *= mix(vec3(1.0), shadowColor, shadowFactor);
	
	// Darken with lightmap
	color.rgb *= mix(lmShadowColor, vec3(1.0), clamp(lm.y + lm.x, 0.0, 1.0));

	// Diffuse lighting
	float sunDot = clamp(shadowPos.w, 0.0, 1.0);
	color.rgb *= mix(shadowColor, vec3(1.0), clamp(inShadow + ShadowBrightnessAdjusted(lm.x) + sunDot, 0.0, 1.0));
	color.rgb *= mix(nightColor, vec3(1.0), clamp(lm.x + GetSunVisibility(), 0.0, 1.0)); // darken overall in night
	color.rgb *= mix(vec3(1.0), shadowColor, rainStrength * 0.5);

	// Brighten parts in direct sunlight
	//color.rgb *= mix(GetShadowLightColor(GetSunVisibility(), rainStrength), vec3(1.0), clamp(inShadow + 1.0 - sunDot, 0.0, 1.0));

	// Brighten light from light sources
	//color.rgb *= mix(vec3(1.0), blockLightTint, lm.x);
	vec3 blockLight = mix(blockLightColor, vec3(1.0), GetSunVisibility() * 0.8);
	color.rgb *= mix(vec3(1.0), blockLight, lm.x);

	// Fog
	vec3 densities = GetFogDensities(GetSunVisibility(), rainStrength, isEyeInWater);
	densities = mix(caveFogDensities, densities, lm.y);
	vec3 fogFactors = (exp(-densities * depth/far) - 1.0) * (1.0 - lm.x*0.6) + 1.0;
	vec3 fogCol = GetLightColor(GetSunVisibility(), rainStrength, isEyeInWater);
	//fogCol = mix(caveFogColor, fogCol, lm.y);
	color.rgb = mix(color.rgb, fogCol, pow(1.0 - fogFactors, vec3(2.0)));

	color.rgb = pow(color.rgb, vec3(1.0/2.2));

	if(water)
	{
		outColor0 = vec4(0.0, 0.0, 0.0, 0.0);
	} else 
	{
		outColor0 = color;
	}
	//outColor0 = vec4(vec3(playerMood), 1.0);
	//if(water) outColor0 = vec4(1.0);
	if(water)
	{
		outColor1 = vec4(1.0);
	} else
	{
		outColor1 = vec4(0.0);
	}

	outColor2 = vec4(waveNormal * 0.5 + 0.5, 1.0);
}