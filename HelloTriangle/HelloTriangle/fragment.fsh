
uniform sampler2D ourTexture;

varying lowp vec2 TexCoord;

void main(void) {
//    gl_FragColor = vec4(1, 0, 0, 1);
    gl_FragColor = texture2D(ourTexture, TexCoord);
}
