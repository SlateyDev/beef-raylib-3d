#version 100
precision highp float;

// Input vertex attributes (from vertex shader)
varying vec3 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;
varying vec3 fragNormal;

// Input uniform values
uniform mat4 matView;
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Input lighting values
uniform vec3 lightDir;
uniform vec4 lightColor;
uniform vec4 ambient;
uniform vec3 viewPos;

// Input shadowmapping values
uniform mat4 lightVP[4];
uniform sampler2D shadowMap[4];
uniform float cascadeSplits[5];

uniform int shadowMapResolution;

// Add this uniform for controlling blend zone size
const float cascadeBlendWidth = 1.0;

float unpackRgbaToFloat(vec4 _rgba) {
    const vec4 shift = vec4(1.0 / (256.0 * 256.0 * 256.0), 1.0 / (256.0 * 256.0), 1.0 / 256.0, 1.0);
    return dot(_rgba, shift);
}

float SampleShadow(int cascade) {
    // Shadow calculations
    vec4 fragPosLightSpace;
    
    if (cascade == 0) {
        fragPosLightSpace = lightVP[0] * vec4(fragPosition, 1);
    } else if (cascade == 1) {
        fragPosLightSpace = lightVP[1] * vec4(fragPosition, 1);
    } else if (cascade == 2) {      
        fragPosLightSpace = lightVP[2] * vec4(fragPosition, 1);
    } else if (cascade == 3) {
        fragPosLightSpace = lightVP[3] * vec4(fragPosition, 1);
    }
    fragPosLightSpace.xyz /= fragPosLightSpace.w;
    fragPosLightSpace.xyz = fragPosLightSpace.xyz * 0.5 + 0.5;

    vec2 sampleCoords = fragPosLightSpace.xy;
    float curDepth = fragPosLightSpace.z;

    if (curDepth > 1.0) return 0.0;

    // Slope-scale depth bias: depth biasing reduces "shadow acne" artifacts, where dark stripes appear all over the scene.
    // The solution is adding a small bias to the depth
    // In this case, the bias is proportional to the slope of the surface, relative to the light
    vec3 normal = normalize(fragNormal);

    // Slope-scale depth bias: depth biasing reduces "shadow acne" artifacts, where dark stripes appear all over the scene.
    // The solution is adding a small bias to the depth
    // In this case, the bias is proportional to the slope of the surface, relative to the light
    float bias = -0.00015;// max(0.0000001 * (1.0 - dot(normal, l)), 0.000000001);
    if (cascade == 0) {
        bias = -0.00015;
    } else if (cascade == 1) {
        bias = -0.00015;
    } else if (cascade == 2) {
        bias = 0.0000;
    } else if (cascade == 3) {
        bias = 0.00015;
    }

    // Increased kernel size for better blurring (5x5 instead of 3x3)
    const int kernelSize = 1;
    const float weightTotal = (float(kernelSize * 2 + 1)) * (float(kernelSize * 2 + 1));
    float shadow = 0.0;

    // PCF (percentage-closer filtering) algorithm:
    // Instead of testing if just one point is closer to the current point,
    // we test the surrounding points as well.
    // This blurs shadow edges, hiding aliasing artifacts.
    vec2 texelSize = vec2(1.0 / float(shadowMapResolution));
    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            vec2 offset = vec2(x, y) * texelSize;
            float weight = (1.0 - length(offset) * 0.5); // Weight drops off with distance
            float sampleDepth = 0.0;
            if (cascade == 0) {
                sampleDepth = unpackRgbaToFloat(texture2D(shadowMap[0], sampleCoords + offset));
            } else if (cascade == 1) {
                 sampleDepth = unpackRgbaToFloat(texture2D(shadowMap[1], sampleCoords + offset));
             } else if (cascade == 2) {
                 sampleDepth = unpackRgbaToFloat(texture2D(shadowMap[2], sampleCoords + offset));
             } else if (cascade == 3) {
                 sampleDepth = unpackRgbaToFloat(texture2D(shadowMap[3], sampleCoords + offset));
             }
            if (curDepth - bias > sampleDepth) shadow += weight;
        }
    }
    return shadow / weightTotal;
}

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    vec3 lightDot = vec3(0.0);
    vec3 normal = normalize(fragNormal);
    vec3 viewD = normalize(viewPos - fragPosition);
    vec3 specular = vec3(0.0);

    vec3 l = -lightDir;

    float NdotL = max(dot(normal, l), 0.0);
    lightDot += lightColor.rgb * NdotL;

    float specCo = 0.0;
    if (NdotL > 0.0) specCo = pow(max(0.0, dot(viewD, reflect(-(l), normal))), 16.0); // 16 refers to shine
    specular += specCo;

    gl_FragColor = (texelColor * fragColor * ((colDiffuse + vec4(specular, 1.0)) * vec4(lightDot, 1.0)));

    vec4 fragPosViewSpace = matView * vec4(fragPosition, 1.0);
    float depthValue = abs(fragPosViewSpace.z);

    if (depthValue < cascadeSplits[4]) {
        // Find cascade and calculate blend factor
        int cascade = 4; // Default to last cascade
        float blendFactor = 0.0;
        
        // Check all but last cascade
        for (int i = 0; i < 4; i++) {
            float splitStart;
            float splitEnd;
            if (i == 0) {
                splitStart = cascadeSplits[0];
                splitEnd = cascadeSplits[1];
            } else if (i == 1) {
                splitStart = cascadeSplits[1];
                splitEnd = cascadeSplits[2];
            } else if (i == 2) {
                splitStart = cascadeSplits[2];
                splitEnd = cascadeSplits[3];
            } else {
                splitStart = cascadeSplits[3];
                splitEnd = cascadeSplits[4];
            }
            
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
        if (blendFactor > 0.0 && cascade < 4) {
            float nextShadow = SampleShadow(cascade + 1);
            shadow = mix(shadow, nextShadow, blendFactor);
        }

        gl_FragColor = mix(gl_FragColor, vec4(0, 0, 0, 1), float(shadow));

        // if (cascade == 0) {
        //     gl_FragColor *= vec4(1, 0, 0, 1);   // Red
        // } else if (cascade == 1) {
        //     gl_FragColor *= vec4(1, 1, 0, 1);   // Yellow
        // } else if (cascade == 2) {
        //     gl_FragColor *= vec4(0, 0, 1, 1);   // Blue
        // } else if (cascade == 3) {
        //     gl_FragColor *= vec4(1, 0, 1, 1);   // Magenta
        // }
    }

    // Add ambient lighting whether in shadow or not
    gl_FragColor += texelColor * (ambient / 10.0) * colDiffuse;

    // Gamma correction
    gl_FragColor = pow(gl_FragColor, vec4(1.0 / 2.2));
}