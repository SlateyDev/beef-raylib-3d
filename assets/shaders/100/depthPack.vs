#version 100

// Input vertex attributes
attribute vec3 vertexPosition;

// Input uniform values
uniform mat4 mvp;

// Output vertex attributes (to fragment shader)
varying float v_depth;

void main()
{
    gl_Position = mvp * vec4(vertexPosition, 1.0);
    v_depth = gl_Position.z / gl_Position.w;
}