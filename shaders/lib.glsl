#define SHADOW_BRIGHTNESS 0.2 //1.0: no shadows, 0.0: very dark shadows [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define SHADOW_BRIGHTNESS_NIGHT 0.4 //1.0: no shadows, 0.0: very dark shadows [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

uniform float rainStrength;
uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;
uniform mat4 modelViewMatrix;
uniform vec3 chunkOffset;
uniform vec3 shadowLightPosition;
uniform float near, far;
uniform vec3 fogColor;
uniform int isEyeInWater;

vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

const vec3 specularColor = vec3(1.0, 1.0, 1.0);
const float specularIntensity = 0.2;
const float specularExp = 5.0;

const vec3 blockLightColor = vec3(2.4, 1.3, 1.0);
const vec3 shadowColor = vec3(0.0, 0.05, 0.1);

const vec3 fogCol = vec3(0.6, 0.75, 1.0);
const vec3 fogLightCol = vec3(1.0, 0.6, 0.4);

const float density = 1.0;
const float underWaterDensity = 5.0;
const vec3 waterColor = vec3(0.7, 0.9, 1.0);

vec3 GetCameraDirection(vec3 pos) {
    return normalize(-pos);
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

float PhongSpecular(float intensity, float exponent, vec3 camDir, vec3 lightDir, vec3 normal) {

    float specular = clamp(dot(normalize(camDir + lightDir), normal), 0.0, 1.0);
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

vec3 ModelPosToViewPos(vec3 modelPos) {
    return (gl_ModelViewMatrix * vec4(modelPos, 1.0)).xyz;
}

vec3 PlayerPosToViewPos(vec3 playerPos) {
    return (gbufferModelView * vec4(playerPos, 1.0)).xyz;
}

vec3 ViewPosToPlayerPos(vec3 viewPos) {
    return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}

vec3 EyePosToViewPos(vec3 eyePos) {
    return mat3(gbufferModelView) * eyePos;
}

vec3 ViewPosToEyePos(vec3 viewPos) {
    return mat3(gbufferModelViewInverse) * viewPos;
}

vec3 EyePosToWorldPos(vec3 eyePos) {
    return eyePos + eyeCameraPosition;
}

vec3 WorldPosToEyePos(vec3 worldPos) {
    return worldPos - eyeCameraPosition;
}

vec3 WorldPosToViewPos(vec3 worldPos) {
    return mat3(gbufferModelView) * (worldPos - cameraPosition);
}

vec3 ViewPosToWorldPos(vec3 viewPos) {
    return mat3(gbufferModelViewInverse) * viewPos + cameraPosition;
}

vec4 ViewPosToClipPos(vec3 viewPos) {
    return gbufferProjection * vec4(viewPos, 1.0);
}

vec3 ClipPosToViewPos(vec4 clipPos) {
    return (gbufferProjectionInverse * clipPos).xyz;
}

vec3 ClipPosToNdcPos(vec4 clipPos) {
    return clipPos.xyz / clipPos.w;
}

vec3 NdcPosToScreenPos(vec3 ndcPos) {
    return ndcPos * 0.5 + 0.5;
}

vec3 ScreenPosToNdcPos(vec3 screenPos) {
    return screenPos * 2.0 - 1.0;
}

vec3 ViewPosToScreenPos(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    return (clip.xyz / clip.w) * 0.5 + 0.5;
}

vec3 ScreenPosToViewPos(vec3 screenPos) {
    vec3 ndc = screenPos * 2.0 - 1.0;
    vec4 homogeneous = gbufferProjectionInverse * vec4(ndc, 1.0);
    return homogeneous.xyz / homogeneous.w;
}
