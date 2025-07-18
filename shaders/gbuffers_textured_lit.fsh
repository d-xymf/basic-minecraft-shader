#version 460 compatibility

uniform float alphaTestRef = 0.1;
uniform float worldTime;

uniform sampler2D lightmap;
uniform sampler2D gtexture;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 vertexPosition;
in vec4 shadowPos;
in float depth;
in vec3 normal;

const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

const vec3 lavaFogColor = vec3(1.0, 0.1, 0.0);
const vec3 snowFogColor = vec3(0.9, 0.9, 1.0);
const float lavaFogDen = 0.5;
const float snowFogDen = 0.5;

#include "distort.glsl"
#include "/lib.glsl"
#include "shadow.glsl"

/* DRAWBUFFERS: 01 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;

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


	// Lighting

	// Adjust lightmap coords
	//lm.x = pow(lm.x, 4.0);
	// Avoids weird issues when lm.x is 0 or 1
	//lm.x = clamp(lm.x, 1.0/32.0, 31.0/32.0);

	//color *= pow(texture2D(lightmap, vec2(31.0/32.0, lm.y)), vec4(2.2));

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
	color.rgb *= mix(GetShadowLightColor(GetSunVisibility(), rainStrength), vec3(1.0), clamp(inShadow + 1.0 - sunDot, 0.0, 1.0));

	// Brighten light from light sources
	//color.rgb *= mix(vec3(1.0), blockLightTint, lm.x);
	vec3 blockLight = mix(blockLightColor, vec3(1.0), GetSunVisibility() * 0.9);
	color.rgb *= mix(vec3(1.0), blockLight, lm.x);

	// Underwater stuff
	if(isEyeInWater == 1)
	{
		color.rgb *= waterTint;
	}

	// Fog
	vec3 densities = GetFogDensities(GetSunVisibility(), rainStrength, isEyeInWater);
	densities = mix(caveFogDensities, densities, lm.y);
	vec3 fogFactors = (exp(-densities * depth/far) - 1.0) * (1.0 - lm.x*0.6) + 1.0;
	vec3 fogCol = GetLightColor(GetSunVisibility(), rainStrength, isEyeInWater);
	//fogCol = mix(caveFogColor, fogCol, lm.y);
	color.rgb = mix(color.rgb, fogCol, pow(1.0 - fogFactors, vec3(2.0)));

	if(isEyeInWater == 2) {
		color.rgb = mix(color.rgb, lavaFogColor, clamp(depth*lavaFogDen, 0.0, 1.0));
	}
	if(isEyeInWater == 3) {
		color.rgb = mix(color.rgb, snowFogColor, clamp(depth*snowFogDen, 0.0, 1.0));
	}

	color.rgb = pow(color.rgb, vec3(1.0/2.2));

	outColor0 = color;
	//outColor0 = vec4(shadowPos.xyz, 1.0);
	//outColor0 = texture2D(lightmap, vec2(31.0/32.0, lm.y));
	outColor1 = vec4(normal * 0.5 + 0.5, 1.0);
}