#version 460 compatibility

#define COLORED_SHADOWS 1
#define SPECULAR_HIGHLIGHTS 1 //Toggle Phong specular highlights [1 0]

uniform float alphaTestRef = 0.1;
uniform float worldTime;

uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
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

#include "distort.glsl"
#include "/lib.glsl"

/* DRAWBUFFERS: 01 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;

void main() {
	vec4 color = texture(gtexture, texcoord) * glcolor;
	
	if (color.a < alphaTestRef) {
		discard;
	}

	//color.rgb = pow(color.rgb, vec3(2.2));

	vec2 lm = lmcoord;

	float inShadow = 0.0;

	// Shadows
	if (shadowPos.w < 0.0) {
		//surface is facing away from shadowLightPosition -> definitely in shadow.
		inShadow = 1.0;
	}
	if (shadowPos.w > 0.0) {
		//surface is facing towards shadowLightPosition
		#if COLORED_SHADOWS == 0
			//for normal shadows, only consider the closest thing to the sun,
			//regardless of whether or not it's opaque.
			if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
		#else
			//for invisible and colored shadows, first check the closest OPAQUE thing to the sun.
			if (texture2D(shadowtex1, shadowPos.xy).r < shadowPos.z) {
		#endif
			//surface is in shadows. reduce light level.
			inShadow = 1.0;
		}
		else {
			//surface is in direct sunlight. increase light level.
			#if COLORED_SHADOWS == 1
				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
				//perform a 2nd check to see if there's anything translucent between us and the sun.
				if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
					//surface has translucent object between it and the sun. modify its color.
					//if the block light is high, modify the color less.
					vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
					//make colors more intense when the shadow light color is more opaque.
					shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);
					//also make colors less intense when the block light level is high.
					shadowLightColor.rgb = mix(shadowLightColor.rgb, vec3(1.0), lm.x);
					//apply the color.
					float shadowFactor = 1.0 - ShadowBrightnessAdjusted(lm.x);
					color.rgb *= mix(vec3(1.0), shadowLightColor.rgb, shadowFactor);
				}
			#endif
		}
	}


	// Lighting

	// Adjust lightmap coords
	lm.x = pow(lm.x, 4.0);
	// Avoids weird issues when lm.x is 0 or 1
	lm.x = clamp(lm.x, 1.0/32.0, 31.0/32.0);

	color *= texture2D(lightmap, lm);

	// Darken shadowed regions
	float shadowFactor = mix(inShadow, 0.0, ShadowBrightnessAdjusted(lm.x));
	color.rgb *= mix(vec3(1.0), shadowColor, shadowFactor);

	// Diffuse lighting
	color.rgb *= mix(shadowColor, vec3(1.0), clamp(rainStrength + inShadow + clamp(shadowPos.w, 0.0, 1.0), 0.0, 1.0));
	color.rgb *= mix(vec3(1.0), shadowColor, rainStrength * 0.5);

	// Brighten light from light sources
	color.rgb *= mix(vec3(1.0), blockLightColor, lm.x);

	// Underwater stuff
	if(isEyeInWater == 1.0)
	{
		color.rgb *= waterTint;
	}


	// Fog
	vec3 densities = GetFogDensities(GetSunVisibility(), rainStrength, isEyeInWater);

	vec3 fogFactors = (exp(-densities * depth/far) - 1.0) * (1.0 - lm.x*0.6) + 1.0;

	color.rgb = mix(GetLightColor(GetSunVisibility(), rainStrength, isEyeInWater), color.rgb, fogFactors);

	//color.rgb = pow(color.rgb, vec3(1.0 / 2.2));

	outColor0 = color;
	outColor1 = vec4(normal * 0.5 + 0.5, 1.0);
}