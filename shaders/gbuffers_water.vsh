#version 330 compatibility

#define WAVING_WATER // Waving water
#define waves_amplitude 0.4    //[0.05 0.1 0.15 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]

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

float getWaves(vec2 coords)
{
	// Sum together several octaves of sine waves

	// Starting values, these will change with each iteration
    float period = 4.0;
    float wavelength = 4.0;
    float direction = 1.0;
    float amplitude = 0.15;
    float offset = 0.0;

    float sum = 0.0;
	float sumOfAmps = 0.0;
    
    int iterations = 10;
    for(int i = 0; i < iterations; i++)
    {
        float xComponent = cos(direction);
        float yComponent = sin(direction);

        float wave = amplitude * sin(2.0*PI *(frameTimeCounter/period + (coords.x*xComponent + coords.y*yComponent)/wavelength + offset));
        
        sum += wave;
		sumOfAmps += amplitude;
        
		// Modify wave properties for next iteration
        period *= 0.91;
        wavelength *= 0.93;
        amplitude *= 0.87;
        direction += float(i) * 11.258912;
        offset += 13.237894;
    }
    
	// exp to get a better wave shape and to normalize wave to be from 0 to 1
	// - 0.4 to roughly center the wave vertically
    return exp(sum/sumOfAmps - 1.0) - 0.4;
}

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
	// Vertical displacement of vertices
	float wave = getWaves(worldPosition.xz);
	worldPosition.y += wave*waves_amplitude;
	// Derivatives of wave in x and z direction using finite difference
	float xderiv = waves_amplitude * (getWaves(worldPosition.xz + vec2(0.01, 0.0)) - wave) / 0.01;
	float zderiv = waves_amplitude * (getWaves(worldPosition.xz + vec2(0.0, 0.01)) - wave) / 0.01;
	// Calculate normal vector based on derivatives
	vec3 xtan = vec3(1.0, xderiv, 0.0);
	vec3 ztan = vec3(0.0, zderiv, 1.0);
	normal = normalize(cross(ztan, xtan));
#endif

	shadowPos.w = lightDot;
	gl_Position = gl_ProjectionMatrix * vec4(WorldPosToViewPos(worldPosition), 1.0);
}