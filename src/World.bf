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


    public this()
    {
        Console.WriteLine("OpenGL version: {}", Rlgl.rlGetVersion());

#if BF_PLATFORM_WASM
        char8* vsShaderFile = "shaders/100/shadow.vs";
        char8* fsShaderFile = "shaders/100/shadow.fs";
#else
        char8* vsShaderFile = "shaders/330/shadow.vs";
        char8* fsShaderFile = "shaders/330/shadow.fs";
#endif
        
        // Initialize shadow mapping resources
        mShadowMap = LoadShadowmapRenderTexture(SHADOWMAP_RESOLUTION, SHADOWMAP_RESOLUTION);
        mShadowShader = Raylib.LoadShader(vsShaderFile, fsShaderFile);
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