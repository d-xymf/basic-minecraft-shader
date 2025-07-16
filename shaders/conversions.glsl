uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;

vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

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