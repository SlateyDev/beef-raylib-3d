using System;
using System.Collections;
using RaylibBeef;

class World {
    private List<uint8> mLevelData = new .() ~ delete(mLevelData);
    private int mWidth = 100;
    private int mHeight = 100;

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
    const int32 NUM_CASCADES = 1;
    private RenderTexture2D[NUM_CASCADES] shadowMaps;
    private Matrix[NUM_CASCADES] lightViews;
    private Matrix[NUM_CASCADES] lightProjs;
    private float[NUM_CASCADES+1] cascadeSplits = .(0.0f, 1.0f);

    public this() {
        LoadModels();
        //CreateObstacles();
        Console.WriteLine("OpenGL version: {}", Rlgl.rlGetVersion());

#if BF_PLATFORM_WASM
        char8* vsShaderFile = "assets/shaders/100/shadow.vs";
        char8* fsShaderFile = "assets/shaders/100/shadow.fs";
#else
        char8* vsShaderFile = "assets/shaders/330/shadow.vs";
        char8* fsShaderFile = "assets/shaders/330/shadow.fs";
#endif
        
        // Initialize shadow mapping resources
        for (var cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            shadowMaps[cascade_index] = LoadShadowmapRenderTexture(SHADOWMAP_RESOLUTION, SHADOWMAP_RESOLUTION);
        }

        mShadowShader = Raylib.LoadShader(vsShaderFile, fsShaderFile);
        UpdateModelShaders();
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
            Raymath.Vector3Add(Raymath.Vector3Scale(lightDir, -15.0f), Program.game.mPlayer.Position),  // Light position
            Program.game.mPlayer.Position,     // Looking at center
            .(0.0f, 1.0f, 0.0f),     // Up vector
            5.0f,                    // FOV
            CameraProjection.CAMERA_ORTHOGRAPHIC       // Projection type
        );
    }

    public ~this() {
        DeleteContainerAndItems!(mModels);
        for (var cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            UnloadShadowmapRenderTexture(shadowMaps[cascade_index]);
        }
        Raylib.UnloadShader(mDepthShader);
        Raylib.UnloadShader(mShadowShader);
    }

    public void LoadLevel(StringView filePath) {
        // For now we'll just create a simple floor
    }

    public void Update(float frameTime) {
        // Update world state
    }

    public const double CULL_DISTANCE_NEAR = 0.05;
    public const double CULL_DISTANCE_FAR = 4000;

    // Update cascade light matrices
    void UpdateCascades(Camera3D camera) {
        for (int i = 0; i < NUM_CASCADES; i++) {
            float nearSplit = Raymath.Lerp((float)CULL_DISTANCE_NEAR, (float)CULL_DISTANCE_FAR, cascadeSplits[i]);
            float farSplit  = Raymath.Lerp((float)CULL_DISTANCE_NEAR, (float)CULL_DISTANCE_FAR, cascadeSplits[i+1]);

            // Here we just use a fixed-size ortho box for simplicity
            Vector3 center = Raymath.Vector3Add(camera.position,
                Raymath.Vector3Scale(Raymath.Vector3Normalize(Raymath.Vector3Subtract(camera.target, camera.position)),
                (nearSplit + farSplit) * 0.5f));

            Vector3 lightPos = Raymath.Vector3Add(center, Raymath.Vector3Scale(lightDir, -20.0f));
            lightViews[i] = Raymath.MatrixLookAt(lightPos, center, .(0, 1, 0));
            lightProjs[i] = Raymath.MatrixOrtho(-20, 20, -20, 20, CULL_DISTANCE_NEAR, CULL_DISTANCE_FAR);
        }
    }

    Matrix lightView;
    Matrix lightProj;

    public void Render(Camera3D playerCamera) {
        mLightCamera.position = Raymath.Vector3Add(Raymath.Vector3Scale(lightDir, -15.0f), Program.game.mPlayer.Position);
        mLightCamera.target = Program.game.mPlayer.Position;

        Vector3 cameraPos = playerCamera.position;
        Raylib.SetShaderValue(mShadowShader, ((int32*)mShadowShader.locs)[ShaderLocationIndex.SHADER_LOC_VECTOR_VIEW], &cameraPos, ShaderUniformDataType.SHADER_UNIFORM_VEC3);

        // First pass: render to shadow map
        // Draw scene from light's perspective
        RenderSceneForShadow(playerCamera);

        // Second pass: render scene with shadows
        // Render the scene from player perspective
        RenderSceneWithShadows(playerCamera);
    }

    private void CustomBeginMode3D(Matrix proj, Matrix view) {
        Rlgl.rlDrawRenderBatchActive();

        Rlgl.rlMatrixMode(Rlgl.RL_PROJECTION);
        Rlgl.rlPushMatrix();
        Rlgl.rlLoadIdentity();

        Rlgl.rlMultMatrixf(&Raymath.MatrixToFloatV(proj).v[0]);

        Rlgl.rlMatrixMode(Rlgl.RL_MODELVIEW);
        Rlgl.rlLoadIdentity();

        Rlgl.rlMultMatrixf(&Raymath.MatrixToFloatV(view).v[0]);

        Rlgl.rlEnableDepthTest();
    }

    private void RenderSceneForShadow(Camera3D playerCamera) {
        UpdateCascades(playerCamera);

        Raylib.BeginTextureMode(shadowMaps[0]);
        Raylib.ClearBackground(Raylib.WHITE);
        lightView = lightViews[0]; // Raymath.MatrixLookAt(mLightCamera.position, mLightCamera.target, mLightCamera.up); // Rlgl.rlGetMatrixModelview();
        lightProj = lightProjs[0]; // Raymath.MatrixOrtho(-mLightCamera.fovy/2.0, mLightCamera.fovy/2.0, -mLightCamera.fovy/2.0, mLightCamera.fovy/2.0, 0.05f, 4000); // Rlgl.rlGetMatrixProjection();
        CustomBeginMode3D(lightProj, lightView);
        //Raylib.BeginMode3D(mLightCamera);

        // Draw floor
        Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mWidth, mHeight), Raylib.BLACK);
        
        DrawCubes(Raylib.BLACK);
        DrawModels();

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
        Rlgl.rlEnableTexture(shadowMaps[0].depth.id);
        Rlgl.rlSetUniform(shadowMapLoc, &slot, ShaderUniformDataType.SHADER_UNIFORM_INT, 1);

        Raylib.BeginMode3D(playerCamera);
        Raylib.BeginShaderMode(mShadowShader);

        // Draw floor
        Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mWidth, mHeight), Raylib.DARKGRAY);

        DrawCubes(Raylib.BLUE);
        DrawModels();

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
    
        if (target.id > 0) {
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
            if (Rlgl.rlFramebufferComplete(target.id)) Console.WriteLine("FBO: [ID {}] Framebuffer object created successfully", target.id);
    
            Rlgl.rlDisableFramebuffer();
        }
        //else TRACELOG(LOG_WARNING, "FBO: Framebuffer object can not be created");
    
        return target;
    }
    
    // Unload shadowmap render texture from GPU memory (VRAM)
    void UnloadShadowmapRenderTexture(RenderTexture2D target) {
        if (target.id > 0) {
            // NOTE: Depth texture/renderbuffer is automatically
            // queried and deleted before deleting framebuffer
            Rlgl.rlUnloadFramebuffer(target.id);
        }
    }

    public List<BoundingBox> mObstacles = new .() ~ delete _;
    private List<Model3D> mModels = new .();

    private void CreateObstacles() {
        // Add obstacles for cubes
        for (int i = -5; i <= 5; i++) {
            for (int j = -5; j <= 5; j++) {
                if ((i + j) % 2 == 0) {
                    AddObstacle(.(i * 4.0f, 1.0f, j * 4.0f), .(1.0f, 2.0f, 1.0f));
                }
            }
        }
    }

    private void AddObstacle(Vector3 position, Vector3 size) {
        Vector3 min = .(
            position.x - size.x/2,
            position.y,
            position.z - size.z/2
        );
        Vector3 max = .(
            position.x + size.x/2,
            position.y + size.y,
            position.z + size.z/2
        );
        mObstacles.Add(.(min, max));
    }

    private void LoadModels() {
        // Example: Load a GLTF model
        // Note: Adjust the path to your model files
        let model = new Model3D("assets/models/charybdis.gltf");
        //let model = new Model3D("assets/models/Untitled.gltf");
        model.Position = .(2, 0.5f, 0);
        model.Scale = .(1f, 1f, 1f);
        mModels.Add(model);
    }

    private void UpdateModelShaders() {
        for (let model in mModels) {
            for (int i = 0; i < model.mModel.materialCount; i++) {
                model.mModel.materials[i].shader = mShadowShader;
            }
        }
    }

    public void DrawModels() {
        // Draw models
        for (let model in mModels) {
            model.Draw();
        }
    }
}