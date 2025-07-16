#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform float far;
uniform float near;
uniform vec3 skyColor;
uniform vec3 fogColor;

in vec2 texcoord;

#include "conversions.glsl"

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
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

void main() {
	vec4 color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;

	vec3 normal = texture(colortex1, texcoord).xyz * 2.0 - 1.0;

	float water = texture(colortex4, texcoord).r;

	vec3 screenPos = vec3(texcoord, depth);

	vec3 eyePos = ViewPosToEyePos(ScreenPosToViewPos(screenPos));
	vec3 rayDir = normalize(eyePos);

	float accuracy = length(eyePos) * 0.03;

	// Reflect ray
	rayDir = rayDir - 2.0 * dot(normal, rayDir) * normal;

	vec3 rayPos = eyePos + rayDir * accuracy;

	vec3 reflection = calcSkyColor(EyePosToViewPos(rayDir));

	if(water >= 0.1) {
		for(int i = 0; i < 1000; i++) {
			vec3 rayScreenPos = ViewPosToScreenPos(EyePosToViewPos(rayPos));

			// Check if rayPos is outside of screen
			if(rayScreenPos.x > 1.0 || rayScreenPos.x < 0.0) {
				break;
			}
			if(rayScreenPos.y > 1.0 || rayScreenPos.y < 0.0) {
				break;
			}

			float rayDepth = rayScreenPos.z;
			float depthAtRayPos = texture(depthtex0, rayScreenPos.xy).r;

			// Check if collision
			if(rayDepth >= depthAtRayPos) {
				if(abs(LinearDepth(rayDepth) - LinearDepth(depthAtRayPos)) < 0.2) {
					// Collision within screen
					
					reflection = texture(colortex0, rayScreenPos.xy).rgb;
					break;
				}
			}

			// If not march ray
			rayPos += rayDir * accuracy * 0.5;
		}
	}

	vec4 waterColor = mix(vec4(1.0), vec4(0.7, 0.9, 1.0, 1.0), water);
	float reflectionFactor = (1.0 + dot(normal, normalize(eyePos)));
	color = mix(color * waterColor, vec4(reflection, 1.0), water * reflectionFactor);
	//color = color * waterColor;

	//outColor0 = mix(vec4(0.0, 0.0, 0.0, 1.0), vec4(reflection, 1.0), water * reflectionFactor);
	outColor0 = color;
	//outColor0 = vec4(water);
}