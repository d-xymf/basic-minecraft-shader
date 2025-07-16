#version 330 compatibility

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

in vec3 vaPosition;
in vec3 vaNormal;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec4 shadowPos;
out vec3 vertexPosition;
out vec3 worldPosition;
out float depth;
out vec3 normal;

uniform float frameTimeCounter;

#include "/distort.glsl"
#include "lib.glsl"
#include "waves.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	vertexPosition = gl_Vertex.xyz;
	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
	worldPosition = ViewPosToWorldPos(viewPos.xyz);
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

	// Vertical displacement of vertices
	float wave = getWaves(worldPosition.xz);
	worldPosition.y += wave*waves_amplitude;

	shadowPos.w = lightDot;
	gl_Position = gl_ProjectionMatrix * vec4(WorldPosToViewPos(worldPosition), 1.0);
}