#version 330 compatibility

#define WAVING_WATER // Waving water
#define waves_amplitude 0.65    //[0.55 0.65 0.75 0.85 0.95 1.05 1.15 1.25 1.35 1.45 1.55 1.65 1.75 1.85 1.95 2.05]

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 shadowLightPosition;

in vec3 vaPosition;
in vec3 vaNormal;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec4 shadowPos;
out vec3 vertexPosition;
out float depth;
out vec3 normal;

#ifdef WAVING_WATER
uniform float frameTimeCounter;
float PI = 3.14159265;
#endif

#include "/distort.glsl"
#include "conversions.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	vertexPosition = gl_Vertex.xyz;
	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
	vec3 worldPosition = ViewPosToWorldPos(viewPos.xyz);
	//depth = (gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex).z;
	depth = length(viewPos.xyz);
	normal = gl_Normal;

	float lightDot = dot(normalize(shadowLightPosition), normalize(gl_NormalMatrix * gl_Normal));

	if (lightDot > 0.0) { //vertex is facing towards the sun
		vec4 playerPos = gbufferModelViewInverse * viewPos;
		shadowPos = shadowProjection * (shadowModelView * playerPos); //convert to shadow ndc space.
		float bias = computeBias(shadowPos.xyz);
		shadowPos.xyz = distort(shadowPos.xyz); //apply shadow distortion
		shadowPos.xyz = shadowPos.xyz * 0.5 + 0.5; //convert from -1 ~ +1 to 0 ~ 1
		//apply shadow bias.
		#ifdef NORMAL_BIAS
			//we are allowed to project the normal because shadowProjection is purely a scalar matrix.
			vec4 shadowNormal = shadowProjection * vec4(mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal)), 1.0);
			//a faster way to apply the same operation would be to multiply by shadowProjection[0][0].
			shadowPos.xyz += shadowNormal.xyz / shadowNormal.w * bias;
		#else
			shadowPos.z -= bias / abs(lightDot);
		#endif
	}

#ifdef WAVING_WATER
	float fy = fract(worldPosition.y + 0.001);
	float wave = 0.05 * sin(2 * PI * (frameTimeCounter*0.8 + worldPosition.x /  2.5 + worldPosition.z / 5.0))
				+ 0.05 * sin(2 * PI * (frameTimeCounter*0.6 + worldPosition.x / 6.0 + worldPosition.z /  12.0));
	worldPosition.y += clamp(wave, -fy, 1.0-fy)*waves_amplitude;
	float xderiv = 0.05 * cos(2 * PI * (frameTimeCounter*0.8 + worldPosition.x /  2.5 + worldPosition.z / 5.0)) * 2*PI / 2.5
				+ 0.05 * cos(2 * PI * (frameTimeCounter*0.6 + worldPosition.x / 6.0 + worldPosition.z /  12.0)) * 2*PI / 6;
	float zderiv = 0.05 * cos(2 * PI * (frameTimeCounter*0.8 + worldPosition.x /  2.5 + worldPosition.z / 5.0)) * 2*PI / 5
				+ 0.05 * cos(2 * PI * (frameTimeCounter*0.6 + worldPosition.x / 6.0 + worldPosition.z /  12.0)) * 2*PI / 12;
	vec3 xtan = vec3(1.0, xderiv * waves_amplitude, 0.0);
	vec3 ztan = vec3(0.0, zderiv * waves_amplitude, 1.0);
	normal = normalize(cross(ztan, xtan));
#endif

	shadowPos.w = lightDot;
	gl_Position = gl_ProjectionMatrix * vec4(WorldPosToViewPos(worldPosition), 1.0);
}