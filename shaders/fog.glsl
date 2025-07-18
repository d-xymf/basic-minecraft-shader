uniform float near, far;
uniform int worldTime;
uniform int isEyeInWater;

const vec3 dayDryFogColor = vec3(0.86, 1.0, 1.0);
const vec3 nightDryFogColor = vec3(0.16, 0.19, 0.23);
const float dryFogGain = 3;
const float dryFogDensity = 0.022;

const vec3 dayRainFogColor = vec3(0.65, 0.65, 0.7);
const vec3 nightRainFogColor = vec3(0.25, 0.26, 0.29);
const float rainFogGain = 3;
const float rainFogDensity = 0.06;

const vec3 dayWaterFogColor = vec3(0.0, 0.3, 0.45);
const vec3 nightWaterFogColor = vec3(0.01, 0.05, 0.1);
const float waterFogGain = 1.0;
const float waterFogDensity = 0.1;

const vec3 dayIceFogColor = vec3(0.6, 0.7, 0.8);
const vec3 nightIceFogColor = vec3(0.05, 0.05, 0.1);
const float iceFogGain = 1.0;
const float iceFogDensity = 4.0;

const vec3 dayLavaFogColor = vec3(1.0, 0.4, 0.05);
const vec3 nightLavaFogColor = vec3(1.0, 0.5, 0.1);
const float lavaFogGain = 1.0;
const float lavaFogDensity = 2.0;

const vec3 daySnowFogColor = vec3(0.8, 0.9, 1.0);
const vec3 nightSnowFogColor = vec3(0.8, 0.9, 1.0);
const float snowFogGain = 1.0;
const float snowFogDensity = 1.0;

float LinearDepth(float z) {
    return 1.0 / ((1 - far / near) * z + (far / near));
}

vec3 CalcFog(vec3 fragColor, vec3 dFogColor, vec3 nFogColor, float gain, float density, float fogMask, float depth) {
    float night = clamp((worldTime - 12500.0) / 1500.0, 0.0, 1.0) - clamp((worldTime - 22500.0) / 1000.0, 0.0, 1.0);
    vec3 fogColor = mix(dFogColor, nFogColor, night);

    return mix(fragColor, fogColor, pow(1 - exp(-depth * density), gain) * fogMask);
}