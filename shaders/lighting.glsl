#define SHADOW_BRIGHTNESS 0.2 //1.0: no shadows, 0.0: very dark shadows [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define SHADOW_BRIGHTNESS_NIGHT 0.4 //1.0: no shadows, 0.0: very dark shadows [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

uniform float rainStrength;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 modelViewMatrix;
uniform vec3 chunkOffset;
uniform vec3 shadowLightPosition;
uniform float near, far;
uniform vec3 fogColor;
uniform int isEyeInWater;

const vec3 specularColor = vec3(1.0, 1.0, 1.0);
const float specularIntensity = 0.2;
const float specularExp = 5.0;

const vec3 blockLightColor = vec3(2.4, 1.3, 1.0);
const vec3 shadowColor = vec3(0.0, 0.05, 0.1);

const vec3 fogCol = vec3(0.6, 0.75, 1.0);
const vec3 fogLightCol = vec3(1.0, 0.6, 0.4);

const float density = 1.0;
const float underWaterDensity = 5.0;

in vec3 vertexPosition;

vec3 GetCameraDirection() {
    return normalize(-vertexPosition);
}

vec3 GetSunDirection() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition);
}

float GetSunVisibility() {
    vec3 sunDirection = GetSunDirection();
    return clamp((dot(sunDirection, vec3(0, 1, 0)) + 0.05) * 10.0, 0.0, 1.0);
}

vec3 GetShadowLightDirection() {
    return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
}

float ShadowBrightnessAdjusted(float lmx) {
    float adjusted = mix(SHADOW_BRIGHTNESS_NIGHT, SHADOW_BRIGHTNESS, GetSunVisibility());
    adjusted = mix(adjusted, 1.0, rainStrength);
    return mix(adjusted, 1.0, lmx);
}

float PhongSpecular(float intensity, float exponent) {

    float specular = clamp(dot(normalize(GetShadowLightDirection() + GetCameraDirection()), normal), 0.0, 1.0);
    specular = pow(specular, exponent) * intensity;

    return specular;
}

float getFogDensity() {
    return mix(density, underWaterDensity, isEyeInWater);
}

float GetDay() {
    return 1.0;
}

vec3 GetFogColor(float day) {
    return fogColor;
}
