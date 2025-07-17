#version 330 compatibility

uniform sampler2D gtexture;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform vec3 skyColor;

in vec2 texcoord;

#include "lib.glsl"

/* DRAWBUFFERS: 0 */
layout(location = 0) out vec4 outColor0;

float LinearDepth(float z) {
    return 1.0 / ((1 - far / near) * z + (far / near));
}

float fogify(float x, float w) {
	return w / (x * x + w);
}

float luminosity(vec3 color) {
	return dot(color, vec3(0.213, 0.715, 0.072));
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

void main() {
	vec4 color = texture(colortex0, texcoord);

	color.rgb = pow(color.rgb, vec3(2.2));

	float water = texture(colortex4, texcoord).r;

	vec3 debug = vec3(0.0);

	float sunVis = GetSunVisibility();

	if(water >= 0.1) {

		float depth = texture(depthtex0, texcoord).r;
		float lineardepth0 = LinearDepth(depth);
		float lineardepth1 = LinearDepth(texture(depthtex1, texcoord).r);

		// Water fog
		if(isEyeInWater == 0.0) {
			//color.rgb *= waterTint;
			vec3 densities = GetFogDensities(sunVis, rainStrength, 1.0);

			vec3 fogFactors = exp(-densities * (lineardepth1 - lineardepth0));

			color.rgb = mix(color.rgb, GetLightColor(sunVis, rainStrength, 1.0), pow(1.0 - fogFactors, vec3(2.0)));
			//color.rgb = vec3(lineardepth1);
		}


		vec3 normal = texture(colortex1, texcoord).xyz * 2.0 - 1.0;
		vec3 screenPos = vec3(texcoord, depth);
		vec3 eyePos = ViewPosToEyePos(ScreenPosToViewPos(screenPos));
		vec3 rayDir = normalize(eyePos);
		float hit = 0.0;

		float accuracy = length(eyePos) * 0.03;

		// Reflect ray
		rayDir = rayDir - 2.0 * dot(normal, rayDir) * normal;

		vec3 rayPos = eyePos + rayDir * accuracy;

		vec3 reflection = calcSkyColor(EyePosToViewPos(rayDir));

		// Ray marching SSR
		for(int i = 0; i < 100; i++) {
			vec3 rayScreenPos = ViewPosToScreenPos(EyePosToViewPos(rayPos));

			// Check if rayPos is outside of screen
			if(rayScreenPos.x > 1.0 || rayScreenPos.x < 0.0) {
				break;
			}
			if(rayScreenPos.y > 1.0 || rayScreenPos.y < 0.0) {
				break;
			}
			if(LinearDepth(rayScreenPos.z) > 1.0) {
				break;
			}

			float rayDepth = LinearDepth(rayScreenPos.z);
			float depthAtRayPos = LinearDepth(texture(depthtex0, rayScreenPos.xy).r);

			// Check if collision
			if(rayDepth >= depthAtRayPos) {
				if(abs(rayDepth - depthAtRayPos) < 0.2) {
					// Collision within screen

					hit = 1.0;
					
					reflection = texture(colortex0, rayScreenPos.xy).rgb;
					reflection = pow(reflection, vec3(2.2));
					break;
				}
			}

			// If not march ray
			rayPos += rayDir * 0.5;
			debug = vec3(float(i/100.0));
		}

		float reflectionFactor = (1.0 - abs(dot(normal, normalize(-eyePos))));
		color.rgb = mix(color.rgb * waterTint, reflection, reflectionFactor);
		
		// Phong specular highlights
		vec3 lightDirection = normalize(ViewPosToEyePos(shadowLightPosition));
		vec3 specular = 0.5*GetShadowLightColor(sunVis, rainStrength) * smoothstep(0.98 - sunVis*0.04, 1.0, dot(rayDir, lightDirection));
		//debug = vec3(eyePos);
		color.rgb += mix(specular * (1.0 - hit), vec3(0.0), rainStrength);

		// Fog
		vec3 densities = GetFogDensities(sunVis, rainStrength, isEyeInWater);
		vec3 fogFactors = (exp(-densities * lineardepth0));
		color.rgb = mix(color.rgb, GetLightColor(sunVis, rainStrength, isEyeInWater), pow(1.0 - fogFactors, vec3(2.0)));
	}

	//outColor0 = mix(vec4(0.0, 0.0, 0.0, 1.0), vec4(reflection, 1.0), water * reflectionFactor);
	color.rgb = pow(color.rgb, vec3(1.0/2.2));
	outColor0 = color;
	//outColor0 = texture(gtexture, texcoord);
	//outColor0 = vec4(debug, 1.0);
}