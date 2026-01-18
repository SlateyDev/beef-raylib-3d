using System;
using System.Collections;
using RaylibBeef;

class World {
    private List<uint8> mLevelData = new .() ~ delete(mLevelData);
    private int mWidth = 100;
    private int mHeight = 100;

    private Camera3D mLightCamera;
    // private Shader mDepthShader;
    private Shader mShadowShader;
    private Matrix mLightSpaceMatrix;
    private Vector3 lightDir = Raymath.Vector3Normalize(.( 0.35f, -1.0f, -0.25f ));
    private Color lightColor = Raylib.WHITE;
    private Vector4 lightColorNormalized = Raylib.ColorNormalize(lightColor);

    private int32 shadowMapLoc = 0;
    private int32 lightDirLoc = 0;
    private int32 locSplits = 0;

    const int32 SHADOWMAP_RESOLUTION = 4096;
    const int32 NUM_CASCADES = 4;
    public const float CULL_DISTANCE_NEAR = 0.05f;
    public const float CULL_DISTANCE_FAR = 1000;

    private RenderTexture2D[NUM_CASCADES] shadowMaps;
    private Matrix[NUM_CASCADES] lightViews;
    private Matrix[NUM_CASCADES] lightProjs;
    private float[NUM_CASCADES+1] cascadeSplits = .(CULL_DISTANCE_NEAR, 0.004f * CULL_DISTANCE_FAR, 0.01f * CULL_DISTANCE_FAR, 1f * CULL_DISTANCE_FAR, CULL_DISTANCE_FAR);
    private int32[NUM_CASCADES] lightVPLocs = .(0,0,0,0);

    private Dictionary<GridPos, Road> roadTiles = new Dictionary<GridPos, Road>() ~ delete _;
    private List<Car> cars = new .() ~ delete _;

    public this() {
        LoadModels();

        //CreateObstacles();
        Console.WriteLine("OpenGL version: {}", Rlgl.rlGetVersion());

#if BF_PLATFORM_WASM
    //    char8* vsDepthShaderFile = "assets/shaders/100/depthPack.vs";
    //    char8* fsDepthShaderFile = "assets/shaders/100/depthPack.fs";
    //    char8* vsShaderFile = "assets/shaders/100/shadow.vs";
    //    char8* fsShaderFile = "assets/shaders/100/shadow.fs";
        char8* vsShaderFile = "assets/shaders/300_es/shadow.vs";
        char8* fsShaderFile = "assets/shaders/300_es/shadow.fs";
#else
        char8* vsShaderFile = "assets/shaders/330/shadow.vs";
        char8* fsShaderFile = "assets/shaders/330/shadow.fs";
#endif
        
        // Initialize shadow mapping resources
        for (var cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            shadowMaps[cascade_index] = LoadShadowmapRenderTexture(SHADOWMAP_RESOLUTION, SHADOWMAP_RESOLUTION);
        }

        // mDepthShader = Raylib.LoadShader(vsDepthShaderFile, fsDepthShaderFile);
        mShadowShader = Raylib.LoadShader(vsShaderFile, fsShaderFile);

        ((int32*)mShadowShader.locs)[ShaderLocationIndex.SHADER_LOC_VECTOR_VIEW] = Raylib.GetShaderLocation(mShadowShader, "viewPos");
        lightDirLoc = Raylib.GetShaderLocation(mShadowShader, "lightDir");
        int32 lightColLoc = Raylib.GetShaderLocation(mShadowShader, "lightColor");
        Raylib.SetShaderValue(mShadowShader, lightDirLoc, &lightDir, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
        Raylib.SetShaderValue(mShadowShader, lightColLoc, &lightColorNormalized, ShaderUniformDataType.SHADER_UNIFORM_VEC4);
        int32 ambientLoc = Raylib.GetShaderLocation(mShadowShader, "ambient");
        float[4] ambient = .(0.4f, 0.4f, 0.4f, 1.0f);
        Raylib.SetShaderValue(mShadowShader, ambientLoc, &ambient, ShaderUniformDataType.SHADER_UNIFORM_VEC4);
        for (var cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            lightVPLocs[cascade_index] = Raylib.GetShaderLocation(mShadowShader, scope $"lightVP[{cascade_index}]");
        }
        shadowMapLoc = Raylib.GetShaderLocation(mShadowShader, "shadowMap");
        int32 shadowMapResolution = SHADOWMAP_RESOLUTION;
        Raylib.SetShaderValue(mShadowShader, Raylib.GetShaderLocation(mShadowShader, "shadowMapResolution"), &shadowMapResolution, ShaderUniformDataType.SHADER_UNIFORM_INT);
        float cascadeBlendResolution = 0.1f;
        Raylib.SetShaderValue(mShadowShader, Raylib.GetShaderLocation(mShadowShader, "cascadeBlendWidth"), &cascadeBlendResolution, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
        locSplits = Raylib.GetShaderLocation(mShadowShader, "cascadeSplits");
        Raylib.SetShaderValueV(mShadowShader, locSplits, &cascadeSplits[0], ShaderUniformDataType.SHADER_UNIFORM_FLOAT, NUM_CASCADES + 1);

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
        DeleteContainerAndItems!(mModelInstances);
        for (var cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            UnloadShadowmapRenderTexture(shadowMaps[cascade_index]);
        }
        // Raylib.UnloadShader(mDepthShader);
        Raylib.UnloadShader(mShadowShader);
    }

    public void LoadLevel(StringView filePath) {
        // For now we'll just create a simple floor
    }

    public void Update(float frameTime) {
        // Update world state
        for (var modelInstance in mModelInstances) {
            modelInstance.Update(frameTime);
        }
    }

    private void ComputeCascadeSplits(int32 numCascades, float nearPlane, float farPlane, float lambda, float* outSplits) {
        outSplits[0] = nearPlane;
        outSplits[numCascades] = farPlane;

        float range = farPlane - nearPlane;
        float ratio = farPlane / nearPlane;

        for (int cascade_index = 1; cascade_index < numCascades; cascade_index++) {
            float p = (float)cascade_index / (float)numCascades;
            float log = nearPlane * System.Math.Pow(ratio, p);
            float uniform = nearPlane + range * p;
            float d = lambda * (log - uniform) + uniform;
            outSplits[cascade_index] = d;
        }
    }

    private void FrustumSliceCornersWS(Camera3D cam, float aspect, float nearZ, float farZ, ref Vector3[8] outCorners) {
        Vector3 fwd = Raymath.Vector3Normalize(Raymath.Vector3Subtract(cam.target, cam.position));
        Vector3 right = Raymath.Vector3Normalize(Raymath.Vector3CrossProduct(fwd, cam.up));
        Vector3 up = Raymath.Vector3Normalize(Raymath.Vector3CrossProduct(right, fwd));

        float tanHalfFovy = Math.Tan(cam.fovy * Raymath.DEG2RAD * 0.5f);

        float nh = 2.0f * tanHalfFovy * nearZ;
        float nw = nh * aspect;
        float fh = 2.0f * tanHalfFovy * farZ;
        float fw = fh * aspect;

        Vector3 nc = Raymath.Vector3Add(cam.position, Raymath.Vector3Scale(fwd, nearZ));
        Vector3 fc = Raymath.Vector3Add(cam.position, Raymath.Vector3Scale(fwd, farZ));

        Vector3 upN = Raymath.Vector3Scale(up, nh * 0.5f);
        Vector3 rtN = Raymath.Vector3Scale(right, nw * 0.5f);
        Vector3 upF = Raymath.Vector3Scale(up, fh * 0.5f);
        Vector3 rtF = Raymath.Vector3Scale(right, fw * 0.5f);

        outCorners[0] = Raymath.Vector3Add(Raymath.Vector3Add(nc, upN),  rtN);
        outCorners[1] = Raymath.Vector3Add(Raymath.Vector3Subtract(nc, rtN),  upN);
        outCorners[2] = Raymath.Vector3Subtract(Raymath.Vector3Subtract(nc, upN),  rtN);
        outCorners[3] = Raymath.Vector3Subtract(Raymath.Vector3Add(nc, rtN),  upN);

        outCorners[4] = Raymath.Vector3Add(Raymath.Vector3Add(fc, upF),  rtF);
        outCorners[5] = Raymath.Vector3Add(Raymath.Vector3Subtract(fc, rtF),  upF);
        outCorners[6] = Raymath.Vector3Subtract(Raymath.Vector3Subtract(fc, upF),  rtF);
        outCorners[7] = Raymath.Vector3Subtract(Raymath.Vector3Add(fc, rtF),  upF);
    }

    private void SnapOrthoToTexels(float* minX, float* maxX, float* minY, float* maxY, int mapSize) {
        float width  = (*maxX - *minX);
        float height = (*maxY - *minY);
        float texelX = width  / (float)mapSize;
        float texelY = height / (float)mapSize;

        float cx = 0.5f*(*minX + *maxX);
        float cy = 0.5f*(*minY + *maxY);

        cx = Math.Floor(cx / texelX) * texelX;
        cy = Math.Floor(cy / texelY) * texelY;

        *minX = cx - width *0.5f;
        *maxX = cx + width *0.5f;
        *minY = cy - height*0.5f;
        *maxY = cy + height*0.5f;
    }

    // Update cascade light matrices
    void UpdateCascades(Camera3D camera) {
        for (int cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            float nearSplit = cascadeSplits[cascade_index];
            float farSplit  = cascadeSplits[cascade_index + 1];

            // Here we just use a fixed-size ortho box for simplicity
            Vector3 center = Raymath.Vector3Add(camera.position,
                Raymath.Vector3Scale(Raymath.Vector3Normalize(Raymath.Vector3Subtract(camera.target, camera.position)),
                (nearSplit + farSplit) * 0.5f));

            Vector3 lightPos = Raymath.Vector3Add(center, Raymath.Vector3Scale(lightDir, -20.0f));
            lightViews[cascade_index] = Raymath.MatrixLookAt(lightPos, center, .(0, 1, 0));

            var ortho_size = (cascade_index * 5 + 1) * 4;
            lightProjs[cascade_index] = Raymath.MatrixOrtho(-ortho_size, ortho_size, -ortho_size, ortho_size, CULL_DISTANCE_NEAR, CULL_DISTANCE_FAR);
        }
    }

    void NewUpdateCascades(Camera3D camera) {
        float lambda = 0.95f;
        float zPadding = 30.0f;

        float aspect = (float)Raylib.GetScreenWidth() / (float)Raylib.GetScreenHeight();
        ComputeCascadeSplits(NUM_CASCADES, CULL_DISTANCE_NEAR, 100, lambda, &cascadeSplits);
        Raylib.SetShaderValueV(mShadowShader, locSplits, &cascadeSplits[0], ShaderUniformDataType.SHADER_UNIFORM_FLOAT, NUM_CASCADES + 1);

        Vector3 worldUp = (Math.Abs(lightDir.y) > 0.99f) ? .(0,0,1) : .(0,1,0);

        for (int cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            float nearSplit = cascadeSplits[cascade_index];
            float farSplit  = cascadeSplits[cascade_index + 1];

            Vector3[8] cornersWS = .();
            FrustumSliceCornersWS(camera, aspect, nearSplit, farSplit, ref cornersWS);

            Vector3 centroid = .(0, 0, 0);
            for (int i = 0; i < 8; i++) centroid = Raymath.Vector3Add(centroid, cornersWS[i]);
            centroid = Raymath.Vector3Scale(centroid, 1.0f/8.0f);

            float distBack = 50.0f; // heuristic; large enough for your scene
            Vector3 eye = Raymath.Vector3Subtract(centroid, Raymath.Vector3Scale(lightDir, distBack));
            lightViews[cascade_index] = Raymath.MatrixLookAt(eye, centroid, worldUp);

            float minX = float.MaxValue, minY = float.MaxValue, minZ = float.MaxValue;
            float maxX = float.MinValue, maxY = float.MinValue, maxZ = float.MinValue;
            for (int i = 0; i < 8; i++) {
                Vector3 ls = Raymath.Vector3Transform(cornersWS[i], lightViews[cascade_index]);
                minX = Math.Min(minX, ls.x);
                maxX = Math.Max(maxX, ls.x);
                minY = Math.Min(minY, ls.y);
                maxY = Math.Max(maxY, ls.y);
                minZ = Math.Min(minZ, ls.z);
                maxZ = Math.Max(maxZ, ls.z);
            }

            float padXY = 0.05f * Math.Max(maxX - minX, maxY - minY);
            minX -= padXY;
            maxX += padXY;
            minY -= padXY;
            maxY += padXY;

            SnapOrthoToTexels(&minX, &maxX, &minY, &maxY, SHADOWMAP_RESOLUTION);

            minZ -= zPadding;
            maxZ += zPadding;

            lightProjs[cascade_index] = Raymath.MatrixOrtho(minX, maxX, minY, maxY, CULL_DISTANCE_NEAR, CULL_DISTANCE_FAR);

            //var ortho_size = (cascade_index * 5 + 1) * 4;
            //lightProjs[cascade_index] = Raymath.MatrixOrtho(-ortho_size, ortho_size, -ortho_size, ortho_size, CULL_DISTANCE_NEAR, CULL_DISTANCE_FAR);
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
        // ModelManager.UpdateModelShaders(mDepthShader);
        ModelManager.UpdateModelShaders(mShadowShader);
        NewUpdateCascades(playerCamera);

        Rlgl.rlDisableColorBlend();
        for (var cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            Raylib.BeginTextureMode(shadowMaps[cascade_index]);
            Raylib.ClearBackground(Raylib.WHITE);
            lightView = lightViews[cascade_index];
            lightProj = lightProjs[cascade_index];
            CustomBeginMode3D(lightProj, lightView);

            // // Raylib.BeginShaderMode(mDepthShader);
            // Raylib.BeginShaderMode(mShadowShader);
            // Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mWidth, mHeight), Raylib.BLACK);
            // // DrawCubes(Raylib.BLACK);
            // Raylib.EndShaderMode();

            DrawModels();

            Raylib.EndMode3D();
            Raylib.EndTextureMode();
        }
        Rlgl.rlEnableColorBlend();
    }

    private void RenderSceneWithShadows(Camera3D playerCamera) {
        ModelManager.UpdateModelShaders(mShadowShader);
        Raylib.ClearBackground(Raylib.BEIGE);

        // Calculate MVP matrix for the current camera
        Matrix[NUM_CASCADES] lightViewProj;
        for (int32 cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            lightViewProj[cascade_index] = Raymath.MatrixMultiply(lightViews[cascade_index], lightProjs[cascade_index]);
            Raylib.SetShaderValueMatrix(mShadowShader, lightVPLocs[cascade_index], lightViewProj[cascade_index]);
        }

        int32[NUM_CASCADES] slot;
        for (int32 cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            slot[cascade_index] = 10 + cascade_index; // Can be anything 0 to 15, but 0 will probably be taken up
            Rlgl.rlActiveTextureSlot(slot[cascade_index]);
            Rlgl.rlEnableTexture(shadowMaps[cascade_index].depth.id);
        }
        Rlgl.rlSetUniform(shadowMapLoc, &slot[0], ShaderUniformDataType.SHADER_UNIFORM_INT, NUM_CASCADES);

        Raylib.BeginMode3D(playerCamera);

        Raylib.BeginShaderMode(mShadowShader);
        Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mWidth, mHeight), Raylib.DARKGRAY);
        //DrawCubes(Raylib.WHITE);
        Raylib.EndShaderMode();

        DrawModels();

        Raylib.EndMode3D();

        for (int32 cascade_index = 0; cascade_index < NUM_CASCADES; cascade_index++) {
            slot[cascade_index] = 10 + cascade_index; // Can be anything 0 to 15, but 0 will probably be taken up
            Rlgl.rlActiveTextureSlot(slot[cascade_index]);
            Rlgl.rlDisableTexture();
        }
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
    
        if (target.id > 0) {
            Rlgl.rlEnableFramebuffer(target.id);
    
            // target.texture.id = Rlgl.rlLoadTexture(null, width, height, PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            target.texture.width = width;
            target.texture.height = height;
            // target.texture.format = PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            // target.texture.mipmaps = 1;

            target.depth.id = Rlgl.rlLoadTextureDepth(width, height, false);
            target.depth.width = width;
            target.depth.height = height;
            target.depth.format = 19;       //DEPTH_COMPONENT_24BIT?
            target.depth.mipmaps = 1;
    
            // Rlgl.rlFramebufferAttach(target.id, target.texture.id, rlFramebufferAttachType.RL_ATTACHMENT_COLOR_CHANNEL0, rlFramebufferAttachTextureType.RL_ATTACHMENT_TEXTURE2D, 0);
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
    private List<ModelInstance3D> mModelInstances = new .();

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

    private void AddRoadTile(Road tile, GridPos position) {
        Console.WriteLine($"Adding road tile at {position}");

        //TODO: Check if we are replacing an existing tile and if links already exist and disconnect them first
        tile.Position = .(position.x, position.y, position.z);
        mModelInstances.Add(tile);
        roadTiles.Add(position, tile);

        bool[4] links = .();

        var data = tile.GetRoadData();
        for (var pathIndex = 0; pathIndex < data.numPaths; pathIndex++) {
            links[(int)data.paths[pathIndex].sideA] = true;
            links[(int)data.paths[pathIndex].sideB] = true;
        }

        if (links[(int)EntryExitSide.North]) {
            Road northRoad;
            var northKey = position - .(0, 0, 1);
            let hasNorthRoad = roadTiles.TryGetValue(northKey, out northRoad);
            if (hasNorthRoad) {
                //Make sure on of the connected road paths goes south to meet this incomming road
                var roadData = northRoad.GetRoadData();
                for (var pathIndex = 0; pathIndex < roadData.numPaths; pathIndex++) {
                    if (roadData.paths[pathIndex].sideA == .South || roadData.paths[pathIndex].sideB == .South) {
                        //Make connection and exit
                        tile.connections[(int)EntryExitSide.North] = northRoad;
                        Console.WriteLine($"Linking {position} on North side to {northKey}");
                        northRoad.connections[(int)EntryExitSide.South] = tile;
                        Console.WriteLine($"Linking {northKey} on South side to {position}");
                        break;
                    }
                }
            }
        }

        if (links[(int)EntryExitSide.East]) {
            Road eastRoad;
            var eastKey = position + .(1, 0, 0);
            let hasEastRoad = roadTiles.TryGetValue(eastKey, out eastRoad);
            if (hasEastRoad) {
                //Make sure on of the connected road paths goes south to meet this incomming road
                var roadData = eastRoad.GetRoadData();
                for (var pathIndex = 0; pathIndex < roadData.numPaths; pathIndex++) {
                    if (roadData.paths[pathIndex].sideA == .West || roadData.paths[pathIndex].sideB == .West) {
                        //Make connection and exit
                        tile.connections[(int)EntryExitSide.East] = eastRoad;
                        Console.WriteLine($"Linking {position} on East side to {eastKey}");
                        eastRoad.connections[(int)EntryExitSide.West] = tile;
                        Console.WriteLine($"Linking {eastKey} on West side to {position}");
                        break;
                    }
                }
            }
        }

        if (links[(int)EntryExitSide.South]) {
            Road southRoad;
            var southKey = position + .(0, 0, 1);
            let hasSouthRoad = roadTiles.TryGetValue(southKey, out southRoad);
            if (hasSouthRoad) {
                //Make sure on of the connected road paths goes south to meet this incomming road
                var roadData = southRoad.GetRoadData();
                for (var pathIndex = 0; pathIndex < roadData.numPaths; pathIndex++) {
                    if (roadData.paths[pathIndex].sideA == .North || roadData.paths[pathIndex].sideB == .North) {
                        //Make connection and exit
                        tile.connections[(int)EntryExitSide.South] = southRoad;
                        Console.WriteLine($"Linking {position} on South side to {southKey}");
                        southRoad.connections[(int)EntryExitSide.North] = tile;
                        Console.WriteLine($"Linking {southKey} on North side to {position}");
                        break;
                    }
                }
            }
        }

        if (links[(int)EntryExitSide.West]) {
            Road westRoad;
            var westKey = position - .(1, 0, 0);
            let hasWestRoad = roadTiles.TryGetValue(westKey, out westRoad);
            if (hasWestRoad) {
                //Make sure on of the connected road paths goes south to meet this incomming road
                var roadData = westRoad.GetRoadData();
                for (var pathIndex = 0; pathIndex < roadData.numPaths; pathIndex++) {
                    if (roadData.paths[pathIndex].sideA == .East || roadData.paths[pathIndex].sideB == .East) {
                        //Make connection and exit
                        tile.connections[(int)EntryExitSide.West] = westRoad;
                        Console.WriteLine($"Linking {position} on West side to {westKey}");
                        westRoad.connections[(int)EntryExitSide.East] = tile;
                        Console.WriteLine($"Linking {westKey} on East side to {position}");
                        break;
                    }
                }
            }
        }
    }

    private void LoadModels() {
        // Example: Load a GLTF model
        // Note: Adjust the path to your model files
        //let model = new Model3D("assets/models/charybdis.gltf");
        //let model = new Model3D("assets/models/Untitled.gltf");
        ModelInstance3D modelInstance;

        AddRoadTile(new RoadCornerSE(), .(1, 0, -2));

        AddRoadTile(new RoadStraightNS(), .(1, 0, -1));
        AddRoadTile(new RoadStraightNS(), .(1, 0, 0));
        AddRoadTile(new RoadStraightNS(), .(1, 0, 1));

        AddRoadTile(new RoadCornerNE(), .(1, 0, 2));

        AddRoadTile(new RoadStraightEW(), .(2, 0, 2));
        AddRoadTile(new RoadStraightEW(), .(3, 0, 2));
        AddRoadTile(new RoadStraightEW(), .(4, 0, 2));

        AddRoadTile(new RoadCornerNW(), .(5, 0, 2));

        AddRoadTile(new RoadStraightNS(), .(5, 0, 1));
        AddRoadTile(new RoadStraightNS(), .(5, 0, 0));
        AddRoadTile(new RoadStraightNS(), .(5, 0, -1));

        AddRoadTile(new RoadCornerSW(), .(5, 0, -2));

        AddRoadTile(new RoadStraightEW(), .(4, 0, -2));
        AddRoadTile(new RoadStraightEW(), .(3, 0, -2));
        AddRoadTile(new RoadStraightEW(), .(2, 0, -2));

        var taxi = new CarTaxi();
        mModelInstances.Add(taxi);
        cars.Add(taxi);
        taxi.currentRoadSegment = roadTiles[.(1, 0, -2)];
        taxi.Start();

        var stationWagon = new CarStationWagon();
        mModelInstances.Add(stationWagon);
        cars.Add(stationWagon);
        stationWagon.currentRoadSegment = roadTiles[.(5, 0, -2)];
        stationWagon.Start();

        var police = new CarPolice();
        mModelInstances.Add(police);
        cars.Add(police);
        police.currentRoadSegment = roadTiles[.(2, 0, 2)];
        police.Start();

        var sedan = new CarSedan();
        mModelInstances.Add(sedan);
        cars.Add(sedan);
        sedan.currentRoadSegment = roadTiles[.(5, 0, 0)];
        sedan.Start();

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_A.gltf"));
        modelInstance.Position = .(2, 0, -1);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 270, 0);
        mModelInstances.Add(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_B.gltf"));
        modelInstance.Position = .(2, 0, 0);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 270, 0);
        mModelInstances.Add(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_H.gltf"));
        modelInstance.Position = .(2, 0, 1);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 270, 0);
        mModelInstances.Add(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_C.gltf"));
        modelInstance.Position = .(0, 0, -2);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_D.gltf"));
        modelInstance.Position = .(0, 0, -1);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_E.gltf"));
        modelInstance.Position = .(0, 0, 0);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_F.gltf"));
        modelInstance.Position = .(0, 0, 1);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_G.gltf"));
        modelInstance.Position = .(0, 0, 2);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);
        
    }

    public void DrawModels() {
        // Draw models
        for (let model in mModelInstances) {
            model.Draw();
        }
    }
}