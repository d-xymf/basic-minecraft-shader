#version 330 compatibility

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform vec3 skyColor;

in vec4 glcolor;

#include "lib.glsl"

float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
	float sunDot = dot(normalize(pos), normalize(sunPosition));
	float sunVis = GetSunVisibility();

	vec3 lightCol = GetLightColor(sunVis, rainStrength, isEyeInWater);
	vec3 fogDensities = GetFogDensities(sunVis, rainStrength, isEyeInWater);
	vec3 skyFogColor = mix(lightCol, skyColor, exp(-fogDensities));

	vec3 sky = mix(GetSkyColor(sunVis, rainStrength), skyFogColor, fogify(max(upDot, 0.0), 0.25));

	float sunset = 1.0 - 2.0 * abs(sunVis - 0.5);

	sky += sunsetOrange * vec3(exp((sunDot - 1.0) * 1.0)) * sunset;

	sky += sunsetYellow * vec3(exp((sunDot - 1.0) * 7.0)) * sunset;
	
	return sky;
}

vec3 screenToView(vec3 screenPos) {
	vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
	vec4 tmp = gbufferProjectionInverse * ndcPos;
	return tmp.xyz / tmp.w;
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	if (renderStage == MC_RENDER_STAGE_STARS) {
		color = glcolor;
	} else {
		// Sky color
		vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
		color = vec4(calcSkyColor(normalize(pos)), 1.0);
		color.rgb = pow(color.rgb, vec3(1.0/2.2));
	}
}
