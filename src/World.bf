using System;
using System.Collections;
using System.Interop;
using RaylibBeef;
using Jolt;
using static Jolt.Jolt;

class World {
    private List<uint8> mLevelData = new .() ~ delete(mLevelData);
    private int mFloorWidth = 50;
    private int mFloorLength = 50;

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

    Frustum cameraFrustum;

    JPH_BodyID floorId;
    JPH_BodyID sphereId;

    public this() {
        LoadModels();

        //CreateObstacles();
        Console.WriteLine("OpenGL version: {}", Rlgl.rlGetVersion());


        floorId = .();
        {
        	// Next we can create a rigid body to serve as the floor, we make a large box
        	// Create the settings for the collision volume (the shape). 
        	// Note that for simple shapes (like boxes) you can also directly construct a BoxShape.
        	JPH_Vec3 boxHalfExtents = .(mFloorWidth / 2, 1.0f, mFloorLength / 2);
        	JPH_BoxShape* floorShape = JPH_BoxShape_Create(&boxHalfExtents, JPH_DEFAULT_CONVEX_RADIUS);

        	JPH_Vec3 floorPosition = .(0.0f, -1.0f, 0.0f);
        	JPH_BodyCreationSettings* floorSettings = JPH_BodyCreationSettings_Create3(
        		(JPH_Shape*)floorShape,
        		&floorPosition,
        		null, // Identity, 
        		JPH_MotionType.Static,
        		PhysicsServer.Layers.NON_MOVING.Underlying);

        	// Create the actual rigid body
        	floorId = PhysicsServer.CreateAndAddBody(floorSettings, .DontActivate);
        	JPH_BodyCreationSettings_Destroy(floorSettings);
        }

        // Sphere
        sphereId = .();
        {
        	JPH_SphereShape* sphereShape = JPH_SphereShape_Create(1.0f);
        	JPH_Vec3 spherePosition = .(0.6f, 5f, 1f);
        	JPH_BodyCreationSettings* sphereSettings = JPH_BodyCreationSettings_Create3(
        		(JPH_Shape*)sphereShape,
        		&spherePosition,
        		null, // Identity,
        		JPH_MotionType.Dynamic,
        		PhysicsServer.Layers.MOVING.Underlying);

        	sphereId = PhysicsServer.CreateAndAddBody(sphereSettings, .Activate);
        	JPH_BodyCreationSettings_Destroy(sphereSettings);
        }

        // Now you can interact with the dynamic body, in this case we're going to give it a velocity.
        // (note that if we had used CreateBody then we could have set the velocity straight on the body before adding it to the physics system)
        JPH_Vec3 sphereLinearVelocity = .(0.0f, 10f, 0.0f);
        PhysicsServer.SetLinearVelocity(sphereId, &sphereLinearVelocity);

        JPH_SixDOFConstraintSettings jointSettings;
        JPH_SixDOFConstraintSettings_Init(&jointSettings);

        // Optional step: Before starting the physics simulation you can optimize the broad phase. This improves collision detection performance (it's pointless here because we only have 2 bodies).
        // You should definitely not call this every frame or when e.g. streaming in a new level section as it is an expensive operation.
        // Instead insert all new objects in batches instead of 1 at a time to keep the broad phase efficient.
        PhysicsServer.Optimise();

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

    float physicsTime;
    float physicsUpdateTime = 1f / 60f;
    float physicsThreshold = physicsUpdateTime * 1.2f;

    public void Update(float frameTime) {
        // Update world state
        for (var modelInstance in mModelInstances) {
            modelInstance.Update(frameTime);
        }

        if (Raylib.IsKeyPressed(.KEY_LEFT_SHIFT)) {
            JPH_Vec3 sphereLinearVelocity = .(0.0f, 5f, 0.0f);
            PhysicsServer.SetLinearVelocity(sphereId, &sphereLinearVelocity);
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

    private void SphereInFrustum(Matrix vpMatrix, Vector3 point, float radius) {
        var projection = Rlgl.rlGetMatrixProjection();
        var modelView = Rlgl.rlGetMatrixModelview();
        var viewProjMatrix = Raymath.MatrixMultiply(modelView, projection);

        Vector4 r1 = .(viewProjMatrix.m0, viewProjMatrix.m4, viewProjMatrix.m8, viewProjMatrix.m12);
        Vector4 r2 = .(viewProjMatrix.m1, viewProjMatrix.m5, viewProjMatrix.m9, viewProjMatrix.m13);
        Vector4 r3 = .(viewProjMatrix.m2, viewProjMatrix.m6, viewProjMatrix.m10, viewProjMatrix.m14);
        Vector4 r4 = .(viewProjMatrix.m3, viewProjMatrix.m7, viewProjMatrix.m11, viewProjMatrix.m15);

        float magnitude;

        Vector4 leftPlane = .(r4.x + r1.x, r4.y + r1.y, r4.z + r1.z, r4.w + r1.w);
        magnitude = Math.Sqrt(leftPlane.x * leftPlane.x + leftPlane.y * leftPlane.y + leftPlane.z * leftPlane.z);
        leftPlane = .(leftPlane.x / magnitude, leftPlane.y / magnitude, leftPlane.z / magnitude, leftPlane.w / magnitude);
        Vector4 rightPlane = .(r4.x - r1.x, r4.y - r1.y, r4.z - r1.z, r4.w - r1.w);

        Vector4 bottomPlane = .(r4.x + r2.x, r4.y + r2.y, r4.z + r2.z, r4.w + r2.w);
        Vector4 topPlane = .(r4.x - r2.x, r4.y - r2.y, r4.z - r2.z, r4.w - r2.w);

        Vector4 nearPlane = .(r4.x + r3.x, r4.y + r3.y, r4.z + r3.z, r4.w + r3.w);
        Vector4 farPlane = .(r4.x - r3.x, r4.y - r3.y, r4.z - r3.z, r4.w - r3.w);

        var distanceToPlane = leftPlane.x * point.x + leftPlane.y * point.y + leftPlane.z * point.z + leftPlane.w;
        if (distanceToPlane < -radius) {
            Console.WriteLine($"False: {distanceToPlane}");
        } else {
            Console.WriteLine($"True: {distanceToPlane}");
        }
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
            cameraFrustum.Extract();

            // // Raylib.BeginShaderMode(mDepthShader);
            Raylib.BeginShaderMode(mShadowShader);
            JPH_RVec3* position = new .(0,0,0);
            PhysicsServer.GetCenterOfMassPosition(sphereId, position);
            Raylib.DrawSphere(.(position.x, position.y, position.z), 1, Raylib.RED);
            delete position;
            // Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mFloorWidth, mFloorLength), Raylib.BLACK);
            // // DrawCubes(Raylib.BLACK);
            Raylib.EndShaderMode();

            DrawModels();

            //if (PhysicsServer.BodyIsActive(sphereId)) {
            //    JPH_Vec3* velocity= new .(0,0,0);
            //    PhysicsServer.GetLinearVelocity(sphereId, velocity);
            //    delete velocity;
            //}

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
        cameraFrustum.Extract();

        Raylib.BeginShaderMode(mShadowShader);
        JPH_RVec3* position = new .(0,0,0);
        PhysicsServer.GetCenterOfMassPosition(sphereId, position);
        if (cameraFrustum.SphereIn(position, 1)) {
            Raylib.DrawSphere(*position, 1, Raylib.RED);
        }
        delete position;
        Raylib.DrawPlane(.(0.0f, 0.0f, 0.0f), .(mFloorWidth, mFloorLength), Raylib.DARKGRAY);
        //DrawCubes(Raylib.WHITE);
        Raylib.EndShaderMode();

        DrawModels();

        Program.game.[Friend]scene.Render();

        PhysicsServer.DebugDrawBodies();

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
        CreateModelStaticPhysicsBoundingBox(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_B.gltf"));
        modelInstance.Position = .(2, 0, 0);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 270, 0);
        mModelInstances.Add(modelInstance);
        CreateModelStaticPhysicsBoundingBox(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_H.gltf"));
        modelInstance.Position = .(2, 0, 1);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 270, 0);
        mModelInstances.Add(modelInstance);
        CreateModelStaticPhysicsBoundingBox(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_C.gltf"));
        modelInstance.Position = .(0, 0, -2);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);
        CreateModelStaticPhysicsBoundingBox(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_D.gltf"));
        modelInstance.Position = .(0, 0, -1);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);
        CreateModelStaticPhysicsBoundingBox(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_E.gltf"));
        modelInstance.Position = .(0, 0, 0);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);
        CreateModelStaticPhysicsBoundingBox(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_F.gltf"));
        modelInstance.Position = .(0, 0, 1);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);
        CreateModelStaticPhysicsBoundingBox(modelInstance);

        modelInstance = new ModelInstance3D(ModelManager.Get("assets/models/building_G.gltf"));
        modelInstance.Position = .(0, 0, 2);
        modelInstance.Scale = .(0.5f, 0.5f, 0.5f);
        modelInstance.Rotation = .(0, 90, 0);
        mModelInstances.Add(modelInstance);
        CreateModelStaticPhysicsBoundingBox(modelInstance);
    }

    public void CreateModelStaticPhysicsBoundingBox(ModelInstance3D modelInstance) {
        var modelAABB = modelInstance.boundingBox;
        modelAABB.min = Raymath.Vector3Multiply(modelAABB.min, modelInstance.Scale);
        modelAABB.max = Raymath.Vector3Multiply(modelAABB.max, modelInstance.Scale);
        var rot = Raymath.QuaternionFromAxisAngle(Raymath.Vector3Normalize(modelInstance.Rotation), Raymath.Vector3Length(modelInstance.Rotation) * Raymath.DEG2RAD);
        var halfsize = Vector3((modelAABB.max.x - modelAABB.min.x) / 2f, (modelAABB.max.y - modelAABB.min.y) / 2f, (modelAABB.max.z - modelAABB.min.z) / 2f);
        var center = Vector3(modelInstance.Position.x + halfsize.x + modelAABB.min.x, modelInstance.Position.y + halfsize.y + modelAABB.min.y, modelInstance.Position.z + halfsize.z + modelAABB.min.z);
        var shape = JPH_BoxShape_Create(&halfsize, JPH_DEFAULT_CONVEX_RADIUS);
        var bodySettings = JPH_BodyCreationSettings_Create3((JPH_Shape*)shape, &center, (JPH_Quat*)&rot, JPH_MotionType.Static, PhysicsServer.Layers.NON_MOVING.Underlying);
        PhysicsServer.CreateAndAddBody(bodySettings, .DontActivate);
        JPH_BodyCreationSettings_Destroy(bodySettings);
    }

    public void DrawModels() {
        //Needed for Ray Picking Example
        var ray = Raylib.GetScreenToWorldRay(Raylib.GetMousePosition(), Program.game.mPlayer.camera);
        RayCollision closestCollision = .{distance = float.MaxValue};
        var closestModelIndex = -1;

        List<ModelInstance3D> modelsToDraw = scope List<ModelInstance3D>();

        for (let model in mModelInstances) {
            var sphere = model.GetBoundingSphere();
            if (cameraFrustum.SphereIn(&sphere.Center, sphere.Radius)) {
                modelsToDraw.Add(model);

                //Ray Picking Example
                var raySphereCollision = Raylib.GetRayCollisionSphere(ray, sphere.Center, sphere.Radius);
                if (raySphereCollision.hit) {
                    for (var meshIndex < model.mModel.meshCount) {
                        var rayMeshCollision = Raylib.GetRayCollisionMesh(ray, model.mModel.meshes[meshIndex], Raymath.MatrixMultiply(model.mModel.transform, model.Transform()));
                        if (rayMeshCollision.hit) {
                            if (rayMeshCollision.distance < closestCollision.distance) {
                                closestCollision = rayMeshCollision;
                                closestModelIndex = modelsToDraw.Count - 1;
                            }
                        }
                    }
                }
            }
        }

        for (let model in modelsToDraw) {
            model.Draw(modelsToDraw.IndexOf(model) == closestModelIndex ? Raylib.GREEN : Raylib.WHITE);
        }
    }
}