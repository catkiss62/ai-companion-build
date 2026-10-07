#include <flutter/runtime_effect.glsl>
precision mediump float;
uniform vec2 viewSize;
uniform vec2 imageSize;
uniform vec2 tilt;
uniform float strength;
uniform sampler2D roomImage;
uniform sampler2D depthImage;
out vec4 fragColor;
void main() {
    float scale = max(viewSize.x/imageSize.x, viewSize.y/imageSize.y);
    vec2 uv = (FlutterFragCoord().xy-viewSize*.5)/(imageSize*scale)+.5;
    // Overscan reserves 6% per edge; combined motion stays below 5.03%.
    uv = (uv-.5)*(1.0-.12*strength)+.5;
    // Device Motion translates the entire room before depth displacement.
    uv += tilt*.035*strength;
    vec2 shift = tilt*.018*strength;
    vec2 sampleUv = uv + shift*(texture(depthImage,uv).r-.15);
    sampleUv = uv + shift*(texture(depthImage,sampleUv).r-.15);
    fragColor = vec4(texture(roomImage, sampleUv).rgb,1.0);
}
