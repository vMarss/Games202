attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat4 uLightMVP;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp vec4 vPositionFromLight;

void main(void) {

  vFragPos = (uModelMatrix * vec4(aVertexPosition, 1.0)).xyz;
  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;

  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);

  vTextureCoord = aTextureCoord;

  // 记录该顶点在shadow空间坐标系下的位置信息
  vPositionFromLight = uLightMVP * vec4(aVertexPosition, 1.0);

  // 对于每个传入的模型顶点数据，都将其位置从世界坐标空间转换到光的坐标空间，如此可以直观的看到模型在光照坐标空间下的位置信息等
  // gl_Position = vPositionFromLight;
}