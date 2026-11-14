#version 100
precision mediump float;

varying vec2 fragTexCoord;
varying vec4 fragColor;
uniform sampler2D texture0;

void main() {
    vec4 pixel = texture2D(texture0, fragTexCoord) * fragColor;
    float luma = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    pixel.rgb = mix(pixel.rgb, vec3(luma * 0.32, luma * 0.66, luma * 1.32), 0.62);
    gl_FragColor = pixel;
}
