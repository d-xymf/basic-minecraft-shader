#version 330 compatibility

uniform sampler2D gtexture;
uniform float viewHeight;
uniform float viewWidth;

uniform float alphaTestRef = 0.1;

in vec2 texcoord;
in vec4 glcolor;

#include "/world1/lib_world1.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 screenToView(vec3 screenPos) {
	vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
	vec4 tmp = gbufferProjectionInverse * ndcPos;
	return tmp.xyz / tmp.w;
}

void main() {
	//color = texture(gtexture, texcoord) * glcolor;
	color = vec4(0.0);

	color.rgb = pow(color.rgb, vec3(2.2));

	vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
	color = vec4(calcSkyColor(normalize(pos)), 1.0);

	//color.rgb += pow(texture(gtexture, texcoord).rgb * glcolor.rgb, vec3(2.2)) * 0.1;

	color.rgb = pow(color.rgb, vec3(1.0/2.2));

	if (color.a < alphaTestRef) {
		discard;
	}
}