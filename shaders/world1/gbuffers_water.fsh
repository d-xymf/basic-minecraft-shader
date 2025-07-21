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

#include "/world1/lib_world1.glsl"
#include "waves.glsl"

/* DRAWBUFFERS: 0413 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;
layout(location = 2) out vec4 outColor2;
layout(location = 3) out vec4 outColor3;

void main() {
	vec4 color = texture(gtexture, texcoord) * glcolor;

	color.rgb = pow(color.rgb, vec3(2.2));
	
	if (color.a < alphaTestRef) {
		discard;
	}

	vec2 lm = lmcoord;

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

	// Darken with lightmap
	color.rgb *= mix(lmShadowColor, vec3(1.0), clamp(lm.y + lm.x, 0.0, 1.0));

	// Diffuse lighting kinda
	color.rgb *= mix(lmShadowColor, vec3(1.0), clamp(dot(normal, vec3(0.0, 1.0, 0.0)) + lm.x, 0.4, 1.0));

	// Brighten parts in direct sunlight
	//color.rgb *= mix(GetShadowLightColor(GetSunVisibility(), rainStrength), vec3(1.0), clamp(inShadow + 1.0 - sunDot, 0.0, 1.0));

	// Brighten light from light sources
	color.rgb *= mix(vec3(1.0), blockLightColor, lm.x);

	// Underwater stuff
	if(isEyeInWater == 1)
	{
		color.rgb *= waterTint;
	}

	// Fog
	vec3 densities = GetFogDensities(isEyeInWater);
	vec3 fogFactors = (exp(-densities * depth/192.0) - 1.0) * (1.0 - lm.x*0.6) + 1.0;
	vec3 fogCol = GetLightColor(isEyeInWater);
	color.rgb = mix(color.rgb, fogCol, pow(1.0 - fogFactors, vec3(2.0)));
	vec3 fogMask = mix(vec3(0.0), vec3(1.0), pow(1.0 - fogFactors.g, 2.0));

	if(isEyeInWater == 2) {
		color.rgb = mix(color.rgb, lavaFogColor, clamp(depth*lavaFogDen, 0.0, 1.0));
	}
	if(isEyeInWater == 3) {
		color.rgb = mix(color.rgb, snowFogColor, clamp(depth*snowFogDen, 0.0, 1.0));
	}

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
		outColor3 = vec4(vec3((lm.y - (1.0/32.0)) * 32.0 / 30.0), 1.0);
	} else
	{
		outColor1 = vec4(0.0, 0.0, 0.0, 1.0);
	}

	outColor2 = vec4(waveNormal * 0.5 + 0.5, 1.0);
}