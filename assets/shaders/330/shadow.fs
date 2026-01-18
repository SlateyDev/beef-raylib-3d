#version 330

// This shader is based on the basic lighting shader
// This only supports one light, which is directional, and it (of course) supports shadows

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;

// Input uniform values
uniform mat4 matView;
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// Input lighting values
uniform vec3 lightDir;
uniform vec4 lightColor;
uniform vec4 ambient;
uniform vec3 viewPos;

// Input shadowmapping values
#define NUM_CASCADES 4
uniform mat4 lightVP[NUM_CASCADES];
uniform sampler2D shadowMap[NUM_CASCADES];
uniform float cascadeSplits[NUM_CASCADES + 1];

const vec3 myColors[NUM_CASCADES] = vec3[](
    vec3(1.0, 0.0, 0.0), // Red
    vec3(1.0, 1.0, 0.0), // Yellow
    vec3(0.0, 0.0, 1.0), // Blue
    vec3(1.0, 0.0, 1.0) // Magenta
);

uniform int shadowMapResolution;

// Add this uniform for controlling blend zone size
uniform float cascadeBlendWidth = 0.1;

float SampleShadow(int cascade) {
    // Shadow calculations
    vec4 fragPosLightSpace = lightVP[cascade] * vec4(fragPosition, 1);
    fragPosLightSpace.xyz /= fragPosLightSpace.w;
    fragPosLightSpace.xyz = fragPosLightSpace.xyz * 0.5 + 0.5;

    vec2 sampleCoords = fragPosLightSpace.xy;
    float curDepth = fragPosLightSpace.z;

    if (curDepth > 1.0) return 0.0;

    // Slope-scale depth bias: depth biasing reduces "shadow acne" artifacts, where dark stripes appear all over the scene.
    // The solution is adding a small bias to the depth
    // In this case, the bias is proportional to the slope of the surface, relative to the light
    vec3 normal = normalize(fragNormal);
    vec3 l = -lightDir;

    // Slope-scale depth bias: depth biasing reduces "shadow acne" artifacts, where dark stripes appear all over the scene.
    // The solution is adding a small bias to the depth
    // In this case, the bias is proportional to the slope of the surface, relative to the light
    float bias = max(0.0004 * (1.0 - dot(normal, l)), 0.00004);

    // Increased kernel size for better blurring (5x5 instead of 3x3)
    const int kernelSize = 1;
    const float weightTotal = (kernelSize * 2 + 1) * (kernelSize * 2 + 1);
    float shadow = 0;

    // PCF (percentage-closer filtering) algorithm:
    // Instead of testing if just one point is closer to the current point,
    // we test the surrounding points as well.
    // This blurs shadow edges, hiding aliasing artifacts.
    vec2 texelSize = vec2(1.0 / float(shadowMapResolution));
    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            vec2 offset = vec2(x, y) * texelSize;
            float weight = (1.0 - length(offset) * 0.5); // Weight drops off with distance
            float sampleDepth = texture(shadowMap[cascade], sampleCoords + offset).r;
            if (curDepth - bias > sampleDepth) shadow += weight;
        }
    }
    return shadow / weightTotal;
}

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec3 lightDot = vec3(0.0);
    vec3 normal = normalize(fragNormal);
    vec3 viewD = normalize(viewPos - fragPosition);
    vec3 specular = vec3(0.0);

    vec3 l = -lightDir;

    //vec3 half_dir = normalize(viewD + l);

    float NdotL = max(dot(normal, l), 0.0);
    lightDot += lightColor.rgb*NdotL;

    float specCo = 0.0;
    if (NdotL > 0.0) specCo = pow(max(0.0, dot(viewD, reflect(-(l), normal))), 16.0); // 16 refers to shine
    specular += specCo;

    finalColor = (texelColor * fragColor*((colDiffuse + vec4(specular, 1.0)) * vec4(lightDot, 1.0)));

    int shadowCounter = 0;
    const int numSamples = 9;

    vec4 fragPosViewSpace = matView * vec4(fragPosition, 1.0);
    float depthValue = abs(fragPosViewSpace.z);

    if (depthValue < cascadeSplits[NUM_CASCADES - 1]) {
        // Find cascade and calculate blend factor
        int cascade = NUM_CASCADES - 1; // Default to last cascade
        float blendFactor = 0.0;
        
        // Check all but last cascade
        for (int i = 0; i < NUM_CASCADES - 1; i++) {
            float splitStart = cascadeSplits[i];
            float splitEnd = cascadeSplits[i + 1];
            
            if (depthValue < splitEnd) {
                cascade = i;
                float splitDistance = splitEnd - splitStart;
                float blendZone = splitDistance * cascadeBlendWidth;
                
                // Calculate blend factor if we're in the blend zone
                if (depthValue > splitEnd - blendZone) {
                    blendFactor = (depthValue - (splitEnd - blendZone)) / blendZone;
                    blendFactor = smoothstep(0.0, 1.0, blendFactor);
                }
                break;
            }
        }

        // Sample current and next cascade
        float shadow = SampleShadow(cascade);
        if (blendFactor > 0.0 && cascade < NUM_CASCADES - 1) {
            float nextShadow = SampleShadow(cascade + 1);
            shadow = mix(shadow, nextShadow, blendFactor);
        }

        finalColor = mix(finalColor, vec4(0, 0, 0, 1), float(shadow));

    }
    //finalColor *= vec4(myColors[cascade], 1);

    // Add ambient lighting whether in shadow or not
    finalColor += texelColor * (ambient / 10.0) * colDiffuse;

    // Gamma correction
    finalColor = pow(finalColor, vec4(1.0 / 2.2));
}