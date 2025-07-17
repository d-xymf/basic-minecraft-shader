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

/* DRAWBUFFERS: 041 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;
layout(location = 2) out vec4 outColor2;

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
					color.rgb *= shadowLightColor.rgb;
				}
			#endif
		}
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
			waveNormal = normalize(cross(ztan, xtan));
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

	// Specular highlights
	#if SPECULAR_HIGHLIGHTS == 1
	// not rly correct
		vec3 specular = specularColor * PhongSpecular(specularIntensity, specularExp, GetShadowLightDirection(), GetCameraDirection(vertexPosition), normal);
		specular *= (1.0 - rainStrength) * GetSunVisibility() * (1.0 - inShadow);
		color.rgb += specular;
	#endif

	// Brighten light from light sources
	color.rgb *= mix(vec3(1.0), blockLightColor, lm.x);

	// Fog
	vec3 densities = GetFogDensities(GetSunVisibility(), rainStrength, isEyeInWater);

	vec3 fogFactors = (exp(-densities * depth/far) - 1.0) * (1.0 - lm.x*0.6) + 1.0;

	color.rgb = mix(GetLightColor(GetSunVisibility(), rainStrength, isEyeInWater), color.rgb, fogFactors);

	//color.rgb = pow(color.rgb, vec3(1.0 / 2.2));

	if(water)
	{
		outColor0 = vec4(0.0, 0.0, 0.0, 0.0);
	} else 
	{
		outColor0 = color;
	}
	//outColor0 = vec4(worldPosition, 1.0);
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