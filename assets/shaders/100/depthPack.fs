#version 100
precision highp float;

// This shader is based on the basic lighting shader
// This only supports one light, which is directional, and it (of course) supports shadows

// Input vertex attributes (from vertex shader)
varying float v_depth;

vec4 packFloatToRgba(float depth) {
    const vec4 bitShift = vec4(16777216.0, 65536.0, 256.0, 1.0);
    const vec4 bitMask  = vec4(0.0, 1.0 / 256.0, 1.0 / 256.0, 1.0 / 256.0);
    vec4 res = fract(depth * bitShift);
    res -= res.xxyz * bitMask;
    return res;
}

void main()
{
    float depth = v_depth * 0.5 + 0.5;
    gl_FragColor = packFloatToRgba(depth);
}