
attribute vec4 position;
attribute vec2 aTexCoord;

varying vec2 TexCoord;

void main(void) {
    gl_Position = position;
    TexCoord = aTexCoord;
}
