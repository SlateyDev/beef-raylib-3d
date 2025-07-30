using System;
using System.Collections;
using RaylibBeef;

namespace game;

class World
{
    private List<uint8> mLevelData = new .() ~ delete(mLevelData);
    private int mWidth = 100;
    private int mHeight = 100;

    private RenderTexture2D mShadowMap;
    private Camera3D mLightCamera;
    private Shader mDepthShader;
    private Shader mShadowShader;
    private Matrix mLightSpaceMatrix;
    private Vector3 lightDir = Raymath.Vector3Normalize(.( 0.35f, -1.0f, -0.35f ));
    private Color lightColor = Raylib.WHITE;
    private Vector4 lightColorNormalized = Raylib.ColorNormalize(lightColor);

    private int32 lightVPLoc = 0;
    private int32 shadowMapLoc = 0;
    private int32 lightDirLoc = 0;

    const int32 SHADOWMAP_RESOLUTION = 2048;

    char8* shadowVs =
        """
        #version 100

        // Input vertex attributes
        attribute vec3 vertexPosition;
        attribute vec2 vertexTexCoord;
        attribute vec3 vertexNormal;
        attribute vec4 vertexColor;

        // Input uniform values
        uniform mat4 mvp;
        uniform mat4 matModel;
        uniform mat4 matNormal;

        // Output vertex attributes (to fragment shader)
        varying vec3 fragPosition;
        varying vec2 fragTexCoord;
        varying vec4 fragColor;
        varying vec3 fragNormal;

        // NOTE: Add your custom variables here

        void main()
        {
            // Send vertex attributes to fragment shader
            fragPosition = vec3(matModel*vec4(vertexPosition, 1.0));
            fragTexCoord = vertexTexCoord;
            fragColor = vertexColor;
            fragNormal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));

            // Calculate final vertex position
            gl_Position = mvp*vec4(vertexPosition, 1.0);
        }
        """;

    char8* shadowFs =
        """
        #version 100

        precision mediump float;

        // This shader is based on the basic lighting shader
        // This only supports one light, which is directional, and it (of course) supports shadows

        // Input vertex attributes (from vertex shader)
        varying vec3 fragPosition;
        varying vec2 fragTexCoord;
        varying vec4 fragColor;
        varying vec3 fragNormal;

        // Input uniform values
        uniform sampler2D texture0;
        uniform vec4 colDiffuse;

        // Input lighting values
        uniform vec3 lightDir;
        uniform vec4 lightColor;
        uniform vec4 ambient;
        uniform vec3 viewPos;

        // Input shadowmapping values
        uniform mat4 lightVP; // Light source view-projection matrix
        uniform sampler2D shadowMap;

        uniform int shadowMapResolution;

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
            lightDot += lightColor.rgb*NdotL;

            float specCo = 0.0;
            if (NdotL > 0.0) specCo = pow(max(0.0, dot(viewD, reflect(-(l), normal))), 16.0); // 16 refers to shine
            specular += specCo;

            vec4 finalColor = (texelColor*fragColor*((colDiffuse + vec4(specular, 1.0))*vec4(lightDot, 1.0)));

            // Shadow calculations
            vec4 fragPosLightSpace = lightVP*vec4(fragPosition, 1);
            fragPosLightSpace.xyz /= fragPosLightSpace.w; // Perform the perspective division
            fragPosLightSpace.xyz = (fragPosLightSpace.xyz + 1.0)/2.0; // Transform from [-1, 1] range to [0, 1] range
            vec2 sampleCoords = fragPosLightSpace.xy;
            float curDepth = fragPosLightSpace.z;

            // Slope-scale depth bias: depth biasing reduces "shadow acne" artifacts, where dark stripes appear all over the scene.
            // The solution is adding a small bias to the depth
            // In this case, the bias is proportional to the slope of the surface, relative to the light
            float bias = max(0.0008*(1.0 - dot(normal, l)), 0.00008);
            int shadowCounter = 0;
            const int numSamples = 9;
            
            // PCF (percentage-closer filtering) algorithm:
            // Instead of testing if just one point is closer to the current point,
            // we test the surrounding points as well.
            // This blurs shadow edges, hiding aliasing artifacts.
            vec2 texelSize = vec2(1.0/float(shadowMapResolution));
            for (int x = -1; x <= 1; x++)
            {
                for (int y = -1; y <= 1; y++)
                {
                    float sampleDepth = texture2D(shadowMap, sampleCoords + texelSize*vec2(x, y)).r;
                    if (curDepth - bias > sampleDepth) shadowCounter++;
                }
            }
            
            finalColor = mix(finalColor, vec4(0, 0, 0, 1), float(shadowCounter)/float(numSamples));

            // Add ambient lighting whether in shadow or not
            finalColor += texelColor*(ambient/10.0)*colDiffuse;

            // Gamma correction
            finalColor = pow(finalColor, vec4(1.0/2.2));
            gl_FragColor = finalColor;
        }
        """;

    public this()
    {
        // Initialize shadow mapping resources
        mShadowMap = LoadShadowmapRenderTexture(SHADOWMAP_RESOLUTION, SHADOWMAP_RESOLUTION);
        mShadowShader = Raylib.LoadShaderFromMemory(shadowVs, shadowFs);
        ((int32*)mShadowShader.locs)[ShaderLocationIndex.SHADER_LOC_VECTOR_VIEW] = Raylib.GetShaderLocation(mShadowShader, "viewPos");
        lightDirLoc = Raylib.GetShaderLocation(mShadowShader, "lightDir");
        int32 lightColLoc = Raylib.GetShaderLocation(mShadowShader, "lightColor");
        Raylib.SetShaderValue(mShadowShader, lightDirLoc, &lightDir, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
        Raylib.SetShaderValue(mShadowShader, lightColLoc, &lightColorNormalized, ShaderUniformDataType.SHADER_UNIFORM_VEC4);
        int32 ambientLoc = Raylib.GetShaderLocation(mShadowShader, "ambient");
        float[4] ambient = .(0.4f, 0.4f, 0.4f, 1.0f);
        Raylib.SetShaderValue(mShadowShader, ambientLoc, &ambient, ShaderUniformDataType.SHADER_UNIFORM_VEC4);
        lightVPLoc = Raylib.GetShaderLocation(mShadowShader, "lightVP");
        shadowMapLoc = Raylib.GetShaderLocation(mShadowShader, "shadowMap");
        int32 shadowMapResolution = SHADOWMAP_RESOLUTION;
        Raylib.SetShaderValue(mShadowShader, Raylib.GetShaderLocation(mShadowShader, "shadowMapResolution"), &shadowMapResolution, ShaderUniformDataType.SHADER_UNIFORM_INT);

        // Setup light camera and calculate light space matrix
        mLightCamera = .(
            Raymath.Vector3Scale(lightDir, -15.0f),  // Light position
            Raymath.Vector3Zero(),     // Looking at center
            .(0.0f, 1.0f, 0.0f),     // Up vector
            60.0f,                    // FOV
            CameraProjection.CAMERA_ORTHOGRAPHIC       // Projection type
        );
    }

    public ~this() {
        UnloadShadowmapRenderTexture(mShadowMap);
        Raylib.UnloadShader(mDepthShader);
        Raylib.UnloadShader(mShadowShader);
    }

    public void LoadLevel(StringView filePath) {
        // For now we'll just create a simple floor
    }

    public void Update() {
        // Update world state
    }

    Matrix lightView;
    Matrix lightProj;

    public void Render(Camera3D playerCamera) {
        Vector3 cameraPos = playerCamera.position;
        Raylib.SetShaderValue(mShadowShader, ((int32*)mShadowShader.locs)[ShaderLocationIndex.SHADER_LOC_VECTOR_VIEW], &cameraPos, ShaderUniformDataType.SHADER_UNIFORM_VEC3);

        // First pass: render to shadow map
        // Draw scene from light's perspective
        RenderSceneForShadow();

        // Second pass: render scene with shadows
        // Render the scene from player perspective
        RenderSceneWithShadows(playerCamera);
    }

    private void RenderSceneForShadow() {
        Raylib.BeginTextureMode(mShadowMap);
        Raylib.ClearBackground(Raylib.WHITE);
        Raylib.BeginMode3D(mLightCamera);
        lightView = Rlgl.rlGetMatrixModelview();
        lightProj = Rlgl.rlGetMatrixProjection();

        // Draw floor
        //Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mWidth, mHeight), Raylib.BLACK);
        
        DrawCubes(Raylib.BLACK);

        Raylib.EndMode3D();
        Raylib.EndTextureMode();
    }

    private void RenderSceneWithShadows(Camera3D playerCamera) {
        Raylib.ClearBackground(Raylib.BEIGE);

        // Calculate MVP matrix for the current camera
        Matrix lightViewProj = Raymath.MatrixMultiply(lightView, lightProj);
        Raylib.SetShaderValueMatrix(mShadowShader, lightVPLoc, lightViewProj);

        int32 slot = 10; // Can be anything 0 to 15, but 0 will probably be taken up
        Rlgl.rlActiveTextureSlot(slot);
        Rlgl.rlEnableTexture(mShadowMap.depth.id);
        Rlgl.rlSetUniform(shadowMapLoc, &slot, ShaderUniformDataType.SHADER_UNIFORM_INT, 1);
        Raylib.BeginShaderMode(mShadowShader);

        Raylib.BeginMode3D(playerCamera);

        // Draw floor
        Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mWidth, mHeight), Raylib.DARKGRAY);

        DrawCubes(Raylib.BLUE);

        Raylib.EndShaderMode();
        Raylib.EndMode3D();
    }

    private void DrawCubes(Color color) {
        // Draw cubes
        for (int i = -5; i <= 5; i++) {
            for (int j = -5; j <= 5; j++) {
                if ((i + j) % 2 == 0) {
                    Raylib.DrawCube(.(i * 4.0f, 1.0f, j * 4.0f), 1.0f, 2.0f, 1.0f, color);
                }
            }
        }
    }

    private RenderTexture2D LoadShadowmapRenderTexture(int32 width, int32 height) {
        RenderTexture2D target = .{ id = 0 };
    
        target.id = Rlgl.rlLoadFramebuffer(); // Load an empty framebuffer
        target.texture.width = width;
        target.texture.height = height;
    
        if (target.id > 0)
        {
            Rlgl.rlEnableFramebuffer(target.id);
    
            // Create depth texture
            // We don't need a color texture for the shadowmap
            target.depth.id = Rlgl.rlLoadTextureDepth(width, height, false);
            target.depth.width = width;
            target.depth.height = height;
            target.depth.format = 19;       //DEPTH_COMPONENT_24BIT?
            target.depth.mipmaps = 1;
    
            // Attach depth texture to FBO
            Rlgl.rlFramebufferAttach(target.id, target.depth.id, rlFramebufferAttachType.RL_ATTACHMENT_DEPTH, rlFramebufferAttachTextureType.RL_ATTACHMENT_TEXTURE2D, 0);
    
            // Check if fbo is complete with attachments (valid)
            //if (Rlgl.rlFramebufferComplete(target.id)) Raylib.TraceLog(TraceLogLevel.LOG_INFO, "FBO: [ID %i] Framebuffer object created successfully", target.id);
    
            Rlgl.rlDisableFramebuffer();
        }
        //else TRACELOG(LOG_WARNING, "FBO: Framebuffer object can not be created");
    
        return target;
    }
    
    // Unload shadowmap render texture from GPU memory (VRAM)
    void UnloadShadowmapRenderTexture(RenderTexture2D target)
    {
        if (target.id > 0)
        {
            // NOTE: Depth texture/renderbuffer is automatically
            // queried and deleted before deleting framebuffer
            Rlgl.rlUnloadFramebuffer(target.id);
        }
    }
    }