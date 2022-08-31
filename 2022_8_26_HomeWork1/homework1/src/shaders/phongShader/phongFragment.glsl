#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 20
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

// 泊松圆盘采样
void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

// 均匀圆盘采样
void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
	return 1.0;
}

float PCF(sampler2D shadowMap, vec4 coords) {
  // 1. 采样ShadowMap上该点周围一块区域的深度，并得出其平均深度来计算
  // 1.0 确定一个随机种子
  vec2 randomSeed = vec2(5.0, 4.0);

  // 1.1.1 采用泊松圆盘采样
  poissonDiskSamples(randomSeed);

  // 1.1.2 采用均匀圆盘采样
  // uniformDiskSamples(randomSeed);

  // TOOD 下面的滤波部分还没有看懂
  // TOOD 下面的滤波部分还没有看懂
  // TOOD 下面的滤波部分还没有看懂
  // shadowMap的大小，越大滤波的范围越小
  float textureSize = 2048.;
  // 滤波的步长
  float filterStride = 5.0;
  // 滤波窗口的范围
  float filterRange = filterStride / textureSize;

  // 1.2 记录范围内有多少个ShadingPoint是被遮挡的
  float sumBlock = 0.0;
  float bias = 0.005;
  for(int i = 0; i < NUM_SAMPLES; i++){
    vec2 shadowCoord = coords.xy + poissonDisk[i] * filterRange;
    float shadowDepthTmp = unpack(texture2D(shadowMap, shadowCoord));
    if(shadowDepthTmp > (coords.z - bias)){
      sumBlock += 1.0;
    }
  }

  // 3. 如果ShadowMap的深度小于顶点的实际深度，说明被遮挡，显示为阴影，这里赋为0，在外面与color点乘时为黑色
  return sumBlock / float(NUM_SAMPLES);
}

float PCSS(sampler2D shadowMap, vec4 coords){

  // STEP 1: avgblocker depth

  // STEP 2: penumbra size

  // STEP 3: filtering
  
  return 1.0;

}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  // 1. 采样ShadowMap上该点的深度
  float shadowDepth = unpack(texture2D(shadowMap, shadowCoord.xy));
  // 2. 获取该顶点的实际深度
  float realDepth = shadowCoord.z;

  // 2.1 增加阴影容差bias，防止阴影失真现象，该值不宜过大，过大会导致另一个问题“彼得潘”
  float bias = 0.005;

  // 3. 如果ShadowMap的深度小于顶点的实际深度，说明被遮挡，显示为阴影，这里赋为0，在外面与color点乘时为黑色
  return shadowDepth < realDepth - bias ? 0.0 : 1.0;
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {

  float visibility;
  // 1. 将三维世界空间坐标系的点转换到光的坐标系，这一步在phongVertex中处理了，坐标为vPositionFromLight
  // vPositionFromLight = uLightMVP * vec4(aVertexPosition, 1.0);

  // 2. 将该坐标转换为NDC，方便后面找到ShadowMap上对应的UV坐标
  vec3 shadowCoord = vPositionFromLight.xyz / vPositionFromLight.w;

  // 3. 目前得到的点是一个在-1~1范围的CVV空间坐标，而UV坐标是0~1，需要处理一波 (x -(-1)) / 1 - (-1) * (1 - 0) + 0
  shadowCoord = shadowCoord * 0.5 + 0.5;

  // 4. 获取ShadowMap在该点是否为阴影
  // 4.1 原汁原味的ShadowMap
  // visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));
  // 4.2 PCF软阴影实现方案
  visibility = PCF(uShadowMap, vec4(shadowCoord, 1.0));
  //visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0));

  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  // gl_FragColor = vec4(phongColor, 1.0);
}